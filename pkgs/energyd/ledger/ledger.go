// Package ledger turns stored readings, prices and NextEnergy's daily figures
// into money. Two levels never mix silently: NextEnergy's day totals are the
// figures it reports, and everything else is computed and labelled as such.
package ledger

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"math"
	"slices"
	"sort"
	"strconv"
	"time"

	"energyd/db"
	"energyd/db/dbsqlc"
	"energyd/tz"
)

const (
	// Energy keys, as stored in prices, supplier_hours and fees.
	Electricity = "electricity"
	Gas         = "gas"

	// SourceSupplier marks NextEnergy's figures, SourceMeter computed ones.
	SourceSupplier = "nextenergy"
	SourceMeter    = "meter"

	dayMissing   = "MISS"
	periodSecs   = 15 * 60
	cheapestSpan = 3 // hours, long enough for a dishwasher or a laundry run

	// heatingBase is the Dutch degree-day convention, not a fit to this home.
	heatingBase = 18.0
)

// Ledger answers questions about stored data. It is read-only.
type Ledger struct {
	db  *db.DB
	now func() time.Time
}

// New builds a ledger over d.
func New(d *db.DB) *Ledger { return &Ledger{db: d, now: time.Now} }

// vatFactor is the VAT multiplier for a local day. Energy VAT was cut to 9% for
// the second half of 2022, inside this contract's history.
func vatFactor(day string) float64 {
	if day >= "2022-07-01" && day <= "2022-12-31" {
		return 1.09
	}

	return 1.21
}

func heatingDegrees(meanC float64) float64 { return max(0, heatingBase-meanC) }

// Hour is one hour of usage and price. Past hours carry usage, and hours whose
// day-ahead price is known carry a price, including future ones.
type Hour struct {
	TS        int64   `json:"ts"`
	KWh       float64 `json:"kwh"`
	M3        float64 `json:"m3"`
	MarketEUR float64 `json:"market_eur_kwh"` // ex VAT, mean of the hour's quarters
	AllInEUR  float64 `json:"all_in_eur_kwh"` // incl fee, tax, VAT
	Band      int     `json:"band"`           // 0 cheap, 1 middle, 2 dear, within the local day
	ElecEUR   float64 `json:"elec_eur"`
	GasEUR    float64 `json:"gas_eur"`
	Source    string  `json:"source"`
	// Estimated means a meter gap spread this hour's volume over several hours.
	Estimated bool `json:"estimated"`

	hasPrice bool
}

// view is everything needed to price a span, loaded once per question.
type view struct {
	days     []dbsqlc.SupplierDay // sorted by day
	byDay    map[string]dbsqlc.SupplierDay
	fees     map[string][]dbsqlc.Fee
	elec     []dbsqlc.Price
	gas      []dbsqlc.Price
	elecHour map[int64]float64
	gasHour  map[int64]float64
	meter    map[int64]meterHour
}

type meterHour struct {
	kwh, m3 float64
	gap     bool
}

func (l *Ledger) load(ctx context.Context, from, to time.Time) (*view, error) {
	v := &view{byDay: map[string]dbsqlc.SupplierDay{}, fees: map[string][]dbsqlc.Fee{}}

	days, err := l.db.SupplierDaysBetween(ctx, dbsqlc.SupplierDaysBetweenParams{FromDay: "", ToDay: "9999"})
	if err != nil {
		return nil, fmt.Errorf("supplier days: %w", err)
	}

	for _, d := range days {
		if d.Status != dayMissing {
			v.days = append(v.days, d)
			v.byDay[d.Day] = d
		}
	}

	fees, err := l.db.ListFees(ctx)
	if err != nil {
		return nil, fmt.Errorf("fees: %w", err)
	}

	for _, f := range fees {
		v.fees[f.Utility] = append(v.fees[f.Utility], f)
	}

	v.elec, err = l.db.PricesBetween(ctx, dbsqlc.PricesBetweenParams{Energy: Electricity, FromTs: from.Unix(), ToTs: to.Unix()})
	if err != nil {
		return nil, fmt.Errorf("electricity prices: %w", err)
	}

	v.gas, err = l.db.PricesBetween(ctx, dbsqlc.PricesBetweenParams{Energy: Gas, FromTs: from.Unix(), ToTs: to.Unix()})
	if err != nil {
		return nil, fmt.Errorf("gas prices: %w", err)
	}

	if v.elecHour, err = l.supplierHours(ctx, Electricity, from, to); err != nil {
		return nil, err
	}

	if v.gasHour, err = l.supplierHours(ctx, Gas, from, to); err != nil {
		return nil, err
	}

	if v.meter, err = l.meterHours(ctx, from, to); err != nil {
		return nil, err
	}

	return v, nil
}

func (l *Ledger) supplierHours(ctx context.Context, utility string, from, to time.Time) (map[int64]float64, error) {
	rows, err := l.db.SupplierHoursBetween(ctx, dbsqlc.SupplierHoursBetweenParams{Utility: utility, FromTs: from.Unix(), ToTs: to.Unix()})
	if err != nil {
		return nil, fmt.Errorf("supplier hours: %w", err)
	}

	out := make(map[int64]float64, len(rows))
	for _, r := range rows {
		out[r.HourStart] = r.Volume
	}

	return out, nil
}

