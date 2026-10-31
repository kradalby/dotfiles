package ledger

import (
	"context"
	"fmt"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"energyd/db"
	"energyd/db/dbsqlc"
	"energyd/tz"
)

// One real day's shape with its real public prices, kept so the cost formula is
// tested against numbers it did not produce. Volumes are scaled and fees and fixed
// costs invented, with the delivery cost adjusted to match: this repository is
// public, and these are not this home's figures.
var (
	sampleKWh = []float64{
		0.3014, 0.4521, 0.3973, 0.3288, 0.4795, 0.3836, 0.4247, 0.3973, 0.3288, 0.548, 0.3288, 0.2877,
		0.4795, 0.3699, 0.3562, 0.5069, 0.3973, 0.3699, 0.3973, 0.4247, 0.4521, 0.4247, 0.3562, 0.5069,
	}
	sampleQuarters = []float64{
		0.12805, 0.12382, 0.11556, 0.10689, 0.11815, 0.11294, 0.11546, 0.10942,
		0.10538, 0.09419, 0.09187, 0.08878, 0.09125, 0.09017, 0.08952, 0.08906,
		0.08938, 0.08889, 0.09175, 0.08801, 0.10457, 0.0801, 0.0783, 0.09578,
		0.10215, 0.12475, 0.1291, 0.15791, 0.16545, 0.20273, 0.2073, 0.19581,
		0.21425, 0.19127, 0.17834, 0.15929, 0.16914, 0.1499, 0.12982, 0.09861,
		0.11773, 0.09696, 0.06711, 0.01001, 0.07999, 0.06222, 0.06216, 0.05434,
		0.04706, 0.05335, 0.0577, 0.0658, 0.05306, 0.0613, 0.06803, 0.09282,
		0.05836, 0.08526, 0.11208, 0.12925, 0.12702, 0.13498, 0.17027, 0.23313,
		0.20413, 0.23991, 0.25222, 0.26609, 0.25661, 0.2549, 0.2613, 0.27644,
		0.27159, 0.27001, 0.28519, 0.29124, 0.28237, 0.27374, 0.28238, 0.27626,
		0.26654, 0.26492, 0.26122, 0.2474, 0.2552, 0.24996, 0.2409, 0.22886,
		0.24, 0.23274, 0.23672, 0.22665, 0.22852, 0.22071, 0.21724, 0.2073,
	}
)

const (
	sampleKWhTotal  = 9.68864
	sampleDelivery  = 2.10812876036
	sampleFeeElec   = 0.02
	sampleFeeGas    = 0.11
	sampleTaxElec   = 1.0739673356
	sampleFixedElec = -0.2
	sampleFixedGas  = 0.8
)

type fixture struct {
	*testing.T
	db  *db.DB
	led *Ledger
}

func newFixture(t *testing.T, now string) fixture {
	t.Helper()

	d, err := db.Open(context.Background(), filepath.Join(t.TempDir(), "test.db"))
	require.NoError(t, err)
	t.Cleanup(func() { _ = d.Close() })

	l := New(d)
	at := at(t, now)
	l.now = func() time.Time { return at }

	f := fixture{T: t, db: d, led: l}
	f.fee("electricity", "2022-09-10", sampleFeeElec)
	f.fee("gas", "2022-09-10", sampleFeeGas)

	return f
}

func at(t *testing.T, s string) time.Time {
	t.Helper()

	v, err := time.ParseInLocation("2006-01-02 15:04", s, tz.Amsterdam)
	require.NoError(t, err)

	return v
}

func (f fixture) fee(u, from string, eur float64) {
	require.NoError(f, f.db.UpsertFee(f.Context(), dbsqlc.UpsertFeeParams{Utility: u, ValidFrom: from, EurExVat: eur}))
}

func (f fixture) price(energy string, start, end time.Time, eur float64) {
	require.NoError(f, f.db.UpsertPrice(f.Context(), dbsqlc.UpsertPriceParams{
		Energy: energy, PeriodStart: start.Unix(), PeriodEnd: end.Unix(), EurExVat: eur,
	}))
}

func (f fixture) hourlyPrices(day string, eur func(hour int) float64) {
	start := at(f.T, day+" 00:00")
	end := start.AddDate(0, 0, 1)
	for h, i := start, 0; h.Before(end); h, i = h.Add(time.Hour), i+1 {
		f.price("electricity", h, h.Add(time.Hour), eur(i))
	}
}

func (f fixture) gasDay(day string, eur float64) {
	start := at(f.T, day+" 06:00")
	f.price("gas", start, start.AddDate(0, 0, 1), eur)
}

