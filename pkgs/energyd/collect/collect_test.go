package collect

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"energyd/db"
	"energyd/db/dbsqlc"
	"energyd/nextenergy"
	"energyd/tz"
)

func openDB(t *testing.T) *db.DB {
	t.Helper()

	d, err := db.Open(context.Background(), filepath.Join(t.TempDir(), "test.db"))
	require.NoError(t, err)
	t.Cleanup(func() { _ = d.Close() })

	return d
}

func date(t *testing.T, s string) time.Time {
	t.Helper()

	v, err := tz.ParseDate(s)
	require.NoError(t, err)

	return v
}

func TestMeterStoresRegistersInTheirPeriod(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		require.Equal(t, "/api/v1/data", r.URL.Path)
		fmt.Fprint(w, `{"total_power_import_kwh":1000.5,"total_power_export_kwh":1.5,"total_gas_m3":500.25,"unique_id":"private"}`)
	}))
	defer srv.Close()

	d := openDB(t)
	m := &Meter{DB: d, HTTP: srv.Client(), Target: strings.TrimPrefix(srv.URL, "http://")}

	now := time.Date(2026, 10, 31, 8, 7, 30, 0, time.UTC)
	require.NoError(t, m.Poll(t.Context(), now))

	rows, err := d.ReadingsBetween(t.Context(), dbsqlc.ReadingsBetweenParams{FromTs: 0, ToTs: now.Unix()})
	require.NoError(t, err)
	require.Len(t, rows, 1)
	require.Equal(t, time.Date(2026, 10, 31, 8, 0, 0, 0, time.UTC).Unix(), rows[0].PeriodStart)
	require.Equal(t, now.Unix(), rows[0].ReadAt)
	require.InDelta(t, 1000.5, rows[0].ImportKwh, 1e-9)
	require.InDelta(t, 1.5, rows[0].ExportKwh, 1e-9)
	require.InDelta(t, 500.25, rows[0].GasM3, 1e-9)
}

// A meter that answers with no registers must not look like usage falling to
// zero: the next delta would be a huge negative.
func TestMeterRejectsZeroRegisters(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprint(w, `{"wifi_ssid":"x"}`)
	}))
	defer srv.Close()

	d := openDB(t)
	m := &Meter{DB: d, HTTP: srv.Client(), Target: strings.TrimPrefix(srv.URL, "http://")}

	require.ErrorIs(t, m.Poll(t.Context(), time.Now()), ErrEmpty)
}

// The v1 gas field is marked for removal upstream. A silent zero would read as a
// huge negative delta and then as no gas at all.
func TestMeterRejectsMissingGasRegister(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprint(w, `{"total_power_import_kwh":1000.5}`)
	}))
	defer srv.Close()

	m := &Meter{DB: openDB(t), HTTP: srv.Client(), Target: strings.TrimPrefix(srv.URL, "http://")}
	require.ErrorIs(t, m.Poll(t.Context(), time.Now()), ErrEmpty)
}

func TestMeterFailsOnHTTPError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, "boom", http.StatusBadGateway)
	}))
	defer srv.Close()

	m := &Meter{DB: openDB(t), HTTP: srv.Client(), Target: strings.TrimPrefix(srv.URL, "http://")}
	require.Error(t, m.Poll(t.Context(), time.Now()))
}

// priceServer answers as EnergyZero does: a key with no reply is a 404 with an
// error body, never an empty 200.
func priceServer(t *testing.T, replies map[string]string) *httptest.Server {
	t.Helper()

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		reply, ok := replies[r.URL.Query().Get("energyType")+"/"+r.URL.Query().Get("interval")]
		if !ok {
			w.WriteHeader(http.StatusNotFound)
			fmt.Fprint(w, `{"code":5,"message":"no prices found","details":[]}`)

			return
		}

		fmt.Fprint(w, reply)
	}))
	t.Cleanup(srv.Close)

	return srv
}

