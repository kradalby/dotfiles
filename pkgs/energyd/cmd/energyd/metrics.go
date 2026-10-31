package main

import (
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"

	"energyd/ledger"
)

// metrics are gauges only: the ledger is the source for money. Values that are
// not known are absent, because 0 reads as free energy.
type metrics struct {
	price            *prometheus.GaugeVec
	gasPrice         *prometheus.GaugeVec
	band             *prometheus.GaugeVec
	tomorrowPrice    *prometheus.GaugeVec
	tomorrowHours    prometheus.Gauge
	cheapestStart    *prometheus.GaugeVec
	cheapestPrice    *prometheus.GaugeVec
	costToday        prometheus.Gauge
	costMonth        prometheus.Gauge
	newestDay        *prometheus.GaugeVec
	newestDayCost    *prometheus.GaugeVec
	meanPrice        *prometheus.GaugeVec
	computedError    prometheus.Gauge
	yearCost         *prometheus.GaugeVec
	settlement       *prometheus.GaugeVec
	advance          *prometheus.GaugeVec
	estimateReliable prometheus.Gauge

	lastSuccess       *prometheus.GaugeVec
	errors            *prometheus.CounterVec
	loginBlocked      prometheus.Gauge
	apiVersionChanged prometheus.Gauge
	logins            prometheus.Gauge
}

func newMetrics(reg prometheus.Registerer) *metrics {
	f := promauto.With(reg)

	gauge := func(name, help string) prometheus.Gauge {
		return f.NewGauge(prometheus.GaugeOpts{Name: name, Help: help})
	}
	optional := func(name, help string, labels ...string) *prometheus.GaugeVec {
		return f.NewGaugeVec(prometheus.GaugeOpts{Name: name, Help: help}, labels)
	}

	return &metrics{
		price:            optional("energyd_price_eur_per_kwh", "Electricity price; market excludes VAT, all_in includes fee, tax and VAT.", "level", "period"),
		gasPrice:         optional("energyd_gas_price_eur_per_m3", "All-in gas price for the current gas day."),
		band:             optional("energyd_price_band", "Current hour within today's prices: 0 cheap, 1 middle, 2 dear."),
		tomorrowPrice:    optional("energyd_tomorrow_price_eur_per_kwh", "All-in electricity price tomorrow.", "stat"),
		tomorrowHours:    gauge("energyd_tomorrow_price_hours", "Hours of tomorrow with a published price."),
		cheapestStart:    optional("energyd_cheapest_window_start_timestamp_seconds", "Start of the cheapest three hours still ahead."),
		cheapestPrice:    optional("energyd_cheapest_window_eur_per_kwh", "Mean all-in price of the cheapest three hours still ahead."),
		costToday:        gauge("energyd_cost_today_eur", "Computed cost of today so far, including fixed cost."),
		costMonth:        gauge("energyd_cost_month_eur", "This month's cost: NextEnergy's daily figures, computed where they have not arrived."),
		newestDay:        optional("energyd_newest_supplier_day_timestamp_seconds", "Local midnight of the newest day NextEnergy has delivered."),
		newestDayCost:    optional("energyd_newest_supplier_day_cost_eur", "NextEnergy's total for its newest delivered day."),
		meanPrice:        optional("energyd_mean_price_30d_eur_per_kwh", "Mean all-in electricity cost per kWh over the last 30 days."),
		computedError:    gauge("energyd_computed_error_ratio", "Computed electricity against NextEnergy's figures over the last week."),
		yearCost:         optional("energyd_year_cost_estimate_eur", "Projected cost of the current contract year."),
		settlement:       optional("energyd_settlement_estimate_eur", "Projected annual settlement; negative is a refund."),
		advance:          optional("energyd_advance_eur", "Current monthly advance."),
		estimateReliable: gauge("energyd_estimate_reliable", "1 when enough NextEnergy days exist to project the year."),

		lastSuccess: optional("energyd_source_last_success_timestamp_seconds", "Last successful read per source.", "source"),
		errors: f.NewCounterVec(prometheus.CounterOpts{
			Name: "energyd_source_errors_total",
			Help: "Failed reads per source.",
		}, []string{"source"}),
		loginBlocked:      gauge("energyd_supplier_login_blocked", "1 while a rejected login is stopping login attempts."),
		apiVersionChanged: gauge("energyd_supplier_api_version_changed", "1 when NextEnergy's backend no longer accepts a hard-coded apiVersion."),
		logins:            gauge("energyd_supplier_logins", "Login attempts since start. Climbing means sessions keep expiring."),
	}
}