func (f fixture) supplierDay(day string, kwh, delivery, tax, fixedElec, m3, gasDelivery, gasTax, fixedGas float64) {
	require.NoError(f, f.db.UpsertSupplierDay(f.Context(), dbsqlc.UpsertSupplierDayParams{
		Day: day, ElecKwh: kwh, ElecDeliveryEur: delivery, ElecTaxEur: tax, ElecFixedEur: fixedElec,
		ElecTotalEur: delivery + tax + fixedElec,
		GasM3:        m3, GasDeliveryEur: gasDelivery, GasTaxEur: gasTax, GasFixedEur: fixedGas,
		GasTotalEur: gasDelivery + gasTax + fixedGas,
	}))
}

func (f fixture) supplierHour(u string, start time.Time, volume float64) {
	require.NoError(f, f.db.UpsertSupplierHour(f.Context(), dbsqlc.UpsertSupplierHourParams{
		Utility: u, HourStart: start.Unix(), Volume: volume,
	}))
}

func (f fixture) reading(start time.Time, kwh, m3 float64) {
	require.NoError(f, f.db.InsertReading(f.Context(), dbsqlc.InsertReadingParams{
		PeriodStart: start.Unix(), ReadAt: start.Unix(), ImportKwh: kwh, GasM3: m3,
	}))
}

func (f fixture) bill(kind, start, end string, eur float64) {
	require.NoError(f, f.db.InsertBill(f.Context(), dbsqlc.InsertBillParams{
		Kind: kind, PeriodStart: start, PeriodEnd: end, AmountEur: eur,
	}))
}

func (f fixture) weather(day string, mean float64) {
	require.NoError(f, f.db.UpsertWeather(f.Context(), dbsqlc.UpsertWeatherParams{Day: day, MeanC: mean}))
}

func (f fixture) sampleDay() {
	f.Helper()

	start := at(f.T, "2026-10-27 00:00")
	for i, eur := range sampleQuarters {
		s := start.Add(time.Duration(i) * 15 * time.Minute)
		f.price("electricity", s, s.Add(15*time.Minute), eur)
	}

	var sum float64
	for _, v := range sampleKWh {
		sum += v
	}
	for i, v := range sampleKWh {
		f.supplierHour("electricity", start.Add(time.Duration(i)*time.Hour), v*sampleKWhTotal/sum)
	}

	f.supplierDay("2026-10-27", sampleKWhTotal, sampleDelivery, sampleTaxElec, sampleFixedElec, 0.07, 0.0886, 0.0509, sampleFixedGas)
}

func TestComputedElectricityMatchesNextEnergyWithinAPointOnePercent(t *testing.T) {
	f := newFixture(t, "2026-10-29 12:00")
	f.sampleDay()

	days, err := f.led.Days(f.Context(), at(t, "2026-10-27 00:00"), at(t, "2026-10-27 23:00"))
	require.NoError(t, err)
	require.Len(t, days, 1)

	hours, err := f.led.Hours(f.Context(), at(t, "2026-10-27 00:00"), at(t, "2026-10-28 00:00"))
	require.NoError(t, err)
	require.Len(t, hours, 24)

	var computed float64
	for _, h := range hours {
		computed += h.ElecEUR
	}

	want := sampleDelivery + sampleTaxElec
	require.InEpsilon(t, want, computed, 0.001, "computed %.4f against NextEnergy %.4f", computed, want)
}

func TestHoursPreferSupplierVolumeThenMeterAndShowFuturePrices(t *testing.T) {
	f := newFixture(t, "2026-10-28 10:10")
	f.hourlyPrices("2026-10-28", func(int) float64 { return 0.10 })
	f.supplierDay("2026-10-27", 1, 0.2, 0.11085, 0, 1, 1, 0.7268, 0.5)
	f.supplierHour("electricity", at(t, "2026-10-28 08:00"), 0.5)

	f.reading(at(t, "2026-10-28 08:00"), 100, 50)
	f.reading(at(t, "2026-10-28 09:00"), 100.9, 50)
	f.reading(at(t, "2026-10-28 09:15"), 101, 50)
	f.reading(at(t, "2026-10-28 09:30"), 101.25, 50.1)

	rows, err := f.led.Hours(f.Context(), at(t, "2026-10-28 08:00"), at(t, "2026-10-28 12:00"))
	require.NoError(t, err)
	require.Len(t, rows, 4)

	require.InDelta(t, 0.5, rows[0].KWh, 1e-9, "a supplier hour beats the meter")
	require.Equal(t, SourceSupplier, rows[0].Source)

	require.InDelta(t, 0.1+0.25, rows[1].KWh, 1e-9, "meter deltas land in their own hour")
	require.Equal(t, SourceMeter, rows[1].Source)
	require.InDelta(t, 0.1, rows[1].M3, 1e-9)

	require.InDelta(t, 0, rows[3].KWh, 1e-9, "the future has a price and no usage")
	require.InDelta(t, 0.10, rows[3].MarketEUR, 1e-9)
	require.InDelta(t, (0.10+sampleFeeElec)*1.21+0.11085, rows[3].AllInEUR, 1e-9)
}

