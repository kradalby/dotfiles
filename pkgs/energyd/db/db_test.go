package db

import (
	"context"
	"database/sql"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/juanfont/headscale/hscontrol/db/sqliteconfig"
	"github.com/stretchr/testify/require"
	"github.com/tailscale/squibble"

	"energyd/db/dbsqlc"
)

func openTest(t *testing.T) *DB {
	t.Helper()

	d, err := Open(context.Background(), filepath.Join(t.TempDir(), "test.db"))
	require.NoError(t, err)
	t.Cleanup(func() { _ = d.Close() })

	return d
}

// The live database holds years of history, so a schema change must upgrade it in
// place, keep what it holds, and reach the same schema a new database gets.
func TestSchemaUpgradesTheDeployedDatabase(t *testing.T) {
	ctx := t.Context()
	path := filepath.Join(t.TempDir(), "test.db")

	before := strings.Replace(dbSchema, weatherHoursTable+";", "", 1)
	require.NotEqual(t, dbSchema, before)

	digest, err := squibble.SQLDigest(before)
	require.NoError(t, err)
	require.Equal(t, deployedSchemaDigest, digest, "the rule must start from the deployed schema")

	uri, err := sqliteconfig.Default(path).ToURL()
	require.NoError(t, err)

	old, err := sql.Open("sqlite", uri)
	require.NoError(t, err)
	require.NoError(t, (&squibble.Schema{Current: before, IgnoreTables: schema.IgnoreTables}).Apply(ctx, old))
	_, err = old.ExecContext(ctx, `INSERT INTO weather_days (day, mean_c) VALUES ('2026-10-30', 12.5)`)
	require.NoError(t, err)
	require.NoError(t, old.Close())

	d, err := Open(ctx, path)
	require.NoError(t, err)
	t.Cleanup(func() { _ = d.Close() })

	rows, err := d.WeatherBetween(ctx, dbsqlc.WeatherBetweenParams{FromDay: "", ToDay: "9999"})
	require.NoError(t, err)
	require.Len(t, rows, 1, "history survives the upgrade")

	require.NoError(t, d.UpsertWeatherHour(ctx, dbsqlc.UpsertWeatherHourParams{HourTs: 3600, TempC: 9}))
	require.NoError(t, schema.Check())
}

// The ledger is replicated off-site, so personal data must not be able to reach
// it. A new column with one of these meanings must fail here first.
func TestSchemaHoldsNoPersonalData(t *testing.T) {
	d := openTest(t)

	rows, err := d.sql.QueryContext(t.Context(),
		`SELECT m.name, p.name FROM sqlite_master m JOIN pragma_table_info(m.name) p WHERE m.type = 'table'`)
	require.NoError(t, err)
	defer func() { _ = rows.Close() }()

	banned := regexp.MustCompile(`(?i)name|address|street|city|postal|house|email|phone|iban|bank|(^|_)ean($|_)|birth|account|customer|contract|number|invoice_id|user|password|token`)

	columns := 0
	for rows.Next() {
		var table, column string
		require.NoError(t, rows.Scan(&table, &column))
		columns++
		require.False(t, banned.MatchString(column), "%s.%s looks like personal data", table, column)
	}
	require.NoError(t, rows.Err())
	require.Greater(t, columns, 30, "the walk must actually see the schema")
}

// The first reading of a period is its opening register. A later poll in the
// same period must not move it, or period deltas shift.
func TestFirstReadingOfPeriodWins(t *testing.T) {
	d := openTest(t)
	ctx := t.Context()

	insert := func(readAt int64, kwh float64) {
		require.NoError(t, d.InsertReading(ctx, dbsqlc.InsertReadingParams{
			PeriodStart: 900, ReadAt: readAt, ImportKwh: kwh,
		}))
	}
	insert(905, 1)
	insert(960, 2)

	rows, err := d.ReadingsBetween(ctx, dbsqlc.ReadingsBetweenParams{FromTs: 0, ToTs: 1000})
	require.NoError(t, err)
	require.Len(t, rows, 1)
	require.InDelta(t, 1.0, rows[0].ImportKwh, 1e-9)
}

func TestTxRollsBackOnError(t *testing.T) {
	d := openTest(t)
	ctx := t.Context()

	err := d.Tx(ctx, func(q *dbsqlc.Queries) error {
		require.NoError(t, q.UpsertWeather(ctx, dbsqlc.UpsertWeatherParams{Day: "2026-10-27", MeanC: 10}))

		return sql.ErrTxDone
	})
	require.ErrorIs(t, err, sql.ErrTxDone)

	rows, err := d.WeatherBetween(ctx, dbsqlc.WeatherBetweenParams{FromDay: "2026-01-01", ToDay: "2027-01-01"})
	require.NoError(t, err)
	require.Empty(t, rows)
}

// Litestream runs as another user in the owner's group and writes to the database
// files. SQLite creates them from a mode that the service's umask reduces to
// group read-only, and -wal and -shm copy the main file's mode.
func TestDatabaseFilesAreGroupWritable(t *testing.T) {
	old := syscall.Umask(0o007)
	defer syscall.Umask(old)

	path := filepath.Join(t.TempDir(), "test.db")
	d, err := Open(context.Background(), path)
	require.NoError(t, err)
	defer func() { _ = d.Close() }()

	require.NoError(t, d.UpsertWeather(t.Context(), dbsqlc.UpsertWeatherParams{Day: "2026-10-27", MeanC: 10}))

	for _, suffix := range []string{"", "-wal", "-shm"} {
		info, err := os.Stat(path + suffix)
		require.NoError(t, err)
		require.Equal(t, os.FileMode(0o660), info.Mode().Perm(), "energyd.db%s", suffix)
	}
}

func TestLoginStateRoundTrips(t *testing.T) {
	d := openTest(t)
	ctx := t.Context()

	last, blocked, err := d.LoadLogin(ctx)
	require.NoError(t, err)
	require.True(t, last.IsZero())
	require.True(t, blocked.IsZero())

	at := time.Unix(1793394000, 0)
	require.NoError(t, d.SaveLogin(ctx, at, at.Add(time.Hour)))
	require.NoError(t, d.SaveLogin(ctx, at, at.Add(2*time.Hour)))

	last, blocked, err = d.LoadLogin(ctx)
	require.NoError(t, err)
	require.True(t, last.Equal(at))
	require.True(t, blocked.Equal(at.Add(2*time.Hour)))

	require.NoError(t, d.SaveLogin(ctx, at, time.Time{}))
	_, blocked, err = d.LoadLogin(ctx)
	require.NoError(t, err)
	require.True(t, blocked.IsZero(), "clearing must read back as no block")
}