// meterHours spreads register deltas onto hours. A row's registers open its
// period and the next row's close it, so a gap spreads evenly across the
// periods it spans: volume survives, and the hours say they are estimated.
//
// shortcut: export registers are stored but not priced, since this contract has
// no return. Price them here if solar or a battery arrives.
func (l *Ledger) meterHours(ctx context.Context, from, to time.Time) (map[int64]meterHour, error) {
	rows, err := l.db.ReadingsBetween(ctx, dbsqlc.ReadingsBetweenParams{FromTs: from.Unix(), ToTs: to.Unix()})
	if err != nil {
		return nil, fmt.Errorf("readings: %w", err)
	}

	before, err := l.db.LastReadingBefore(ctx, from.Unix())
	switch {
	case errors.Is(err, sql.ErrNoRows):
	case err != nil:
		return nil, fmt.Errorf("reading before: %w", err)
	default:
		rows = append([]dbsqlc.MeterReading{before}, rows...)
	}

	out := map[int64]meterHour{}

	for i := 0; i+1 < len(rows); i++ {
		a, b := rows[i], rows[i+1]
		periods := (b.PeriodStart - a.PeriodStart) / periodSecs
		if periods <= 0 {
			continue
		}

		kwh := (b.ImportKwh - a.ImportKwh) / float64(periods)
		m3 := (b.GasM3 - a.GasM3) / float64(periods)
		gap := periods > 1

		// A register that drops means a swapped meter or a bad reading. Priced, it
		// would show a cost of minus thousands.
		if kwh < 0 {
			kwh, gap = 0, true
		}

		if m3 < 0 {
			m3, gap = 0, true
		}

		for p := range periods {
			start := a.PeriodStart + p*periodSecs
			hour := start - start%3600
			h := out[hour]
			h.kwh += kwh
			h.m3 += m3
			h.gap = h.gap || gap
			out[hour] = h
		}
	}

	return out, nil
}

// feeFor is the fee valid on day. Before the first known row, the first stands
// in: fees are per contract, and older ones are not published.
func (v *view) feeFor(utility, day string) float64 {
	var fee float64

	for i, f := range v.fees[utility] {
		if i == 0 || f.ValidFrom <= day {
			fee = f.EurExVat
		}
	}

	return fee
}

// newestDay is the newest NextEnergy day at or before day that satisfies ok.
func (v *view) newestDay(day string, ok func(dbsqlc.SupplierDay) bool) (dbsqlc.SupplierDay, bool) {
	i := sort.Search(len(v.days), func(i int) bool { return v.days[i].Day > day })

	for i--; i >= 0; i-- {
		if ok(v.days[i]) {
			return v.days[i], true
		}
	}

	return dbsqlc.SupplierDay{}, false
}

// Tax per unit comes from NextEnergy's own day, so rate changes need no code.
func (v *view) taxElec(day string) float64 {
	d, ok := v.newestDay(day, func(d dbsqlc.SupplierDay) bool { return d.ElecKwh > 0 })
	if !ok {
		return 0
	}

	return d.ElecTaxEur / d.ElecKwh
}

func (v *view) taxGas(day string) float64 {
	d, ok := v.newestDay(day, func(d dbsqlc.SupplierDay) bool { return d.GasM3 > 0 })
	if !ok {
		return 0
	}

	return d.GasTaxEur / d.GasM3
}

// fixedFor is NextEnergy's fixed cost for day, or the newest it has reported.
func (v *view) fixedFor(day string) float64 {
	d, ok := v.newestDay(day, func(dbsqlc.SupplierDay) bool { return true })
	if !ok {
		return 0
	}

	return d.ElecFixedEur + d.GasFixedEur
}

// elecPrice is the unweighted mean of the prices inside the hour, which is how
// NextEnergy builds its hourly price from quarters.
func (v *view) elecPrice(hour int64) (float64, bool) {
	i := sort.Search(len(v.elec), func(i int) bool { return v.elec[i].PeriodEnd > hour })

	var sum float64
	var n int

	for ; i < len(v.elec) && v.elec[i].PeriodStart < hour+3600; i++ {
		sum += v.elec[i].EurExVat
		n++
	}

	if n == 0 {
		return 0, false
	}

	return sum / float64(n), true
}

func (v *view) gasPrice(ts int64) (float64, bool) {
	i := sort.Search(len(v.gas), func(i int) bool { return v.gas[i].PeriodEnd > ts })
	if i < len(v.gas) && v.gas[i].PeriodStart <= ts {
		return v.gas[i].EurExVat, true
	}

	return 0, false
}

func (v *view) gasAllIn(ts int64, day string) (float64, bool) {
	p, ok := v.gasPrice(ts)
	if !ok {
		return 0, false
	}

	return (p+v.feeFor(Gas, day))*vatFactor(day) + v.taxGas(day), true
}

func (v *view) elecAllIn(market float64, day string) float64 {
	return (market+v.feeFor(Electricity, day))*vatFactor(day) + v.taxElec(day)
}