// A missed poll must cost attribution, never volume, and say so.
func TestMeterGapSpreadsVolumeAndMarksEstimated(t *testing.T) {
	f := newFixture(t, "2026-10-28 12:00")
	f.reading(at(t, "2026-10-28 08:00"), 100, 50)
	f.reading(at(t, "2026-10-28 10:00"), 108, 50) // 8 periods, 1 kWh each

	rows, err := f.led.Hours(f.Context(), at(t, "2026-10-28 08:00"), at(t, "2026-10-28 10:00"))
	require.NoError(t, err)
	require.Len(t, rows, 2)
	require.InDelta(t, 4, rows[0].KWh, 1e-9)
	require.InDelta(t, 4, rows[1].KWh, 1e-9)
	require.True(t, rows[0].Estimated)
}

func TestGasUsesTheGasDayNotTheCalendarDay(t *testing.T) {
	f := newFixture(t, "2026-10-29 12:00")
	f.gasDay("2026-10-26", 0.50)
	f.gasDay("2026-10-27", 1.00)
	f.supplierDay("2026-10-26", 1, 0.2, 0.11, 0, 1, 1, 0.7268, 0.5)
	f.supplierHour("gas", at(t, "2026-10-27 05:00"), 1)
	f.supplierHour("gas", at(t, "2026-10-27 06:00"), 1)

	rows, err := f.led.Hours(f.Context(), at(t, "2026-10-27 05:00"), at(t, "2026-10-27 07:00"))
	require.NoError(t, err)
	require.Len(t, rows, 2)
	require.InDelta(t, (0.50+sampleFeeGas)*1.21+0.7268, rows[0].GasEUR, 1e-9, "05:00 belongs to the previous gas day")
	require.InDelta(t, (1.00+sampleFeeGas)*1.21+0.7268, rows[1].GasEUR, 1e-9, "06:00 starts the new gas day")
}

func TestLocalDaysOnDSTChangesHaveTheRightHours(t *testing.T) {
	for _, tt := range []struct {
		date  string
		hours int
	}{
		{"2026-03-29", 23},
		{"2026-10-25", 25},
		{"2026-10-27", 24},
	} {
		t.Run(tt.date, func(t *testing.T) {
			f := newFixture(t, "2026-12-01 12:00")
			f.hourlyPrices(tt.date, func(int) float64 { return 0.1 })

			start := at(t, tt.date+" 00:00")
			rows, err := f.led.Hours(f.Context(), start, start.AddDate(0, 0, 1))
			require.NoError(t, err)
			require.Len(t, rows, tt.hours)
		})
	}
}

// Fixed cost arrives with NextEnergy's figures; before that the newest known
// value stands in, and the day says it is computed.
func TestDaysPreferNextEnergyFiguresAndFallBackToComputed(t *testing.T) {
	f := newFixture(t, "2026-10-28 12:00")
	f.sampleDay()
	f.hourlyPrices("2026-10-28", func(int) float64 { return 0.10 })
	f.reading(at(t, "2026-10-28 08:00"), 100, 50)
	f.reading(at(t, "2026-10-28 08:15"), 101, 50)

	days, err := f.led.Days(f.Context(), at(t, "2026-10-27 00:00"), at(t, "2026-10-28 12:00"))
	require.NoError(t, err)
	require.Len(t, days, 2)

	billed := days[0]
	require.Equal(t, SourceSupplier, billed.Source)
	require.Equal(t, "2026-10-27", billed.Date)
	require.InDelta(t, sampleDelivery+sampleTaxElec, billed.ElecEnergyEUR, 1e-9)
	require.InDelta(t, sampleFixedElec+sampleFixedGas, billed.FixedEUR, 1e-9)
	require.InDelta(t, sampleDelivery+sampleTaxElec+0.0886+0.0509+sampleFixedElec+sampleFixedGas, billed.TotalEUR, 1e-9)

	today := days[1]
	require.Equal(t, SourceMeter, today.Source)
	require.InDelta(t, 1, today.ElecKWh, 1e-9)
	wantEnergy := (0.10 + sampleFeeElec) * 1.21
	wantEnergy += sampleTaxElec / sampleKWhTotal
	require.InDelta(t, wantEnergy, today.ElecEnergyEUR, 1e-9)
	require.InDelta(t, sampleFixedElec+sampleFixedGas, today.FixedEUR, 1e-9)
}