// sourceState is the client health the snapshot does not carry.
type sourceState struct {
	loginBlocked      bool
	apiVersionChanged bool
	logins            int
}

func boolGauge(b bool) float64 {
	if b {
		return 1
	}

	return 0
}

func (m *metrics) update(s ledger.Snapshot, state sourceState) {
	for _, v := range []*prometheus.GaugeVec{
		m.price, m.gasPrice, m.band, m.tomorrowPrice, m.cheapestStart, m.cheapestPrice,
		m.newestDay, m.newestDayCost, m.meanPrice, m.yearCost, m.settlement, m.advance,
	} {
		v.Reset()
	}

	if s.HasPrice {
		m.price.WithLabelValues("all_in", "current").Set(s.ElecAllIn)
		m.price.WithLabelValues("market", "current").Set(s.ElecMarket)
		m.band.WithLabelValues().Set(float64(s.Band))

		if s.ElecAllInNext != 0 {
			m.price.WithLabelValues("all_in", "next").Set(s.ElecAllInNext)
			m.price.WithLabelValues("market", "next").Set(s.ElecMarketNxt)
		}
	}

	if s.HasGasPrice {
		m.gasPrice.WithLabelValues().Set(s.GasAllIn)
	}

	m.tomorrowHours.Set(float64(s.TomorrowHours))

	if s.TomorrowHours > 0 {
		m.tomorrowPrice.WithLabelValues("min").Set(s.TomorrowMin)
		m.tomorrowPrice.WithLabelValues("mean").Set(s.TomorrowMean)
		m.tomorrowPrice.WithLabelValues("max").Set(s.TomorrowMax)
	}

	if s.CheapestStart != 0 {
		m.cheapestStart.WithLabelValues().Set(float64(s.CheapestStart))
		m.cheapestPrice.WithLabelValues().Set(s.CheapestMean)
	}

	m.costToday.Set(s.TodayEUR)
	m.costMonth.Set(s.MonthEUR)

	if s.NewestDay != 0 {
		m.newestDay.WithLabelValues().Set(float64(s.NewestDay))
		m.newestDayCost.WithLabelValues().Set(s.NewestDayEUR)
	}

	if s.Mean30dEURPerKWh != 0 {
		m.meanPrice.WithLabelValues().Set(s.Mean30dEURPerKWh)
	}

	m.computedError.Set(s.ComputedErrorRatio)
	m.estimateReliable.Set(boolGauge(s.Estimate.Reliable))

	if s.Estimate.Reliable {
		m.yearCost.WithLabelValues().Set(s.Estimate.YearCostEUR)
		m.settlement.WithLabelValues().Set(s.Estimate.SettlementEUR)
	}

	if s.Estimate.CurrentAdvanceEUR != 0 {
		m.advance.WithLabelValues().Set(s.Estimate.CurrentAdvanceEUR)
	}

	m.loginBlocked.Set(boolGauge(state.loginBlocked))
	m.apiVersionChanged.Set(boolGauge(state.apiVersionChanged))
	m.logins.Set(float64(state.logins))
}

func (m *metrics) sourceSuccess(source string, at time.Time) {
	m.lastSuccess.WithLabelValues(source).Set(float64(at.Unix()))
	m.errors.WithLabelValues(source).Add(0) // the series exists before the first failure
}

func (m *metrics) sourceFailure(source string) { m.errors.WithLabelValues(source).Inc() }
