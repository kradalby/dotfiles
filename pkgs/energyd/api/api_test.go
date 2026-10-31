package api

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strconv"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"energyd/db"
	"energyd/db/dbsqlc"
	"energyd/ledger"
	"energyd/tz"
)

func newServer(t *testing.T) (*http.ServeMux, *db.DB) {
	t.Helper()

	d, err := db.Open(context.Background(), filepath.Join(t.TempDir(), "test.db"))
	require.NoError(t, err)
	t.Cleanup(func() { _ = d.Close() })

	mux := http.NewServeMux()
	New(ledger.New(d), d).Register(mux)

	return mux, d
}

func get(t *testing.T, mux *http.ServeMux, url string) *httptest.ResponseRecorder {
	t.Helper()

	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, url, nil))

	return rec
}

// Infinity draws an empty panel for [] and errors on null, so an empty ledger
// must always answer with an empty list.
func TestEmptyLedgerAnswersEmptyLists(t *testing.T) {
	mux, _ := newServer(t)

	for _, path := range []string{"/api/hours", "/api/bands", "/api/days", "/api/months", "/api/degreedays", "/api/years", "/api/bills"} {
		rec := get(t, mux, path)
		require.Equal(t, http.StatusOK, rec.Code, path)
		require.JSONEq(t, "[]", rec.Body.String(), path)
	}
}

func TestDaysHonourTheRange(t *testing.T) {
	mux, d := newServer(t)

	for _, day := range []string{"2026-10-26", "2026-10-27", "2026-10-28"} {
		require.NoError(t, d.UpsertSupplierDay(t.Context(), dbsqlc.UpsertSupplierDayParams{Day: day, ElecKwh: 1, ElecTotalEur: 2}))
	}

	from, err := tz.ParseDate("2026-10-27")
	require.NoError(t, err)

	// Grafana sends milliseconds in some macros, and seconds in others.
	for _, url := range []string{
		"/api/days?from=" + itoa(from.Unix()) + "&to=" + itoa(from.AddDate(0, 0, 1).Unix()),
		"/api/days?from=" + itoa(from.UnixMilli()) + "&to=" + itoa(from.AddDate(0, 0, 1).UnixMilli()),
	} {
		rec := get(t, mux, url)
		require.Equal(t, http.StatusOK, rec.Code)

		var rows []ledger.Day
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &rows))
		require.Len(t, rows, 1, url)
		require.Equal(t, "2026-10-27", rows[0].Date)
	}
}

func TestBillsCarryNoIdentifier(t *testing.T) {
	mux, d := newServer(t)
	require.NoError(t, d.InsertBill(t.Context(), dbsqlc.InsertBillParams{
		Kind: "Termijnnota", PeriodStart: "2026-11-01", PeriodEnd: "2026-12-01", Due: "2026-10-26", AmountEur: 150, Paid: 1,
	}))

	rec := get(t, mux, "/api/bills")
	require.JSONEq(t, `[{"kind":"Termijnnota","period_start":"2026-11-01","period_end":"2026-12-01","due":"2026-10-26","amount_eur":150,"paid":true,"credited":false}]`, rec.Body.String())
}

func TestWeekdayHoursAndEstimateAnswer(t *testing.T) {
	mux, _ := newServer(t)

	rec := get(t, mux, "/api/weekdayhours")
	require.Equal(t, http.StatusOK, rec.Code)

	var rows []map[string]any
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &rows))
	require.Len(t, rows, 7)

	rec = get(t, mux, "/api/estimate")
	require.Equal(t, http.StatusOK, rec.Code)
	require.Contains(t, rec.Body.String(), `"reliable":false`)
}

func TestDegreeDaysDefaultToMonths(t *testing.T) {
	mux, d := newServer(t)
	for _, day := range []string{"2026-09-30", "2026-10-01"} {
		require.NoError(t, d.UpsertSupplierDay(t.Context(), dbsqlc.UpsertSupplierDayParams{Day: day, GasM3: 1}))
	}

	var months, weeks []ledger.DegreePeriod
	require.NoError(t, json.Unmarshal(get(t, mux, "/api/degreedays").Body.Bytes(), &months))
	require.Len(t, months, 2)
	require.NoError(t, json.Unmarshal(get(t, mux, "/api/degreedays?period=week").Body.Bytes(), &weeks))
	require.Len(t, weeks, 1, "the two days share a week")
}

func itoa(v int64) string { return strconv.FormatInt(v, 10) }

// A panel's legend reduces over everything returned, so it must only get its range.
func TestDaysParamLimitsTheRange(t *testing.T) {
	_, d := newServer(t)
	server := New(ledger.New(d), d)
	now, err := tz.ParseDate("2026-10-28")
	require.NoError(t, err)
	server.now = func() time.Time { return now }

	limited := http.NewServeMux()
	server.Register(limited)

	for _, day := range []string{"2026-09-01", "2026-10-25"} {
		require.NoError(t, d.UpsertSupplierDay(t.Context(), dbsqlc.UpsertSupplierDayParams{Day: day, ElecKwh: 1}))
	}

	var rows []ledger.Day
	require.NoError(t, json.Unmarshal(get(t, limited, "/api/days?days=7").Body.Bytes(), &rows))
	require.Len(t, rows, 1)
	require.Equal(t, "2026-10-25", rows[0].Date)
}