func TestMissingSupplierDayIsTreatedAsNotDelivered(t *testing.T) {
	f := newFixture(t, "2026-10-28 12:00")
	require.NoError(t, f.db.UpsertSupplierDay(f.Context(), dbsqlc.UpsertSupplierDayParams{Day: "2026-10-27", Status: "MISS"}))
	f.reading(at(t, "2026-10-27 08:00"), 100, 50)
	f.reading(at(t, "2026-10-27 08:15"), 101, 50)

	days, err := f.led.Days(f.Context(), at(t, "2026-10-27 00:00"), at(t, "2026-10-27 12:00"))
	require.NoError(t, err)
	require.Len(t, days, 1)
	require.Equal(t, SourceMeter, days[0].Source)
}

func TestVATWasLowerDuringTheLateTwentyTwentyTwoCut(t *testing.T) {
	require.InDelta(t, 1.09, vatFactor("2022-09-10"), 1e-9)
	require.InDelta(t, 1.09, vatFactor("2022-12-31"), 1e-9)
	require.InDelta(t, 1.21, vatFactor("2023-01-01"), 1e-9)
	require.InDelta(t, 1.21, vatFactor("2022-06-30"), 1e-9)
}

func TestHeatingDegreeDays(t *testing.T) {
	require.InDelta(t, 8, heatingDegrees(10), 1e-9)
	require.InDelta(t, 0, heatingDegrees(19), 1e-9)
}

func TestBandSplitsADayIntoThirds(t *testing.T) {
	f := newFixture(t, "2026-10-28 00:30")
	f.hourlyPrices("2026-10-28", func(h int) float64 { return float64(h) / 100 })

	rows, err := f.led.Hours(f.Context(), at(t, "2026-10-28 00:00"), at(t, "2026-10-29 00:00"))
	require.NoError(t, err)
	require.Equal(t, 0, rows[0].Band)
	require.Equal(t, 1, rows[12].Band)
	require.Equal(t, 2, rows[23].Band)
}

func TestSettlementSubtractsAllTwelveAdvances(t *testing.T) {
	f := newFixture(t, "2026-11-15 12:00")
	f.supplierDay("2026-09-20", 10, 2, 1, 0, 0, 0, 0, 0)
	f.supplierDay("2026-11-14", 10, 2, 1, 0, 0, 0, 0, 0)
	f.bill("Termijnnota", "2026-09-01", "2026-10-01", 500) // previous contract year
	f.bill("Termijnnota", "2026-10-01", "2026-11-01", 200)
	f.bill("Termijnnota", "2026-11-01", "2026-12-01", 150)

	got, err := f.led.Estimate(f.Context())
	require.NoError(t, err)
	require.InDelta(t, 200+150+10*150, got.AdvancesEUR, 1e-9, "billed two, ten more at the current amount")
	require.InDelta(t, 150, got.CurrentAdvanceEUR, 1e-9)
	require.InDelta(t, got.YearCostEUR-got.AdvancesEUR, got.SettlementEUR, 1e-9)
	require.Equal(t, "2026-09-10", got.YearStart)
	require.Equal(t, "2027-09-10", got.YearEnd)
}

func TestEstimateProjectsElectricityAndGasPerDegreeDay(t *testing.T) {
	f := newFixture(t, "2026-09-12 12:00")

	// A year of history: 1 m³ a day of hot water plus 0.5 m³ per degree day.
	day := at(t, "2025-09-12 00:00")
	for day.Before(at(t, "2026-09-12 00:00")) {
		date := tz.DateString(day)
		mean := 18.0
		if day.Month() == time.January {
			mean = 8 // 10 degrees
		}
		f.weather(date, mean)
		m3 := 1 + 0.5*heatingDegrees(mean)
		f.supplierDay(date, 10, 3, 1, -0.25, m3, m3, 0.5*m3, 0.9)
		day = day.AddDate(0, 0, 1)
	}

	got, err := f.led.Estimate(f.Context())
	require.NoError(t, err)
	require.InDelta(t, 1, got.GasBaseM3PerDay, 1e-6)
	require.InDelta(t, 0.5, got.GasM3PerDegree, 1e-6)

	// So far this contract year: 09-10 and 09-11 at 4 + 0.65 + 1.5 energy + fixed.
	remaining := 363.0 // 09-12 through 09-09
	wantElec := remaining * (3 + 1)
	wantFixed := remaining * (-0.25 + 0.9)
	wantGasM3 := remaining*1 + 31*5 // January carries the degree days
	wantGas := wantGasM3 * 1.5
	sofar := 2 * (4 - 0.25 + 1 + 0.5 + 0.9)
	require.InDelta(t, sofar+wantElec+wantFixed+wantGas, got.YearCostEUR, 1)
}