// hours prices every hour in [from, to) with data. Bands look at the whole local
// day, so callers pass full days and trim.
func (v *view) hours(from, to time.Time) []Hour {
	start := from.Unix() - from.Unix()%3600
	out := []Hour{}

	for ts := start; ts < to.Unix(); ts += 3600 {
		day := tz.DateString(time.Unix(ts, 0))
		h := Hour{TS: ts, Source: SourceMeter}

		if kwh, ok := v.elecHour[ts]; ok {
			h.KWh, h.Source = kwh, SourceSupplier
		} else if m, ok := v.meter[ts]; ok {
			h.KWh, h.Estimated = m.kwh, m.gap
		}

		// NextEnergy's hourly gas is rounded to 0.01 m³, so a low-use day reads as
		// all zeros. The meter's register has far finer steps, so it wins.
		if m, ok := v.meter[ts]; ok {
			h.M3 = m.m3
			h.Estimated = h.Estimated || m.gap
		} else if m3, ok := v.gasHour[ts]; ok {
			h.M3 = m3
		}

		if p, ok := v.elecPrice(ts); ok {
			h.hasPrice = true
			h.MarketEUR = p
			h.AllInEUR = v.elecAllIn(p, day)
			h.ElecEUR = h.KWh * h.AllInEUR
		}

		if h.M3 != 0 {
			if allIn, ok := v.gasAllIn(ts, day); ok {
				h.GasEUR = h.M3 * allIn
			}
		}

		if h.hasPrice || h.KWh != 0 || h.M3 != 0 {
			out = append(out, h)
		}
	}

	setBands(out)

	return out
}

// setBands splits each local day's priced hours into thirds.
func setBands(hours []Hour) {
	byDay := map[string][]float64{}
	for _, h := range hours {
		if h.hasPrice {
			day := tz.DateString(time.Unix(h.TS, 0))
			byDay[day] = append(byDay[day], h.AllInEUR)
		}
	}

	for _, prices := range byDay {
		slices.Sort(prices)
	}

	for i := range hours {
		h := &hours[i]
		if !h.hasPrice {
			continue
		}

		prices := byDay[tz.DateString(time.Unix(h.TS, 0))]
		n := len(prices)

		switch {
		case h.AllInEUR < prices[n/3]:
			h.Band = 0
		case h.AllInEUR >= prices[2*n/3]:
			h.Band = 2
		default:
			h.Band = 1
		}
	}
}

// fullDays widens a span to local-day boundaries.
func fullDays(from, to time.Time) (time.Time, time.Time) {
	end := tz.Day(to)
	if end.Before(to) {
		end = end.AddDate(0, 0, 1)
	}

	return tz.Day(from), end
}

// Hours returns the priced hours in [from, to).
func (l *Ledger) Hours(ctx context.Context, from, to time.Time) ([]Hour, error) {
	start, end := fullDays(from, to)

	v, err := l.load(ctx, start, end)
	if err != nil {
		return nil, err
	}

	rows := v.hours(start, end)

	return slices.DeleteFunc(rows, func(h Hour) bool {
		return h.TS < from.Unix()-from.Unix()%3600 || h.TS >= to.Unix()
	}), nil
}

// BandRow is one hour's price band. Band is nil on the row that ends the known
// prices.
type BandRow struct {
	TS   int64 `json:"ts"`
	Band *int  `json:"band"`
}

// Bands returns price bands in [from, to), closed by an empty row: a state
// timeline holds its last value to the end of the range, which would colour the
// unknown future.
func (l *Ledger) Bands(ctx context.Context, from, to time.Time) ([]BandRow, error) {
	hours, err := l.Hours(ctx, from, to)
	if err != nil {
		return nil, err
	}

	out := []BandRow{}

	for _, h := range hours {
		if h.hasPrice {
			band := h.Band
			out = append(out, BandRow{TS: h.TS, Band: &band})
		}
	}

	if len(out) > 0 {
		out = append(out, BandRow{TS: out[len(out)-1].TS + 3600})
	}

	return out, nil
}

// Day is one local day of cost.
type Day struct {
	TS            int64   `json:"ts"`
	Date          string  `json:"date"`
	Source        string  `json:"source"`
	ElecKWh       float64 `json:"elec_kwh"`
	GasM3         float64 `json:"gas_m3"`
	ElecEnergyEUR float64 `json:"elec_energy_eur"`
	GasEnergyEUR  float64 `json:"gas_energy_eur"`
	FixedEUR      float64 `json:"fixed_eur"`
	TotalEUR      float64 `json:"total_eur"`
	ComputedEUR   float64 `json:"computed_eur"`
	// NextEnergyEUR is NextEnergy's own figure, nil until it has delivered the day.
	NextEnergyEUR *float64 `json:"nextenergy_eur"`
	MeanC         *float64 `json:"mean_c"`
	DegreeDays    float64  `json:"degree_days"`

	computedElec float64
}

// Days returns the local days with data in [from, to).
func (l *Ledger) Days(ctx context.Context, from, to time.Time) ([]Day, error) {
	start, end := fullDays(from, to)

	v, err := l.load(ctx, start, end)
	if err != nil {
		return nil, err
	}

	weather, err := l.weather(ctx, start, end)
	if err != nil {
		return nil, err
	}

	return v.daysFrom(start, end, to, weather), nil
}

