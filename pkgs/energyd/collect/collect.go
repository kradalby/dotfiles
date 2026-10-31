// Package collect moves data from each source into the ledger store.
package collect

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"time"

	"energyd/db"
	"energyd/db/dbsqlc"
	"energyd/nextenergy"
	"energyd/tz"
)

const (
	maxReplyBytes = 16 << 20
	periodSecs    = 15 * 60

	elecKey = "electricity"
	gasKey  = "gas"

	// recentDays is how far back corrections are re-read each poll.
	recentDays = 7

	energyZeroURL   = "https://public.api.energyzero.nl/public/v1/prices"
	openMeteoURL    = "https://api.open-meteo.com/v1/forecast"
	openMeteoOldURL = "https://archive-api.open-meteo.com/v1/archive"
)

// ErrEmpty means a source answered successfully with no usable data. An empty
// 200 is how these sources fail, so it must never read as success.
var ErrEmpty = errors.New("collect: empty reply")

var errNotFound = errors.New("collect: not found")

func getJSON(ctx context.Context, client *http.Client, rawURL string, out any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rawURL, nil)
	if err != nil {
		return fmt.Errorf("build request: %w", err)
	}

	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("request: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()

	if resp.StatusCode == http.StatusNotFound {
		return errNotFound
	}

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("HTTP %d from %s", resp.StatusCode, req.URL.Host)
	}

	if err := json.NewDecoder(io.LimitReader(resp.Body, maxReplyBytes)).Decode(out); err != nil {
		return fmt.Errorf("decode reply from %s: %w", req.URL.Host, err)
	}

	return nil
}

// Meter polls the HomeWizard P1 meter's local v1 API.
type Meter struct {
	DB     *db.DB
	HTTP   *http.Client
	Target string
}

// Poll stores the registers. Only the first reading of each 15-minute period is
// kept, so polling faster costs nothing.
func (m *Meter) Poll(ctx context.Context, now time.Time) error {
	var data struct {
		Import float64 `json:"total_power_import_kwh"`
		Export float64 `json:"total_power_export_kwh"`
		Gas    float64 `json:"total_gas_m3"`
	}

	if err := getJSON(ctx, m.HTTP, "http://"+m.Target+"/api/v1/data", &data); err != nil {
		return fmt.Errorf("meter: %w", err)
	}

	// shortcut: treats a zero gas register as broken, which assumes a gas meter.
	// Make it depend on the contract if this home ever goes all-electric.
	if data.Import == 0 || data.Gas == 0 {
		return fmt.Errorf("meter: %w", ErrEmpty)
	}

	err := m.DB.InsertReading(ctx, dbsqlc.InsertReadingParams{
		PeriodStart: now.Unix() - now.Unix()%periodSecs,
		ReadAt:      now.Unix(),
		ImportKwh:   data.Import,
		ExportKwh:   data.Export,
		GasM3:       data.Gas,
	})
	if err != nil {
		return fmt.Errorf("meter: store: %w", err)
	}

	return nil
}

// Prices fetches day-ahead prices from EnergyZero's public API.
type Prices struct {
	DB      *db.DB
	HTTP    *http.Client
	BaseURL string
}

// NewPrices builds a fetcher for the real feed.
func NewPrices(d *db.DB, client *http.Client) *Prices {
	return &Prices{DB: d, HTTP: client, BaseURL: energyZeroURL}
}

type priceRow struct {
	Start time.Time `json:"start"`
	End   time.Time `json:"end"`
	Price struct {
		Value string `json:"value"`
	} `json:"price"`
}

func (p *Prices) fetch(ctx context.Context, day time.Time, interval, energyType string) ([]priceRow, error) {
	q := url.Values{
		"date":       {day.In(tz.Amsterdam).Format("02-01-2006")},
		"interval":   {interval},
		"energyType": {energyType},
	}

	var data struct {
		Base []priceRow `json:"base"`
	}

	// EnergyZero answers 404 when it has no rows for this date and resolution.
	err := getJSON(ctx, p.HTTP, p.BaseURL+"?"+q.Encode(), &data)
	if errors.Is(err, errNotFound) {
		return nil, nil
	}

	if err != nil {
		return nil, fmt.Errorf("prices: %w", err)
	}

	return data.Base, nil
}