func TestEstimateWithoutHistoryDoesNotInventGas(t *testing.T) {
	f := newFixture(t, "2026-09-12 12:00")
	f.bill("Termijnnota", "2026-10-01", "2026-11-01", 100)

	got, err := f.led.Estimate(f.Context())
	require.NoError(t, err)
	require.False(t, got.Reliable, "no NextEnergy days means no usable projection")
}

func TestContractYearsReconcileDailyFiguresAgainstBills(t *testing.T) {
	f := newFixture(t, "2026-11-15 12:00")
	f.supplierDay("2025-09-10", 1, 100, 0, 0, 0, 0, 0, 0)
	f.supplierDay("2026-09-09", 1, 900, 0, 0, 0, 0, 0, 0)
	f.supplierDay("2026-09-10", 1, 50, 0, 0, 0, 0, 0, 0)
	for m := time.October; m <= time.December; m++ {
		f.bill("Termijnnota", time.Date(2025, m, 1, 0, 0, 0, 0, tz.Amsterdam).Format(time.DateOnly), "x", 100)
	}
	for m := time.January; m <= time.September; m++ {
		f.bill("Termijnnota", time.Date(2026, m, 1, 0, 0, 0, 0, tz.Amsterdam).Format(time.DateOnly), "x", 100)
	}
	f.bill("Jaarnota", "2025-09-10", "2026-09-10", -190)

	years, err := f.led.ContractYears(f.Context())
	require.NoError(t, err)
	require.Len(t, years, 2)

	done := years[0]
	require.Equal(t, "2025-09-10", done.Start)
	require.True(t, done.Complete)
	require.InDelta(t, 1000, done.DailyFiguresEUR, 1e-9)
	require.InDelta(t, 1200, done.AdvancesEUR, 1e-9)
	require.InDelta(t, -190, done.SettlementEUR, 1e-9)
	require.InDelta(t, 1010, done.BilledEUR, 1e-9)
	require.NotNil(t, done.DifferenceEUR)
	require.InDelta(t, 10, *done.DifferenceEUR, 1e-9)

	require.False(t, years[1].Complete)
	require.Nil(t, years[1].DifferenceEUR, "a running year has no meaningful difference yet")
}

func TestCreditedBillsDoNotCount(t *testing.T) {
	f := newFixture(t, "2026-11-15 12:00")
	require.NoError(t, f.db.InsertBill(f.Context(), dbsqlc.InsertBillParams{
		Kind: "Termijnnota", PeriodStart: "2026-10-01", PeriodEnd: "2026-11-01", AmountEur: 999, Credited: 1,
	}))
	f.bill("Termijnnota", "2026-10-01", "2026-11-01", 200)

	got, err := f.led.Estimate(f.Context())
	require.NoError(t, err)
	require.InDelta(t, 200*12, got.AdvancesEUR, 1e-9)
}

func TestMonthsSumDaysAndReportCapture(t *testing.T) {
	f := newFixture(t, "2026-10-29 12:00")
	f.hourlyPrices("2026-10-27", func(h int) float64 {
		if h == 18 {
			return 0.40
		}

		return 0.10
	})
	start := at(t, "2026-10-27 00:00")
	for h := range 24 {
		kwh := 0.1 // the floor
		if h == 18 {
			kwh = 1.1 // all use above the floor lands on the dearest hour
		}
		f.supplierHour("electricity", start.Add(time.Duration(h)*time.Hour), kwh)
	}
	f.supplierDay("2026-10-27", 3.4, 1, 0.5, 0.1, 0, 0, 0, 0)

	months, err := f.led.Months(f.Context(), at(t, "2026-10-01 00:00"), at(t, "2026-10-28 00:00"))
	require.NoError(t, err)
	require.Len(t, months, 1)
	require.Equal(t, "2026-10", months[0].Month)
	require.InDelta(t, 3.4, months[0].ElecKWh, 1e-9)
	require.InDelta(t, 1.6, months[0].TotalEUR, 1e-9)

	mean := (23*0.10 + 0.40) / 24
	weighted := (2.3*0.10 + 1.1*0.40) / 3.4
	require.InDelta(t, (weighted-mean)*100, months[0].CaptureCtPerKWh, 1e-6)
	require.InDelta(t, (0.40-mean)*100, months[0].CaptureAboveFloorCtPerKWh, 1e-6)
}