const (
	quarterReply = `{"interval":"RESPONSE_INTERVAL_QUARTER","base":[
		{"start":"2026-10-26T23:00:00Z","end":"2026-10-26T23:15:00Z","price":{"value":"0.12805"}},
		{"start":"2026-10-26T23:15:00Z","end":"2026-10-26T23:30:00Z","price":{"value":"-0.01"}}]}`
	hourReply = `{"interval":"RESPONSE_INTERVAL_HOUR","base":[
		{"start":"2023-01-14T23:00:00Z","end":"2023-01-15T00:00:00Z","price":{"value":"0.2"}}]}`
	gasReply = `{"interval":"RESPONSE_INTERVAL_DAY","base":[
		{"start":"2026-10-27T05:00:00Z","end":"2026-10-28T05:00:00Z","price":{"value":"0.955275773208"}}]}`
)

func TestPricesStoreQuartersAndGasDay(t *testing.T) {
	srv := priceServer(t, map[string]string{
		"ENERGY_TYPE_ELECTRICITY/INTERVAL_QUARTER": quarterReply,
		"ENERGY_TYPE_GAS/INTERVAL_DAY":             gasReply,
	})

	d := openDB(t)
	p := &Prices{DB: d, HTTP: srv.Client(), BaseURL: srv.URL}

	require.NoError(t, p.Fetch(t.Context(), date(t, "2026-10-27")))

	elec, err := d.PricesBetween(t.Context(), dbsqlc.PricesBetweenParams{Energy: "electricity", FromTs: 0, ToTs: 1 << 40})
	require.NoError(t, err)
	require.Len(t, elec, 2)
	require.InDelta(t, 0.12805, elec[0].EurExVat, 1e-9)
	require.InDelta(t, -0.01, elec[1].EurExVat, 1e-9, "a negative price is real")

	gas, err := d.PricesBetween(t.Context(), dbsqlc.PricesBetweenParams{Energy: "gas", FromTs: 0, ToTs: 1 << 40})
	require.NoError(t, err)
	require.Len(t, gas, 1)
	require.InDelta(t, 0.955275773208, gas[0].EurExVat, 1e-12)
}

func TestPricesAskForDutchDate(t *testing.T) {
	var got string

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		got = r.URL.Query().Get("date")
		fmt.Fprint(w, quarterReply)
	}))
	defer srv.Close()

	p := &Prices{DB: openDB(t), HTTP: srv.Client(), BaseURL: srv.URL}
	require.NoError(t, p.Fetch(t.Context(), date(t, "2026-10-07")))
	require.Equal(t, "07-10-2026", got)
}

// Quarter prices only exist since the market moved to them; older days answer
// with nothing at that resolution.
func TestPricesFallBackToHoursForOldDays(t *testing.T) {
	srv := priceServer(t, map[string]string{
		"ENERGY_TYPE_ELECTRICITY/INTERVAL_HOUR": hourReply,
	})

	d := openDB(t)
	p := &Prices{DB: d, HTTP: srv.Client(), BaseURL: srv.URL}

	require.NoError(t, p.Fetch(t.Context(), date(t, "2023-01-15")))

	rows, err := d.PricesBetween(t.Context(), dbsqlc.PricesBetweenParams{Energy: "electricity", FromTs: 0, ToTs: 1 << 40})
	require.NoError(t, err)
	require.Len(t, rows, 1)
	require.Equal(t, int64(3600), rows[0].PeriodEnd-rows[0].PeriodStart)
}

// The new gas day is published well after local midnight. Until then gas answers
// 404, and that must not throw away the electricity prices beside it.
func TestPricesKeepElectricityWhenGasIsNotPublished(t *testing.T) {
	srv := priceServer(t, map[string]string{
		"ENERGY_TYPE_ELECTRICITY/INTERVAL_QUARTER": quarterReply,
	})

	d := openDB(t)
	p := &Prices{DB: d, HTTP: srv.Client(), BaseURL: srv.URL}

	require.NoError(t, p.Fetch(t.Context(), date(t, "2026-10-27")))

	rows, err := d.PricesBetween(t.Context(), dbsqlc.PricesBetweenParams{Energy: "electricity", FromTs: 0, ToTs: 1 << 40})
	require.NoError(t, err)
	require.Len(t, rows, 2)
}