func (v *view) daysFrom(start, end, to time.Time, weather map[string]float64) []Day {
	type sums struct{ kwh, m3, elec, gas float64 }

	byDay := map[string]sums{}
	for _, h := range v.hours(start, end) {
		date := tz.DateString(time.Unix(h.TS, 0))
		s := byDay[date]
		s.kwh += h.KWh
		s.m3 += h.M3
		s.elec += h.ElecEUR
		s.gas += h.GasEUR
		byDay[date] = s
	}

	out := []Day{}

	for d := start; d.Before(end) && d.Before(to); d = d.AddDate(0, 0, 1) {
		date := tz.DateString(d)
		s, measured := byDay[date]
		supplier, billed := v.byDay[date]

		if !billed && (s.kwh == 0 && s.m3 == 0) {
			continue
		}

		row := Day{
			TS:           d.Unix(),
			Date:         date,
			computedElec: s.elec,
			ComputedEUR:  s.elec + s.gas + v.fixedFor(date),
		}

		if mean, ok := weather[date]; ok {
			row.MeanC = &mean
			row.DegreeDays = heatingDegrees(mean)
		}

		if billed {
			row.Source = SourceSupplier
			row.ElecKWh = supplier.ElecKwh
			row.GasM3 = supplier.GasM3
			row.ElecEnergyEUR = supplier.ElecDeliveryEur + supplier.ElecTaxEur
			row.GasEnergyEUR = supplier.GasDeliveryEur + supplier.GasTaxEur
			row.FixedEUR = supplier.ElecFixedEur + supplier.GasFixedEur
			row.TotalEUR = supplier.ElecTotalEur + supplier.GasTotalEur
			reported := row.TotalEUR
			row.NextEnergyEUR = &reported
		} else if measured {
			row.Source = SourceMeter
			row.ElecKWh = s.kwh
			row.GasM3 = s.m3
			row.ElecEnergyEUR = s.elec
			row.GasEnergyEUR = s.gas
			row.FixedEUR = v.fixedFor(date)
			row.TotalEUR = row.ElecEnergyEUR + row.GasEnergyEUR + row.FixedEUR
		}

		out = append(out, row)
	}

	return out
}

func (l *Ledger) weather(ctx context.Context, from, to time.Time) (map[string]float64, error) {
	rows, err := l.db.WeatherBetween(ctx, dbsqlc.WeatherBetweenParams{FromDay: tz.DateString(from), ToDay: tz.DateString(to)})
	if err != nil {
		return nil, fmt.Errorf("weather: %w", err)
	}

	out := make(map[string]float64, len(rows))
	for _, r := range rows {
		out[r.Day] = r.MeanC
	}

	return out, nil
}

// Month is one local month of cost, plus price capture: the load-weighted market
// price minus the plain mean. Zero means use ignores price, and negative means
// use lands on cheap hours. A constant load has zero capture by construction, so
// the above-floor figure is the one that shows behaviour.
type Month struct {
	TS                        int64   `json:"ts"`
	Month                     string  `json:"month"`
	ElecKWh                   float64 `json:"elec_kwh"`
	GasM3                     float64 `json:"gas_m3"`
	ElecEnergyEUR             float64 `json:"elec_energy_eur"`
	GasEnergyEUR              float64 `json:"gas_energy_eur"`
	FixedEUR                  float64 `json:"fixed_eur"`
	TotalEUR                  float64 `json:"total_eur"`
	DegreeDays                float64 `json:"degree_days"`
	CaptureCtPerKWh           float64 `json:"capture_ct_kwh"`
	CaptureAboveFloorCtPerKWh float64 `json:"capture_above_floor_ct_kwh"`
	// PrevYearTotalEUR is the same month a year earlier, when stored in the range.
	PrevYearTotalEUR *float64 `json:"prev_year_total_eur"`
}

// Months returns the local months with data in [from, to), whole. It reads a year
// further back than it returns, to compare each month with a year earlier.
func (l *Ledger) Months(ctx context.Context, from, to time.Time) ([]Month, error) {
	day, end := fullDays(from, to)
	first := time.Date(day.Year(), day.Month(), 1, 0, 0, 0, 0, tz.Amsterdam)
	start := first.AddDate(-1, 0, 0)

	v, err := l.load(ctx, start, end)
	if err != nil {
		return nil, err
	}

	weather, err := l.weather(ctx, start, end)
	if err != nil {
		return nil, err
	}

	byMonth := map[string]*Month{}
	var order []string

	for _, d := range v.daysFrom(start, end, to, weather) {
		key := d.Date[:7]

		m, ok := byMonth[key]
		if !ok {
			local := time.Unix(d.TS, 0).In(tz.Amsterdam)
			m = &Month{TS: time.Date(local.Year(), local.Month(), 1, 0, 0, 0, 0, tz.Amsterdam).Unix(), Month: key}
			byMonth[key] = m
			order = append(order, key)
		}

		m.ElecKWh += d.ElecKWh
		m.GasM3 += d.GasM3
		m.ElecEnergyEUR += d.ElecEnergyEUR
		m.GasEnergyEUR += d.GasEnergyEUR
		m.FixedEUR += d.FixedEUR
		m.TotalEUR += d.TotalEUR
		m.DegreeDays += d.DegreeDays
	}

	for key, c := range capture(v.hours(start, end)) {
		if m, ok := byMonth[key]; ok {
			m.CaptureCtPerKWh = c.total
			m.CaptureAboveFloorCtPerKWh = c.aboveFloor
		}
	}

	out := make([]Month, 0, len(order))
	for _, key := range order {
		m := byMonth[key]
		if m.TS < first.Unix() {
			continue
		}

		year, err := strconv.Atoi(key[:4])
		if err != nil {
			return nil, fmt.Errorf("month key %q: %w", key, err)
		}

		if prev, ok := byMonth[fmt.Sprintf("%04d%s", year-1, key[4:])]; ok {
			total := prev.TotalEUR
			m.PrevYearTotalEUR = &total
		}

		out = append(out, *m)
	}

	return out, nil
}

type captured struct{ total, aboveFloor float64 }