func TestSnapshotReportsPricesWindowsAndFreshness(t *testing.T) {
	f := newFixture(t, "2026-10-28 10:10")
	f.supplierDay("2026-10-27", 10, 3, 1.1085, -0.25, 1, 1, 0.7268, 0.89)
	f.hourlyPrices("2026-10-28", func(h int) float64 {
		switch h {
		case 14, 15, 16:
			return 0.01
		}

		return 0.20
	})
	f.hourlyPrices("2026-10-29", func(h int) float64 { return 0.30 + float64(h)/1000 })
	f.gasDay("2026-10-28", 0.9)

	got, err := f.led.Snapshot(f.Context())
	require.NoError(t, err)

	tax := 1.1085 / 10.0
	allIn := func(p float64) float64 { return (p+sampleFeeElec)*1.21 + tax }
	require.InDelta(t, allIn(0.20), got.ElecAllIn, 1e-9)
	require.InDelta(t, allIn(0.20), got.ElecAllInNext, 1e-9)
	require.InDelta(t, 0.20, got.ElecMarket, 1e-9)
	require.InDelta(t, (0.9+sampleFeeGas)*1.21+0.7268, got.GasAllIn, 1e-9)
	require.Equal(t, 24, got.TomorrowHours)
	require.InDelta(t, allIn(0.30), got.TomorrowMin, 1e-9)
	require.InDelta(t, allIn(0.323), got.TomorrowMax, 1e-9)
	require.Equal(t, at(t, "2026-10-28 14:00").Unix(), got.CheapestStart)
	require.InDelta(t, allIn(0.01), got.CheapestMean, 1e-9)
	require.Equal(t, at(t, "2026-10-27 00:00").Unix(), got.NewestDay)
	require.InDelta(t, 3+1.1085-0.25+1+0.7268+0.89, got.NewestDayEUR, 1e-9)
	require.InDelta(t, (3+1.1085)/10, got.Mean30dEURPerKWh, 1e-9)
}

func TestSnapshotWithoutTomorrowReportsZeroHours(t *testing.T) {
	f := newFixture(t, "2026-10-28 10:10")
	f.hourlyPrices("2026-10-28", func(int) float64 { return 0.2 })

	got, err := f.led.Snapshot(f.Context())
	require.NoError(t, err)
	require.Equal(t, 0, got.TomorrowHours)
}

func TestComputedErrorRatioComparesEnergyOverRecentDays(t *testing.T) {
	f := newFixture(t, "2026-10-29 12:00")
	f.sampleDay()

	got, err := f.led.Snapshot(f.Context())
	require.NoError(t, err)
	require.Less(t, got.ComputedErrorRatio, 0.01)
}

func TestWeekdayHoursAverageAboveFloorUse(t *testing.T) {
	f := newFixture(t, "2026-10-29 12:00")
	start := at(t, "2026-10-27 00:00") // a Tuesday
	for h := range 24 {
		kwh := 0.2
		if h == 18 {
			kwh = 1.2
		}
		f.supplierHour("electricity", start.Add(time.Duration(h)*time.Hour), kwh)
	}

	rows, err := f.led.WeekdayHours(f.Context(), start, start.AddDate(0, 0, 1))
	require.NoError(t, err)
	require.Len(t, rows, 7)
	require.Equal(t, "Mon", rows[0]["weekday"])
	require.Equal(t, "Tue", rows[1]["weekday"])
	require.InDelta(t, 1.0, rows[1]["h18"], 1e-9)
	require.InDelta(t, 0.0, rows[1]["h03"], 1e-9)
	require.Nil(t, rows[0]["h18"])
}

func TestDegreeDayPeriodsGroupByMonth(t *testing.T) {
	f := newFixture(t, "2026-10-29 12:00")
	f.weather("2026-09-30", 8)
	f.weather("2026-10-01", 8)
	f.weather("2026-10-02", 8)
	f.supplierDay("2026-09-30", 0, 0, 0, 0, 5, 0, 0, 0)
	f.supplierDay("2026-10-01", 0, 0, 0, 0, 5, 0, 0, 0)
	f.supplierDay("2026-10-02", 0, 0, 0, 0, 15, 0, 0, 0)

	got, err := f.led.DegreeDays(f.Context(), at(t, "2026-09-30 00:00"), at(t, "2026-10-03 00:00"), "month")
	require.NoError(t, err)
	require.Len(t, got, 2)
	require.InDelta(t, 20, got[1].M3, 1e-9)
	require.InDelta(t, 20, got[1].DegreeDays, 1e-9)
	require.NotNil(t, got[1].M3PerDegree)
	require.InDelta(t, 1, *got[1].M3PerDegree, 1e-9)
}