// Only a 404 means no rows. Any other failure must stay a failure.
func TestPricesServerErrorIsAnError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, "boom", http.StatusBadGateway)
	}))
	defer srv.Close()

	p := &Prices{DB: openDB(t), HTTP: srv.Client(), BaseURL: srv.URL}
	err := p.Fetch(t.Context(), date(t, "2026-10-27"))
	require.Error(t, err)
	require.NotErrorIs(t, err, ErrEmpty)
}

// Electricity is what every cost depends on, so gas alone must not read as a
// healthy fetch. The gas rows are still worth keeping.
func TestPricesWithoutElectricityIsAnErrorButKeepsGas(t *testing.T) {
	srv := priceServer(t, map[string]string{
		"ENERGY_TYPE_GAS/INTERVAL_DAY": gasReply,
	})

	d := openDB(t)
	p := &Prices{DB: d, HTTP: srv.Client(), BaseURL: srv.URL}
	require.ErrorIs(t, p.Fetch(t.Context(), date(t, "2026-10-27")), ErrEmpty)

	rows, err := d.PricesBetween(t.Context(), dbsqlc.PricesBetweenParams{Energy: "gas", FromTs: 0, ToTs: 1 << 40})
	require.NoError(t, err)
	require.Len(t, rows, 1)
}

func TestPricesEmptyEverywhereIsAnError(t *testing.T) {
	srv := priceServer(t, map[string]string{})

	p := &Prices{DB: openDB(t), HTTP: srv.Client(), BaseURL: srv.URL}
	require.ErrorIs(t, p.Fetch(t.Context(), date(t, "2026-10-27")), ErrEmpty)
}

// An unparsable price must never become a stored zero, which reads as free
// energy.
func TestPricesRejectAnUnparsableValue(t *testing.T) {
	srv := priceServer(t, map[string]string{
		"ENERGY_TYPE_ELECTRICITY/INTERVAL_QUARTER": `{"base":[{"start":"2026-10-26T23:00:00Z","end":"2026-10-26T23:15:00Z","price":{"value":"n/a"}}]}`,
		"ENERGY_TYPE_GAS/INTERVAL_DAY":             gasReply,
	})

	d := openDB(t)
	p := &Prices{DB: d, HTTP: srv.Client(), BaseURL: srv.URL}
	require.Error(t, p.Fetch(t.Context(), date(t, "2026-10-27")))

	rows, err := d.PricesBetween(t.Context(), dbsqlc.PricesBetweenParams{Energy: "electricity", FromTs: 0, ToTs: 1 << 40})
	require.NoError(t, err)
	require.Empty(t, rows)
}

func TestWeatherStoresDailyMeans(t *testing.T) {
	var path string

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		path = r.URL.RawQuery
		fmt.Fprint(w, `{"daily":{"time":["2026-10-29","2026-10-30","2026-10-31"],"temperature_2m_mean":[12.9,10.0,null]}}`)
	}))
	defer srv.Close()

	d := openDB(t)
	w := &Weather{DB: d, HTTP: srv.Client(), ForecastURL: srv.URL, ArchiveURL: srv.URL, Latitude: 52.16, Longitude: 4.49}
	require.NoError(t, w.Recent(t.Context()))

	rows, err := d.WeatherBetween(t.Context(), dbsqlc.WeatherBetweenParams{FromDay: "", ToDay: "9999"})
	require.NoError(t, err)
	require.Len(t, rows, 2, "a null mean is skipped, never stored as zero degrees")
	require.InDelta(t, 12.9, rows[0].MeanC, 1e-9)
	require.Contains(t, path, "timezone=Europe%2FAmsterdam")
}