func capture(hours []Hour) map[string]captured {
	// The floor is each local day's smallest hour: what ran no matter what.
	floor := map[string]float64{}
	for _, h := range hours {
		if h.KWh == 0 {
			continue
		}

		day := tz.DateString(time.Unix(h.TS, 0))
		if f, ok := floor[day]; !ok || h.KWh < f {
			floor[day] = h.KWh
		}
	}

	type sums struct{ price, n, kwh, weighted, above, aboveWeighted float64 }

	byMonth := map[string]*sums{}

	for _, h := range hours {
		if !h.hasPrice {
			continue
		}

		day := tz.DateString(time.Unix(h.TS, 0))

		s, ok := byMonth[day[:7]]
		if !ok {
			s = &sums{}
			byMonth[day[:7]] = s
		}

		s.price += h.MarketEUR
		s.n++
		s.kwh += h.KWh
		s.weighted += h.KWh * h.MarketEUR

		if extra := h.KWh - floor[day]; extra > 0 {
			s.above += extra
			s.aboveWeighted += extra * h.MarketEUR
		}
	}

	out := map[string]captured{}

	for key, s := range byMonth {
		if s.kwh == 0 {
			continue
		}

		mean := s.price / s.n
		c := captured{total: (s.weighted/s.kwh - mean) * 100}

		if s.above > 0 {
			c.aboveFloor = (s.aboveWeighted/s.above - mean) * 100
		}

		out[key] = c
	}

	return out
}

// DegreePeriod is one week or month of gas against heating demand. M3PerDegree is
// nil when the period had too little heating demand to mean anything.
type DegreePeriod struct {
	TS          int64    `json:"ts"`
	M3          float64  `json:"m3"`
	DegreeDays  float64  `json:"degree_days"`
	M3PerDegree *float64 `json:"m3_per_degree"`
}

// DegreeDays groups days into weeks starting Monday, or months. Daily ratios are
// noise, so nothing finer is offered.
func (l *Ledger) DegreeDays(ctx context.Context, from, to time.Time, period string) ([]DegreePeriod, error) {
	days, err := l.Days(ctx, from, to)
	if err != nil {
		return nil, err
	}

	out := []DegreePeriod{}

	for _, d := range days {
		ts := periodStart(time.Unix(d.TS, 0), period).Unix()

		if len(out) == 0 || out[len(out)-1].TS != ts {
			out = append(out, DegreePeriod{TS: ts})
		}

		p := &out[len(out)-1]
		p.M3 += d.GasM3
		p.DegreeDays += d.DegreeDays
	}

	for i := range out {
		if out[i].DegreeDays >= 1 {
			ratio := out[i].M3 / out[i].DegreeDays
			out[i].M3PerDegree = &ratio
		}
	}

	return out, nil
}

func periodStart(t time.Time, period string) time.Time {
	local := t.In(tz.Amsterdam)
	if period == "month" {
		return time.Date(local.Year(), local.Month(), 1, 0, 0, 0, 0, tz.Amsterdam)
	}

	back := (int(local.Weekday()) + 6) % 7

	return tz.Day(local).AddDate(0, 0, -back)
}

// WeekdayHours averages above-floor use by weekday and hour: one row per weekday
// Monday first, one hNN column per hour. An empty cell means no data.
func (l *Ledger) WeekdayHours(ctx context.Context, from, to time.Time) ([]map[string]any, error) {
	start, end := fullDays(from, to)

	v, err := l.load(ctx, start, end)
	if err != nil {
		return nil, err
	}

	hours := v.hours(start, end)

	floor := map[string]float64{}
	for _, h := range hours {
		if h.KWh == 0 {
			continue
		}

		day := tz.DateString(time.Unix(h.TS, 0))
		if f, ok := floor[day]; !ok || h.KWh < f {
			floor[day] = h.KWh
		}
	}

	type cell struct{ sum, n float64 }

	var cells [7][24]cell

	for _, h := range hours {
		if h.KWh == 0 {
			continue
		}

		local := time.Unix(h.TS, 0).In(tz.Amsterdam)
		c := &cells[(int(local.Weekday())+6)%7][local.Hour()]
		c.sum += h.KWh - floor[tz.DateString(local)]
		c.n++
	}

	out := make([]map[string]any, 7)

	for wd, name := range []string{"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"} {
		row := map[string]any{"weekday": name}

		for hour, c := range cells[wd] {
			if c.n > 0 {
				row[fmt.Sprintf("h%02d", hour)] = c.sum / c.n
			}
		}

		out[wd] = row
	}

	return out, nil
}

// contractAnchor is the contract's first tariff day. Contract years and annual
// statements run from its anniversary.
func (v *view) contractAnchor() (time.Time, bool) {
	var first string

	for _, fees := range v.fees {
		for _, f := range fees {
			if first == "" || f.ValidFrom < first {
				first = f.ValidFrom
			}
		}
	}

	anchor, err := tz.ParseDate(first)

	return anchor, err == nil
}

// ErrNoContract means no fee has been read yet, so the contract start is unknown.
var ErrNoContract = errors.New("ledger: no contract known")

// ContractStart is the first day history can exist for.
func (l *Ledger) ContractStart(ctx context.Context) (time.Time, error) {
	now := l.now()

	v, err := l.load(ctx, now, now)
	if err != nil {
		return time.Time{}, err
	}

	anchor, ok := v.contractAnchor()
	if !ok {
		return time.Time{}, ErrNoContract
	}

	return anchor, nil
}