func TestMonthsReportTheSameMonthLastYear(t *testing.T) {
	f := newFixture(t, "2026-10-29 12:00")
	f.supplierDay("2025-10-05", 1, 40, 0, 0, 0, 0, 0, 0)
	f.supplierDay("2026-09-05", 1, 10, 0, 0, 0, 0, 0, 0)
	f.supplierDay("2026-10-05", 1, 50, 0, 0, 0, 0, 0, 0)

	months, err := f.led.Months(f.Context(), at(t, "2025-01-01 00:00"), at(t, "2026-11-01 00:00"))
	require.NoError(t, err)
	require.Len(t, months, 3)
	require.Nil(t, months[1].PrevYearTotalEUR, "no September a year earlier")
	require.NotNil(t, months[2].PrevYearTotalEUR)
	require.InDelta(t, 40, *months[2].PrevYearTotalEUR, 1e-9)
}

// A state timeline holds its last value to the end of the range, so without a
// closing empty row the last known hour would colour all of the unknown future.
func TestBandsCloseAfterTheLastKnownPrice(t *testing.T) {
	f := newFixture(t, "2026-10-28 10:10")
	f.hourlyPrices("2026-10-28", func(h int) float64 { return float64(h) / 100 })
	f.reading(at(t, "2026-10-27 08:00"), 100, 50)
	f.reading(at(t, "2026-10-27 08:15"), 101, 50)

	rows, err := f.led.Bands(f.Context(), at(t, "2026-10-27 00:00"), at(t, "2026-10-30 00:00"))
	require.NoError(t, err)
	require.Len(t, rows, 25)
	require.NotNil(t, rows[0].Band)
	require.Equal(t, 0, *rows[0].Band)
	require.Equal(t, at(t, "2026-10-28 00:00").Unix(), rows[0].TS, "an hour with use and no price has no band")

	last := rows[24]
	require.Equal(t, at(t, "2026-10-29 00:00").Unix(), last.TS)
	require.Nil(t, last.Band)
}

func TestBandsWithNoPricesAreEmpty(t *testing.T) {
	f := newFixture(t, "2026-10-28 10:10")

	rows, err := f.led.Bands(f.Context(), at(t, "2026-10-28 00:00"), at(t, "2026-10-29 00:00"))
	require.NoError(t, err)
	require.Empty(t, rows)
}

// A swapped meter or a register that drops must read as a gap. Priced, it would
// show a cost of minus thousands.
func TestNegativeMeterDeltaIsAGapNotACredit(t *testing.T) {
	f := newFixture(t, "2026-10-28 12:00")
	f.hourlyPrices("2026-10-28", func(int) float64 { return 0.1 })
	f.gasDay("2026-10-28", 1)
	f.reading(at(t, "2026-10-28 08:00"), 1000, 8000)
	f.reading(at(t, "2026-10-28 08:15"), 1000.5, 0)
	f.reading(at(t, "2026-10-28 08:30"), 1001, 0.2)

	rows, err := f.led.Hours(f.Context(), at(t, "2026-10-28 08:00"), at(t, "2026-10-28 09:00"))
	require.NoError(t, err)
	require.Len(t, rows, 1)
	require.InDelta(t, 1, rows[0].KWh, 1e-9, "electricity kept counting")
	require.InDelta(t, 0.2, rows[0].M3, 1e-9, "the drop is dropped, the next delta is kept")
	require.True(t, rows[0].Estimated)
	require.Positive(t, rows[0].GasEUR)
}