func TestWeatherArchiveSendsTheRange(t *testing.T) {
	var query string

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		query = r.URL.RawQuery
		fmt.Fprint(w, `{"daily":{"time":["2022-09-10"],"temperature_2m_mean":[16.3]}}`)
	}))
	defer srv.Close()

	w := &Weather{DB: openDB(t), HTTP: srv.Client(), ForecastURL: srv.URL, ArchiveURL: srv.URL}
	require.NoError(t, w.Archive(t.Context(), date(t, "2022-09-10"), date(t, "2022-09-12")))
	require.Contains(t, query, "start_date=2022-09-10")
	require.Contains(t, query, "end_date=2022-09-12")
}

// fakeSupplier stands in for the NextEnergy client.
type fakeSupplier struct {
	days     map[string]nextenergy.Day
	calls    []string
	failOn   string
	emptyOn  func(day string) bool
	fees     []nextenergy.Fee
	invoices []nextenergy.Invoice
}

func (f *fakeSupplier) Usage(_ context.Context, day time.Time, u nextenergy.Utility) (nextenergy.Day, error) {
	key := tz.DateString(day)
	f.calls = append(f.calls, key+"/"+u.String())

	if f.emptyOn != nil && f.emptyOn(key) {
		return nextenergy.Day{}, fmt.Errorf("%w: usage %s has no volume", nextenergy.ErrEmptyReply, key)
	}

	if key == f.failOn && u == nextenergy.Gas {
		return nextenergy.Day{}, errors.New("backend down")
	}

	d := f.days[key]
	d.Date = day
	if !d.Missing() {
		d.Hours = []nextenergy.Hour{{Start: day, Volume: float64(u)}}
	}

	return d, nil
}

func (f *fakeSupplier) Fees(context.Context, time.Time) ([]nextenergy.Fee, error) { return f.fees, nil }

func (f *fakeSupplier) Invoices(context.Context) ([]nextenergy.Invoice, error) {
	return f.invoices, nil
}

func (f *fakeSupplier) Contract(context.Context) (nextenergy.Contract, error) {
	return nextenergy.Contract{ID: 1, HasGas: true}, nil
}

func TestSupplierDayStoresTotalsAndBothUtilitiesHours(t *testing.T) {
	d := openDB(t)
	f := &fakeSupplier{days: map[string]nextenergy.Day{"2026-10-27": {
		Elec:      nextenergy.UtilityTotals{Volume: 7, Delivery: 1.5, Tax: 0.8, Fixed: -0.25},
		Gas:       nextenergy.UtilityTotals{Volume: 0.07, Delivery: 0.09, Tax: 0.05, Fixed: 0.89},
		TotalElec: 2.05, TotalGas: 1.03,
	}}}
	s := &Supplier{DB: d, Client: f}

	require.NoError(t, s.Day(t.Context(), date(t, "2026-10-27"), true))

	rows, err := d.SupplierDaysBetween(t.Context(), dbsqlc.SupplierDaysBetweenParams{FromDay: "", ToDay: "9999"})
	require.NoError(t, err)
	require.Len(t, rows, 1)
	require.InDelta(t, 7, rows[0].ElecKwh, 1e-9)
	require.InDelta(t, 2.05, rows[0].ElecTotalEur, 1e-9)
	require.InDelta(t, 0.89, rows[0].GasFixedEur, 1e-9)

	for utility, want := range map[string]float64{"electricity": 2, "gas": 1} {
		hours, err := d.SupplierHoursBetween(t.Context(), dbsqlc.SupplierHoursBetweenParams{Utility: utility, FromTs: 0, ToTs: 1 << 40})
		require.NoError(t, err)
		require.Len(t, hours, 1)
		require.InDelta(t, want, hours[0].Volume, 1e-9)
	}
}