// contractYearStart is the latest anniversary at or before day.
func contractYearStart(anchor, day time.Time) time.Time {
	day = day.In(tz.Amsterdam)
	start := time.Date(day.Year(), anchor.Month(), anchor.Day(), 0, 0, 0, 0, tz.Amsterdam)

	if start.After(day) {
		start = start.AddDate(-1, 0, 0)
	}

	return start
}

// ContractYear reconciles NextEnergy's daily figures against what it billed.
// The difference may be the calorific correction, which daily figures do not
// carry, so it is reported and never hidden.
type ContractYear struct {
	TS              int64   `json:"ts"`
	Start           string  `json:"start"`
	End             string  `json:"end"`
	Complete        bool    `json:"complete"`
	ElecKWh         float64 `json:"elec_kwh"`
	GasM3           float64 `json:"gas_m3"`
	DailyFiguresEUR float64 `json:"daily_figures_eur"`
	AdvancesEUR     float64 `json:"advances_eur"`
	SettlementEUR   float64 `json:"settlement_eur"`
	BilledEUR       float64 `json:"billed_eur"`
	// DifferenceEUR is nil until the year is over and its statement exists.
	DifferenceEUR *float64 `json:"difference_eur"`
}

// ContractYears lists every contract year with data, oldest first.
func (l *Ledger) ContractYears(ctx context.Context) ([]ContractYear, error) {
	now := l.now()

	v, err := l.load(ctx, now, now)
	if err != nil {
		return nil, err
	}

	anchor, ok := v.contractAnchor()
	if !ok {
		return nil, nil
	}

	bills, err := l.db.ListBills(ctx)
	if err != nil {
		return nil, fmt.Errorf("bills: %w", err)
	}

	out := []ContractYear{}

	for start := anchor; !start.After(now); start = start.AddDate(1, 0, 0) {
		end := start.AddDate(1, 0, 0)
		y := ContractYear{TS: start.Unix(), Start: tz.DateString(start), End: tz.DateString(end), Complete: !end.After(now)}

		var seen bool

		for _, d := range v.days {
			if d.Day >= y.Start && d.Day < y.End {
				seen = true
				y.ElecKWh += d.ElecKwh
				y.GasM3 += d.GasM3
				y.DailyFiguresEUR += d.ElecTotalEur + d.GasTotalEur
			}
		}

		for _, b := range bills {
			if b.Credited != 0 || b.PeriodStart < y.Start || b.PeriodStart >= y.End {
				continue
			}

			seen = true

			switch b.Kind {
			case billAdvance:
				y.AdvancesEUR += b.AmountEur
			case billAnnual:
				y.SettlementEUR += b.AmountEur
			}
		}

		if !seen {
			continue
		}

		y.BilledEUR = y.AdvancesEUR + y.SettlementEUR

		if y.Complete {
			difference := y.BilledEUR - y.DailyFiguresEUR
			y.DifferenceEUR = &difference
		}

		out = append(out, y)
	}

	return out, nil
}

const (
	billAdvance = "Termijnnota"
	billAnnual  = "Jaarnota"
)

// Estimate projects the current contract year.
type Estimate struct {
	YearStart         string  `json:"year_start"`
	YearEnd           string  `json:"year_end"`
	CostSoFarEUR      float64 `json:"cost_so_far_eur"`
	YearCostEUR       float64 `json:"year_cost_eur"`
	AdvancesEUR       float64 `json:"advances_eur"`
	CurrentAdvanceEUR float64 `json:"current_advance_eur"`
	SettlementEUR     float64 `json:"settlement_eur"` // negative is a refund
	GasBaseM3PerDay   float64 `json:"gas_base_m3_per_day"`
	GasM3PerDegree    float64 `json:"gas_m3_per_degree"`
	// Reliable is false until there are enough NextEnergy days to project from.
	Reliable bool `json:"reliable"`
}

const (
	estimateRecentDays = 28
	estimateFitDays    = 365
	contractAdvances   = 12

	// estimateMinFitDays and estimateMinNormalDays need a real share of a year:
	// gas is seasonal, so a few months would project the wrong season.
	estimateMinFitDays    = 180
	estimateMinNormalDays = 360
	// estimateMinCoverage is the share of elapsed contract days that must be
	// stored. Missing days vanish from the cost so far, and read as a refund.
	estimateMinCoverage = 0.9
)