// Fetch stores prices around day; each answer spans the day before to the day
// after. Tomorrow's prices are simply absent until published. Days from before the
// quarter-hour market have no quarter rows, and hours stand in. The new gas day
// publishes well after local midnight, so missing gas alone is not an error, but
// every cost depends on electricity, so missing electricity is.
func (p *Prices) Fetch(ctx context.Context, day time.Time) error {
	elec, err := p.fetch(ctx, day, "INTERVAL_QUARTER", "ENERGY_TYPE_ELECTRICITY")
	if err != nil {
		return err
	}

	if len(elec) == 0 {
		if elec, err = p.fetch(ctx, day, "INTERVAL_HOUR", "ENERGY_TYPE_ELECTRICITY"); err != nil {
			return err
		}
	}

	gas, err := p.fetch(ctx, day, "INTERVAL_DAY", "ENERGY_TYPE_GAS")
	if err != nil {
		return err
	}

	err = p.DB.Tx(ctx, func(q *dbsqlc.Queries) error {
		if err := storePrices(ctx, q, elecKey, elec); err != nil {
			return err
		}

		return storePrices(ctx, q, gasKey, gas)
	})
	if err != nil {
		return err
	}

	if len(elec) == 0 {
		return fmt.Errorf("prices %s: no electricity: %w", tz.DateString(day), ErrEmpty)
	}

	return nil
}

func storePrices(ctx context.Context, q *dbsqlc.Queries, energy string, rows []priceRow) error {
	for _, r := range rows {
		value, err := strconv.ParseFloat(r.Price.Value, 64)
		if err != nil {
			return fmt.Errorf("prices: bad %s value at %s", energy, r.Start.Format(time.RFC3339))
		}

		err = q.UpsertPrice(ctx, dbsqlc.UpsertPriceParams{
			Energy:      energy,
			PeriodStart: r.Start.Unix(),
			PeriodEnd:   r.End.Unix(),
			EurExVat:    value,
		})
		if err != nil {
			return fmt.Errorf("prices: store: %w", err)
		}
	}

	return nil
}

// Weather fetches daily mean temperature from Open-Meteo.
type Weather struct {
	DB          *db.DB
	HTTP        *http.Client
	ForecastURL string
	ArchiveURL  string
	Latitude    float64
	Longitude   float64
}

// NewWeather builds a fetcher for the real service.
func NewWeather(d *db.DB, client *http.Client, latitude, longitude float64) *Weather {
	return &Weather{
		DB: d, HTTP: client, ForecastURL: openMeteoURL, ArchiveURL: openMeteoOldURL,
		Latitude: latitude, Longitude: longitude,
	}
}

func (w *Weather) query() url.Values {
	return url.Values{
		"latitude":  {strconv.FormatFloat(w.Latitude, 'f', 2, 64)},
		"longitude": {strconv.FormatFloat(w.Longitude, 'f', 2, 64)},
		"daily":     {"temperature_2m_mean"},
		"timezone":  {tz.Amsterdam.String()},
	}
}

// Recent stores the last week, whose forecast values settle as days pass.
func (w *Weather) Recent(ctx context.Context) error {
	q := w.query()
	q.Set("past_days", strconv.Itoa(recentDays))
	q.Set("forecast_days", "1")

	return w.store(ctx, w.ForecastURL+"?"+q.Encode())
}

// Archive stores a range of past days.
func (w *Weather) Archive(ctx context.Context, from, to time.Time) error {
	q := w.query()
	q.Set("start_date", tz.DateString(from))
	q.Set("end_date", tz.DateString(to))

	return w.store(ctx, w.ArchiveURL+"?"+q.Encode())
}