// A day row means both utilities arrived, so a failure halfway must leave no row
// and backfill reads it again.
func TestSupplierDayFailureLeavesNoRow(t *testing.T) {
	d := openDB(t)
	f := &fakeSupplier{failOn: "2026-10-27"}
	s := &Supplier{DB: d, Client: f}

	require.Error(t, s.Day(t.Context(), date(t, "2026-10-27"), true))

	rows, err := d.SupplierDaysBetween(t.Context(), dbsqlc.SupplierDaysBetweenParams{FromDay: "", ToDay: "9999"})
	require.NoError(t, err)
	require.Empty(t, rows)
}

func TestSupplierDayMissingStoresStatusWithoutHours(t *testing.T) {
	d := openDB(t)
	f := &fakeSupplier{days: map[string]nextenergy.Day{"2026-10-30": {Status: "MISS"}}}
	s := &Supplier{DB: d, Client: f}

	require.NoError(t, s.Day(t.Context(), date(t, "2026-10-30"), true))

	rows, err := d.SupplierDaysBetween(t.Context(), dbsqlc.SupplierDaysBetweenParams{FromDay: "", ToDay: "9999"})
	require.NoError(t, err)
	require.Equal(t, "MISS", rows[0].Status)

	hours, err := d.SupplierHoursBetween(t.Context(), dbsqlc.SupplierHoursBetweenParams{Utility: "electricity", FromTs: 0, ToTs: 1 << 40})
	require.NoError(t, err)
	require.Empty(t, hours)
	require.Equal(t, []string{"2026-10-30/electricity"}, f.calls, "no second call for a day not delivered")
}

// Newest first, because recent days matter most and an unanswerable old day must
// not stop everything after it.
func TestBackfillGoesNewestFirstSkipsStoredDaysAndResumes(t *testing.T) {
	d := openDB(t)
	f := &fakeSupplier{days: map[string]nextenergy.Day{}, failOn: "2022-09-12"}
	s := &Supplier{DB: d, Client: f}

	require.NoError(t, d.UpsertSupplierDay(t.Context(), dbsqlc.UpsertSupplierDayParams{Day: "2022-09-13"}))

	err := s.Backfill(t.Context(), date(t, "2022-09-10"), date(t, "2022-09-14"), nil)
	require.Error(t, err, "backfill stops at the first failure so nothing runs blind")
	require.Equal(t, []string{"2022-09-12/electricity", "2022-09-12/gas"}, f.calls)

	f.calls, f.failOn = nil, ""
	require.NoError(t, s.Backfill(t.Context(), date(t, "2022-09-10"), date(t, "2022-09-14"), nil))
	require.Equal(t, "2022-09-12/electricity", f.calls[0], "resume at the newest missing day")
	require.Len(t, f.calls, 6, "three days, two utilities, end exclusive")
}

// A contract can begin before NextEnergy's history does. The walk must end there
// without failing, on the first run and on every later one, or what follows it
// never runs.
func TestBackfillEndsCleanlyAtTheStartOfHistory(t *testing.T) {
	d := openDB(t)
	f := &fakeSupplier{
		days:    map[string]nextenergy.Day{},
		emptyOn: func(day string) bool { return day < "2022-09-12" },
	}
	s := &Supplier{DB: d, Client: f}

	require.NoError(t, s.Backfill(t.Context(), date(t, "2022-09-10"), date(t, "2022-09-14"), nil))
	require.Equal(t, "2022-09-11/electricity", f.calls[len(f.calls)-1], "nothing older is asked for")

	f.calls = nil
	require.NoError(t, s.Backfill(t.Context(), date(t, "2022-09-10"), date(t, "2022-09-14"), nil))
	require.Equal(t, []string{"2022-09-11/electricity"}, f.calls)
}