// Estimate runs the year-end projection: cost through yesterday, plus electricity
// at the recent daily rate, plus gas from this home's own base use and m³ per
// degree day on a normal year's degree days, plus remaining fixed days, minus all
// twelve advances: billed so far, and the rest at the current amount.
func (l *Ledger) Estimate(ctx context.Context) (Estimate, error) {
	now := l.now()
	today := tz.Day(now)

	v, err := l.load(ctx, today, today)
	if err != nil {
		return Estimate{}, err
	}

	anchor, ok := v.contractAnchor()
	if !ok {
		return Estimate{}, nil
	}

	start := contractYearStart(anchor, now)
	end := start.AddDate(1, 0, 0)
	est := Estimate{YearStart: tz.DateString(start), YearEnd: tz.DateString(end)}

	if err := l.addAdvances(ctx, &est); err != nil {
		return Estimate{}, err
	}

	weather, err := l.db.WeatherBetween(ctx, dbsqlc.WeatherBetweenParams{FromDay: "", ToDay: "9999"})
	if err != nil {
		return Estimate{}, fmt.Errorf("weather: %w", err)
	}

	todayStr := tz.DateString(today)

	for _, d := range v.days {
		if d.Day >= est.YearStart && d.Day < todayStr {
			est.CostSoFarEUR += d.ElecTotalEur + d.GasTotalEur
		}
	}

	recent := daysSince(v.days, tz.DateString(today.AddDate(0, 0, -estimateRecentDays)), todayStr)
	if len(recent) == 0 {
		est.YearCostEUR = est.CostSoFarEUR
		est.SettlementEUR = est.YearCostEUR - est.AdvancesEUR

		return est, nil
	}

	var elec, m3, gasEUR float64
	for _, d := range recent {
		elec += d.ElecDeliveryEur + d.ElecTaxEur
		m3 += d.GasM3
		gasEUR += d.GasDeliveryEur + d.GasTaxEur
	}

	elecPerDay := elec / float64(len(recent))
	fixedPerDay := v.fixedFor(todayStr)

	fit := daysSince(v.days, tz.DateString(today.AddDate(0, 0, -estimateFitDays)), todayStr)
	est.GasBaseM3PerDay, est.GasM3PerDegree = fitGas(fit, weather)

	// Summer has too little gas for a stable unit price, so widen to the year.
	if m3 < 1 {
		m3, gasEUR = 0, 0
		for _, d := range fit {
			m3 += d.GasM3
			gasEUR += d.GasDeliveryEur + d.GasTaxEur
		}
	}

	var gasPerM3 float64
	if m3 > 0 {
		gasPerM3 = gasEUR / m3
	}

	normal := normalDegrees(weather)

	projected := est.CostSoFarEUR
	for d := today; d.Before(end); d = d.AddDate(0, 0, 1) {
		gas := est.GasBaseM3PerDay + est.GasM3PerDegree*normal[tz.DateString(d)[5:]]
		projected += elecPerDay + fixedPerDay + gas*gasPerM3
	}

	est.YearCostEUR = projected
	est.SettlementEUR = est.YearCostEUR - est.AdvancesEUR

	elapsed := len(daysSince(v.days, est.YearStart, todayStr))
	want := math.Round(today.Sub(start).Hours() / 24)

	est.Reliable = len(recent) >= estimateRecentDays/2 &&
		float64(elapsed) >= want*estimateMinCoverage &&
		len(normal) >= estimateMinNormalDays &&
		daysWithWeather(fit, weather) >= estimateMinFitDays

	return est, nil
}

func (l *Ledger) addAdvances(ctx context.Context, est *Estimate) error {
	bills, err := l.db.ListBills(ctx)
	if err != nil {
		return fmt.Errorf("bills: %w", err)
	}

	var billed int
	var newest string

	for _, b := range bills {
		if b.Kind != billAdvance || b.Credited != 0 {
			continue
		}

		if b.PeriodStart > newest {
			newest = b.PeriodStart
			est.CurrentAdvanceEUR = b.AmountEur
		}

		if b.PeriodStart >= est.YearStart && b.PeriodStart < est.YearEnd {
			billed++
			est.AdvancesEUR += b.AmountEur
		}
	}

	est.AdvancesEUR += float64(max(0, contractAdvances-billed)) * est.CurrentAdvanceEUR

	return nil
}

func daysSince(days []dbsqlc.SupplierDay, from, before string) []dbsqlc.SupplierDay {
	var out []dbsqlc.SupplierDay

	for _, d := range days {
		if d.Day >= from && d.Day < before {
			out = append(out, d)
		}
	}

	return out
}

func daysWithWeather(days []dbsqlc.SupplierDay, weather []dbsqlc.WeatherDay) int {
	known := make(map[string]bool, len(weather))
	for _, w := range weather {
		known[w.Day] = true
	}

	var n int

	for _, d := range days {
		if known[d.Day] {
			n++
		}
	}

	return n
}

// fitGas fits m³ = base + perDegree*degrees by least squares. Without enough
// spread in degree days the slope means nothing, so base alone carries the mean.
func fitGas(days []dbsqlc.SupplierDay, weather []dbsqlc.WeatherDay) (base, perDegree float64) {
	degrees := make(map[string]float64, len(weather))
	for _, w := range weather {
		degrees[w.Day] = heatingDegrees(w.MeanC)
	}

	var n, sumX, sumY, sumXX, sumXY float64

	for _, d := range days {
		x, ok := degrees[d.Day]
		if !ok {
			continue
		}

		n++
		sumX += x
		sumY += d.GasM3
		sumXX += x * x
		sumXY += x * d.GasM3
	}

	if n == 0 {
		return 0, 0
	}

	denominator := n*sumXX - sumX*sumX
	if math.Abs(denominator) < 1e-9 {
		return sumY / n, 0
	}

	perDegree = max(0, (n*sumXY-sumX*sumY)/denominator)
	base = max(0, (sumY-perDegree*sumX)/n)

	return base, perDegree
}

// normalDegrees is mean degree days by MM-DD across every stored year.
func normalDegrees(weather []dbsqlc.WeatherDay) map[string]float64 {
	type mean struct{ sum, n float64 }

	byDay := map[string]mean{}

	for _, w := range weather {
		m := byDay[w.Day[5:]]
		m.sum += heatingDegrees(w.MeanC)
		m.n++
		byDay[w.Day[5:]] = m
	}

	out := make(map[string]float64, len(byDay))
	for k, m := range byDay {
		out[k] = m.sum / m.n
	}

	return out
}