func (w *Weather) store(ctx context.Context, rawURL string) error {
	var data struct {
		Daily struct {
			Time []string   `json:"time"`
			Mean []*float64 `json:"temperature_2m_mean"`
		} `json:"daily"`
	}

	if err := getJSON(ctx, w.HTTP, rawURL, &data); err != nil {
		return fmt.Errorf("weather: %w", err)
	}

	if len(data.Daily.Time) == 0 || len(data.Daily.Time) != len(data.Daily.Mean) {
		return fmt.Errorf("weather: %w", ErrEmpty)
	}

	return w.DB.Tx(ctx, func(q *dbsqlc.Queries) error {
		for i, day := range data.Daily.Time {
			if data.Daily.Mean[i] == nil {
				continue
			}

			err := q.UpsertWeather(ctx, dbsqlc.UpsertWeatherParams{Day: day, MeanC: *data.Daily.Mean[i]})
			if err != nil {
				return fmt.Errorf("weather: store: %w", err)
			}
		}

		return nil
	})
}

// SupplierClient is the part of the NextEnergy client this package uses.
type SupplierClient interface {
	Usage(ctx context.Context, day time.Time, u nextenergy.Utility) (nextenergy.Day, error)
	Fees(ctx context.Context, day time.Time) ([]nextenergy.Fee, error)
	Invoices(ctx context.Context) ([]nextenergy.Invoice, error)
	Contract(ctx context.Context) (nextenergy.Contract, error)
}

// Supplier stores NextEnergy's data.
type Supplier struct {
	DB     *db.DB
	Client SupplierClient
}

// Day reads and stores one local day. The day row lands in one transaction with
// its hours, so a row always means the day is whole.
func (s *Supplier) Day(ctx context.Context, day time.Time, hasGas bool) error {
	elec, err := s.Client.Usage(ctx, day, nextenergy.Electricity)
	if err != nil {
		return fmt.Errorf("supplier %s: %w", tz.DateString(day), err)
	}

	if elec.Missing() {
		// A re-read that says "not delivered" must not wipe a day that was.
		rows, err := s.DB.SupplierDaysBetween(ctx, dbsqlc.SupplierDaysBetweenParams{
			FromDay: tz.DateString(day),
			ToDay:   tz.DateString(day),
		})
		if err != nil {
			return fmt.Errorf("supplier: stored day: %w", err)
		}

		if len(rows) > 0 && rows[0].Status != elec.Status {
			return nil
		}
	}

	var gasHours []nextenergy.Hour

	if hasGas && !elec.Missing() {
		gas, err := s.Client.Usage(ctx, day, nextenergy.Gas)
		if err != nil {
			return fmt.Errorf("supplier %s: %w", tz.DateString(day), err)
		}

		gasHours = gas.Hours
	}

	return s.DB.Tx(ctx, func(q *dbsqlc.Queries) error {
		err := q.UpsertSupplierDay(ctx, dbsqlc.UpsertSupplierDayParams{
			Day:             tz.DateString(day),
			Status:          elec.Status,
			ElecKwh:         elec.Elec.Volume,
			ElecDeliveryEur: elec.Elec.Delivery,
			ElecTaxEur:      elec.Elec.Tax,
			ElecFixedEur:    elec.Elec.Fixed,
			ElecTotalEur:    elec.TotalElec,
			GasM3:           elec.Gas.Volume,
			GasDeliveryEur:  elec.Gas.Delivery,
			GasTaxEur:       elec.Gas.Tax,
			GasFixedEur:     elec.Gas.Fixed,
			GasTotalEur:     elec.TotalGas,
			FetchedAt:       time.Now().Unix(),
		})
		if err != nil {
			return fmt.Errorf("supplier: store day: %w", err)
		}

		if err := storeHours(ctx, q, elecKey, elec.Hours); err != nil {
			return err
		}

		return storeHours(ctx, q, gasKey, gasHours)
	})
}