func TestEstimateIsUnreliableWithoutEnoughHistory(t *testing.T) {
	fullYear := func(f fixture, skipWeather bool, skipFrom string) {
		day := at(f.T, "2025-09-12 00:00")
		for day.Before(at(f.T, "2026-10-12 00:00")) {
			date := tz.DateString(day)
			if !skipWeather {
				f.weather(date, 10)
			}
			if skipFrom == "" || date < skipFrom {
				f.supplierDay(date, 10, 3, 1, -0.25, 1, 1, 0.5, 0.9)
			}
			day = day.AddDate(0, 0, 1)
		}
	}

	t.Run("full history is reliable", func(t *testing.T) {
		f := newFixture(t, "2026-10-12 12:00")
		fullYear(f, false, "")

		got, err := f.led.Estimate(f.Context())
		require.NoError(t, err)
		require.True(t, got.Reliable)
	})

	t.Run("no weather history means no gas projection", func(t *testing.T) {
		f := newFixture(t, "2026-10-12 12:00")
		fullYear(f, true, "")

		got, err := f.led.Estimate(f.Context())
		require.NoError(t, err)
		require.False(t, got.Reliable)
	})

	t.Run("contract year mostly missing", func(t *testing.T) {
		f := newFixture(t, "2026-10-12 12:00")
		fullYear(f, false, "2026-09-11")
		for _, day := range []string{"2026-10-05", "2026-10-06", "2026-10-07", "2026-10-08", "2026-10-09", "2026-10-10", "2026-10-11"} {
			f.supplierDay(day, 10, 3, 1, -0.25, 1, 1, 0.5, 0.9)
		}
		for d := 21; d <= 30; d++ {
			f.supplierDay(fmt.Sprintf("2026-09-%02d", d), 10, 3, 1, -0.25, 1, 1, 0.5, 0.9)
		}

		got, err := f.led.Estimate(f.Context())
		require.NoError(t, err)
		require.False(t, got.Reliable)
	})
}

// Computed euros must not be charted under NextEnergy's name.
func TestDaysCarryNextEnergyFigureOnlyWhenDelivered(t *testing.T) {
	f := newFixture(t, "2026-10-28 12:00")
	f.sampleDay()
	f.hourlyPrices("2026-10-28", func(int) float64 { return 0.1 })
	f.reading(at(t, "2026-10-28 08:00"), 100, 50)
	f.reading(at(t, "2026-10-28 08:15"), 101, 50)

	days, err := f.led.Days(f.Context(), at(t, "2026-10-27 00:00"), at(t, "2026-10-29 00:00"))
	require.NoError(t, err)
	require.Len(t, days, 2)
	require.NotNil(t, days[0].NextEnergyEUR)
	require.InDelta(t, days[0].TotalEUR, *days[0].NextEnergyEUR, 1e-9)
	require.Nil(t, days[1].NextEnergyEUR)
}

// The range limits what a panel gets, and a narrow range must still see last year.
func TestMonthsOutsideTheRangeAreLeftOutButStillCompared(t *testing.T) {
	f := newFixture(t, "2026-10-29 12:00")
	f.supplierDay("2025-10-05", 1, 40, 0, 0, 0, 0, 0, 0)
	f.supplierDay("2026-09-05", 1, 10, 0, 0, 0, 0, 0, 0)
	f.supplierDay("2026-10-05", 1, 50, 0, 0, 0, 0, 0, 0)

	months, err := f.led.Months(f.Context(), at(t, "2026-10-01 00:00"), at(t, "2026-11-01 00:00"))
	require.NoError(t, err)
	require.Len(t, months, 1)
	require.Equal(t, "2026-10", months[0].Month)
	require.NotNil(t, months[0].PrevYearTotalEUR)
	require.InDelta(t, 40, *months[0].PrevYearTotalEUR, 1e-9)
}

func TestContractStartIsTheEarliestFee(t *testing.T) {
	f := newFixture(t, "2026-10-29 12:00")
	f.fee("electricity", "2025-01-01", 0.03)

	got, err := f.led.ContractStart(f.Context())
	require.NoError(t, err)
	require.Equal(t, "2022-09-10", tz.DateString(got))
}

// NextEnergy's hourly gas is rounded to 0.01 m³, so a low-use day reads as all
// zeros. The meter's register has far finer steps, so it wins where it exists.
func TestGasHoursPreferTheMeterOverRoundedSupplierHours(t *testing.T) {
	f := newFixture(t, "2026-10-28 12:00")
	f.supplierHour("gas", at(t, "2026-10-28 08:00"), 0)
	f.supplierHour("electricity", at(t, "2026-10-28 08:00"), 0.5)
	f.reading(at(t, "2026-10-28 08:00"), 100, 50)
	f.reading(at(t, "2026-10-28 08:15"), 101, 50.03)

	rows, err := f.led.Hours(f.Context(), at(t, "2026-10-28 08:00"), at(t, "2026-10-28 09:00"))
	require.NoError(t, err)
	require.Len(t, rows, 1)
	require.InDelta(t, 0.03, rows[0].M3, 1e-9)
	require.InDelta(t, 0.5, rows[0].KWh, 1e-9, "electricity still follows the supplier")
}