// Snapshot is the current state for Prometheus.
type Snapshot struct {
	HasPrice      bool
	ElecAllIn     float64
	ElecMarket    float64
	ElecAllInNext float64
	ElecMarketNxt float64
	Band          int
	HasGasPrice   bool
	GasAllIn      float64

	TomorrowHours int
	TomorrowMin   float64
	TomorrowMean  float64
	TomorrowMax   float64

	CheapestStart int64
	CheapestMean  float64

	TodayEUR float64
	MonthEUR float64

	NewestDay    int64
	NewestDayEUR float64

	Mean30dEURPerKWh float64
	// ComputedErrorRatio compares computed electricity with NextEnergy's over
	// the last week. Gas stays out: its index can differ by a cent or two, and
	// NextEnergy's total replaces the estimate within a day anyway.
	ComputedErrorRatio float64

	Estimate Estimate
}

// Snapshot computes the current state.
func (l *Ledger) Snapshot(ctx context.Context) (Snapshot, error) {
	now := l.now()
	today := tz.Day(now)
	dayAfter := today.AddDate(0, 0, 2)
	span := today.AddDate(0, 0, -30)

	v, err := l.load(ctx, span, dayAfter)
	if err != nil {
		return Snapshot{}, err
	}

	var s Snapshot

	hours := v.hours(span, dayAfter)
	s.setPrices(hours, now, today)

	if allIn, ok := v.gasAllIn(now.Unix(), tz.DateString(now)); ok {
		s.HasGasPrice, s.GasAllIn = true, allIn
	}

	s.setRecentDays(v, hours, today)

	month := time.Date(today.Year(), today.Month(), 1, 0, 0, 0, 0, tz.Amsterdam)
	tomorrow := today.AddDate(0, 0, 1)

	monthView, err := l.load(ctx, month, tomorrow)
	if err != nil {
		return Snapshot{}, err
	}

	for _, d := range monthView.daysFrom(month, tomorrow, tomorrow, nil) {
		s.MonthEUR += d.TotalEUR
		if d.TS == today.Unix() {
			s.TodayEUR = d.TotalEUR
		}
	}

	if s.Estimate, err = l.Estimate(ctx); err != nil {
		return Snapshot{}, err
	}

	return s, nil
}

func (s *Snapshot) setPrices(hours []Hour, now, today time.Time) {
	hour := now.Unix() - now.Unix()%3600
	tomorrow := today.AddDate(0, 0, 1)
	dayAfter := today.AddDate(0, 0, 2)

	var future []Hour

	for _, h := range hours {
		if !h.hasPrice {
			continue
		}

		switch h.TS {
		case hour:
			s.HasPrice, s.ElecAllIn, s.ElecMarket, s.Band = true, h.AllInEUR, h.MarketEUR, h.Band
		case hour + 3600:
			s.ElecAllInNext, s.ElecMarketNxt = h.AllInEUR, h.MarketEUR
		}

		if h.TS >= hour {
			future = append(future, h)
		}

		if h.TS >= tomorrow.Unix() && h.TS < dayAfter.Unix() {
			if s.TomorrowHours == 0 || h.AllInEUR < s.TomorrowMin {
				s.TomorrowMin = h.AllInEUR
			}

			s.TomorrowMax = max(s.TomorrowMax, h.AllInEUR)
			s.TomorrowMean += h.AllInEUR
			s.TomorrowHours++
		}
	}

	if s.TomorrowHours > 0 {
		s.TomorrowMean /= float64(s.TomorrowHours)
	}

	s.CheapestStart, s.CheapestMean = cheapestWindow(future)
}

// cheapestWindow finds the cheapest run of consecutive hours still ahead.
func cheapestWindow(hours []Hour) (int64, float64) {
	var bestStart int64
	best := math.Inf(1)

	for i := 0; i+cheapestSpan <= len(hours); i++ {
		window := hours[i : i+cheapestSpan]
		if window[cheapestSpan-1].TS-window[0].TS != (cheapestSpan-1)*3600 {
			continue
		}

		var sum float64
		for _, h := range window {
			sum += h.AllInEUR
		}

		if mean := sum / cheapestSpan; mean < best {
			best, bestStart = mean, window[0].TS
		}
	}

	if bestStart == 0 {
		return 0, 0
	}

	return bestStart, best
}

func (s *Snapshot) setRecentDays(v *view, hours []Hour, today time.Time) {
	if d, ok := v.newestDay(tz.DateString(today), func(dbsqlc.SupplierDay) bool { return true }); ok {
		if local, err := tz.ParseDate(d.Day); err == nil {
			s.NewestDay = local.Unix()
		}

		s.NewestDayEUR = d.ElecTotalEur + d.GasTotalEur
	}

	todayStr := tz.DateString(today)

	var kwh, eur float64
	for _, d := range daysSince(v.days, tz.DateString(today.AddDate(0, 0, -30)), todayStr) {
		kwh += d.ElecKwh
		eur += d.ElecDeliveryEur + d.ElecTaxEur
	}

	if kwh > 0 {
		s.Mean30dEURPerKWh = eur / kwh
	}

	computed := map[string]float64{}
	for _, h := range hours {
		computed[tz.DateString(time.Unix(h.TS, 0))] += h.ElecEUR
	}

	var diff, reported float64
	for _, d := range daysSince(v.days, tz.DateString(today.AddDate(0, 0, -7)), todayStr) {
		c, ok := computed[d.Day]
		if !ok || c == 0 {
			continue
		}

		energy := d.ElecDeliveryEur + d.ElecTaxEur
		diff += math.Abs(c - energy)
		reported += energy
	}

	if reported > 0 {
		s.ComputedErrorRatio = diff / reported
	}
}