func storeHours(ctx context.Context, q *dbsqlc.Queries, utility string, hours []nextenergy.Hour) error {
	for _, h := range hours {
		err := q.UpsertSupplierHour(ctx, dbsqlc.UpsertSupplierHourParams{
			Utility:   utility,
			HourStart: h.Start.Unix(),
			Volume:    h.Volume,
		})
		if err != nil {
			return fmt.Errorf("supplier: store hour: %w", err)
		}
	}

	return nil
}

// Recent re-reads the last week: NextEnergy delivers about a day late and can
// correct earlier days. Today is never delivered yet.
func (s *Supplier) Recent(ctx context.Context, today time.Time, hasGas bool) error {
	today = tz.Day(today)

	for d := today.AddDate(0, 0, -recentDays); d.Before(today); d = d.AddDate(0, 0, 1) {
		if err := s.Day(ctx, d, hasGas); err != nil {
			return err
		}
	}

	return nil
}

// Backfill reads each missing day in [from, to), newest first because recent days
// matter most, and an unanswerable old day must not stop everything after it. It
// stops at the first failure, so a broken session never runs on against a real
// account. Running it again resumes at the newest day still missing. progress may
// be nil.
func (s *Supplier) Backfill(ctx context.Context, from, to time.Time, progress func(day time.Time)) error {
	rows, err := s.DB.SupplierDaysBetween(ctx, dbsqlc.SupplierDaysBetweenParams{
		FromDay: tz.DateString(from),
		ToDay:   tz.DateString(to),
	})
	if err != nil {
		return fmt.Errorf("backfill: stored days: %w", err)
	}

	stored := make(map[string]bool, len(rows))
	for _, r := range rows {
		stored[r.Day] = r.Status != "MISS"
	}

	contract, err := s.Client.Contract(ctx)
	if err != nil {
		return fmt.Errorf("backfill: %w", err)
	}

	first := tz.Day(from)

	for d := tz.Day(to).AddDate(0, 0, -1); !d.Before(first); d = d.AddDate(0, 0, -1) {
		if stored[tz.DateString(d)] {
			continue
		}

		if err := s.Day(ctx, d, contract.HasGas); err != nil {
			return fmt.Errorf("backfill: %w", err)
		}

		if progress != nil {
			progress(d)
		}
	}

	return nil
}

// Account refreshes fees and bills. Bills are replaced whole, because nothing
// stored identifies one bill.
func (s *Supplier) Account(ctx context.Context, today time.Time) error {
	fees, err := s.Client.Fees(ctx, today)
	if err != nil {
		return fmt.Errorf("supplier fees: %w", err)
	}

	bills, err := s.Client.Invoices(ctx)
	if err != nil {
		return fmt.Errorf("supplier invoices: %w", err)
	}

	return s.DB.Tx(ctx, func(q *dbsqlc.Queries) error {
		for _, f := range fees {
			err := q.UpsertFee(ctx, dbsqlc.UpsertFeeParams{
				Utility:   f.Utility.String(),
				ValidFrom: f.ValidFrom,
				ValidTo:   f.ValidTo,
				EurExVat:  f.EURExVAT,
			})
			if err != nil {
				return fmt.Errorf("supplier: store fee: %w", err)
			}
		}

		if err := q.DeleteBills(ctx); err != nil {
			return fmt.Errorf("supplier: clear bills: %w", err)
		}

		for _, b := range bills {
			err := q.InsertBill(ctx, dbsqlc.InsertBillParams{
				Kind:        b.Kind,
				PeriodStart: b.PeriodStart,
				PeriodEnd:   b.PeriodEnd,
				Due:         b.Due,
				AmountEur:   b.AmountEUR,
				Paid:        boolInt(b.Paid),
				Credited:    boolInt(b.Credited),
			})
			if err != nil {
				return fmt.Errorf("supplier: store bill: %w", err)
			}
		}

		return nil
	})
}

func boolInt(b bool) int64 {
	if b {
		return 1
	}

	return 0
}
