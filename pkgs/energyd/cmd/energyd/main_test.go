package main

import (
	"strings"
	"testing"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/testutil"
	"github.com/stretchr/testify/require"

	"energyd/ledger"
	"energyd/tz"
)

func local(t *testing.T, s string) time.Time {
	t.Helper()

	v, err := time.ParseInLocation("2006-01-02 15:04", s, tz.Amsterdam)
	require.NoError(t, err)

	return v
}

func TestPriceFetchIsHourlyAndEagerWhileTomorrowIsMissing(t *testing.T) {
	last := local(t, "2026-10-31 13:00")

	require.False(t, priceFetchDue(local(t, "2026-10-31 13:20"), last, true), "fresh and complete")
	require.True(t, priceFetchDue(local(t, "2026-10-31 14:01"), last, true), "hourly regardless")
	require.True(t, priceFetchDue(local(t, "2026-10-31 13:20"), last, false), "published about now and still missing")
	require.False(t, priceFetchDue(local(t, "2026-10-31 09:20"), local(t, "2026-10-31 09:00"), false), "not published before midday")
	require.True(t, priceFetchDue(local(t, "2026-10-31 09:20"), time.Time{}, false), "first fetch after start")
}

// A missing price must be absent, never 0: 0 reads as free energy and an absent
// series is what the alert watches.
func TestMetricsHidePricesThatAreNotKnown(t *testing.T) {
	m := newMetrics(prometheus.NewRegistry())
	m.update(ledger.Snapshot{}, sourceState{})

	require.Equal(t, 0, testutil.CollectAndCount(m.price))
	require.Equal(t, 0, testutil.CollectAndCount(m.gasPrice))
	require.Equal(t, 0, testutil.CollectAndCount(m.band))
	require.Equal(t, 0, testutil.CollectAndCount(m.tomorrowPrice))
	require.Equal(t, 0, testutil.CollectAndCount(m.cheapestStart))
	require.Equal(t, 0, testutil.CollectAndCount(m.settlement))
	require.Equal(t, float64(0), testutil.ToFloat64(m.tomorrowHours))
}

func TestMetricsExposeSnapshot(t *testing.T) {
	m := newMetrics(prometheus.NewRegistry())
	m.update(ledger.Snapshot{
		HasPrice: true, ElecAllIn: 0.4, ElecMarket: 0.2, ElecAllInNext: 0.5, ElecMarketNxt: 0.3, Band: 2,
		HasGasPrice: true, GasAllIn: 1.9,
		TomorrowHours: 24, TomorrowMin: 0.1, TomorrowMean: 0.2, TomorrowMax: 0.3,
		CheapestStart: 1793394000, CheapestMean: 0.15,
		TodayEUR: 3, MonthEUR: 90, NewestDay: 1793314800, NewestDayEUR: 4,
		Mean30dEURPerKWh: 0.33, ComputedErrorRatio: 0.002,
		Estimate: ledger.Estimate{Reliable: true, YearCostEUR: 2000, SettlementEUR: -400, CurrentAdvanceEUR: 150},
	}, sourceState{loginBlocked: true, apiVersionChanged: true, logins: 2})

	require.InDelta(t, 0.4, testutil.ToFloat64(m.price.WithLabelValues("all_in", "current")), 1e-9)
	require.InDelta(t, 0.3, testutil.ToFloat64(m.price.WithLabelValues("market", "next")), 1e-9)
	require.InDelta(t, 1.9, testutil.ToFloat64(m.gasPrice.WithLabelValues()), 1e-9)
	require.InDelta(t, 2, testutil.ToFloat64(m.band.WithLabelValues()), 1e-9)
	require.InDelta(t, 0.3, testutil.ToFloat64(m.tomorrowPrice.WithLabelValues("max")), 1e-9)
	require.InDelta(t, -400, testutil.ToFloat64(m.settlement.WithLabelValues()), 1e-9)
	require.InDelta(t, 1, testutil.ToFloat64(m.loginBlocked), 1e-9)
	require.InDelta(t, 1, testutil.ToFloat64(m.apiVersionChanged), 1e-9)
	require.InDelta(t, 2, testutil.ToFloat64(m.logins), 1e-9)
}

// An estimate with no history would show a confident wrong number on the top row.
func TestMetricsHideAnUnreliableEstimate(t *testing.T) {
	m := newMetrics(prometheus.NewRegistry())
	m.update(ledger.Snapshot{Estimate: ledger.Estimate{Reliable: false, SettlementEUR: -5000, YearCostEUR: 1}}, sourceState{})

	require.Equal(t, 0, testutil.CollectAndCount(m.settlement))
	require.Equal(t, 0, testutil.CollectAndCount(m.yearCost))
	require.InDelta(t, 0, testutil.ToFloat64(m.estimateReliable), 1e-9)
}

func TestMetricNamesAreStable(t *testing.T) {
	reg := prometheus.NewRegistry()
	m := newMetrics(reg)
	m.update(ledger.Snapshot{HasPrice: true, NewestDay: 1793314800}, sourceState{})
	m.sourceSuccess("meter", time.Unix(1793394000, 0))
	m.sourceFailure("meter")

	families, err := reg.Gather()
	require.NoError(t, err)

	names := make([]string, 0, len(families))
	for _, f := range families {
		require.True(t, strings.HasPrefix(f.GetName(), "energyd_"), f.GetName())
		names = append(names, f.GetName())
	}

	for _, want := range []string{
		"energyd_price_eur_per_kwh",
		"energyd_source_last_success_timestamp_seconds",
		"energyd_source_errors_total",
		"energyd_tomorrow_price_hours",
		"energyd_supplier_login_blocked",
		"energyd_supplier_api_version_changed",
		"energyd_newest_supplier_day_timestamp_seconds",
		"energyd_computed_error_ratio",
	} {
		require.Contains(t, names, want)
	}
}

// A failed poll retries within the hour, and a good one rests for six.
func TestSupplierPollIsDueAfterSixHoursSinceSuccess(t *testing.T) {
	now := local(t, "2026-10-31 13:00")

	require.True(t, supplierPollDue(now, time.Time{}), "never succeeded")
	require.False(t, supplierPollDue(now, now.Add(-time.Hour)))
	require.True(t, supplierPollDue(now, now.Add(-6*time.Hour)))
}

// Meter, prices and weather need no login, so a missing login must not stop them.
func TestMissingCredentialsMeanNoSupplierNotAnError(t *testing.T) {
	t.Setenv("NEXTENERGY_USERNAME", "")
	t.Setenv("NEXTENERGY_PASSWORD", "")

	client, err := newClient()
	require.ErrorIs(t, err, errNoCredentials)
	require.Nil(t, client)
}