func TestBackfillFailsOnAnEmptyDayInsideHistory(t *testing.T) {
	d := openDB(t)
	f := &fakeSupplier{
		days:    map[string]nextenergy.Day{},
		emptyOn: func(day string) bool { return day == "2022-09-12" },
	}
	s := &Supplier{DB: d, Client: f}

	require.NoError(t, d.UpsertSupplierDay(t.Context(), dbsqlc.UpsertSupplierDayParams{Day: "2022-09-10"}))

	err := s.Backfill(t.Context(), date(t, "2022-09-10"), date(t, "2022-09-14"), nil)
	require.ErrorIs(t, err, nextenergy.ErrEmptyReply)
}

// With no answered day to compare against, an empty reply means a broken session.
func TestBackfillFailsWhenNoDayHasEverAnswered(t *testing.T) {
	f := &fakeSupplier{
		days:    map[string]nextenergy.Day{},
		emptyOn: func(string) bool { return true },
	}
	s := &Supplier{DB: openDB(t), Client: f}

	err := s.Backfill(t.Context(), date(t, "2022-09-10"), date(t, "2022-09-14"), nil)
	require.ErrorIs(t, err, nextenergy.ErrEmptyReply)
}

// A re-read that says "not delivered" must not wipe a day that was.
func TestSupplierDayNeverReplacesDeliveredDataWithMissing(t *testing.T) {
	d := openDB(t)
	f := &fakeSupplier{days: map[string]nextenergy.Day{"2026-10-27": {
		Elec: nextenergy.UtilityTotals{Volume: 7}, TotalElec: 2,
	}}}
	s := &Supplier{DB: d, Client: f}

	require.NoError(t, s.Day(t.Context(), date(t, "2026-10-27"), true))

	f.days["2026-10-27"] = nextenergy.Day{Status: "MISS"}
	require.NoError(t, s.Day(t.Context(), date(t, "2026-10-27"), true))

	rows, err := d.SupplierDaysBetween(t.Context(), dbsqlc.SupplierDaysBetweenParams{FromDay: "", ToDay: "9999"})
	require.NoError(t, err)
	require.Len(t, rows, 1)
	require.Empty(t, rows[0].Status)
	require.InDelta(t, 7, rows[0].ElecKwh, 1e-9)
}

func TestRecentRereadsTheLastWeekForCorrections(t *testing.T) {
	d := openDB(t)
	f := &fakeSupplier{days: map[string]nextenergy.Day{}}
	s := &Supplier{DB: d, Client: f}

	today := date(t, "2026-10-31")
	require.NoError(t, s.Recent(t.Context(), today, true))
	require.Equal(t, "2026-10-24/electricity", f.calls[0])
	require.Equal(t, "2026-10-30/gas", f.calls[len(f.calls)-1], "today is not delivered yet")
	require.Len(t, f.calls, 14)
}

func TestFeesAndInvoicesReplaceStoredBills(t *testing.T) {
	d := openDB(t)
	f := &fakeSupplier{
		fees: []nextenergy.Fee{{Utility: nextenergy.Electricity, EURExVAT: 0.02, ValidFrom: "2022-09-10"}},
		invoices: []nextenergy.Invoice{
			{Kind: "Termijnnota", PeriodStart: "2026-11-01", PeriodEnd: "2026-12-01", Due: "2026-10-26", AmountEUR: 150, Paid: true},
		},
	}
	s := &Supplier{DB: d, Client: f}

	require.NoError(t, s.Account(t.Context(), date(t, "2026-10-31")))
	require.NoError(t, s.Account(t.Context(), date(t, "2026-10-31")))

	fees, err := d.ListFees(t.Context())
	require.NoError(t, err)
	require.Len(t, fees, 1)
	require.Equal(t, "electricity", fees[0].Utility)

	bills, err := d.ListBills(t.Context())
	require.NoError(t, err)
	require.Len(t, bills, 1, "a second read must not double the bills")
	require.Equal(t, int64(1), bills[0].Paid)
}
