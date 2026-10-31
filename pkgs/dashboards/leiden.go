package main

import (
	"fmt"

	"github.com/grafana/grafana-foundation-sdk/go/bargauge"
	"github.com/grafana/grafana-foundation-sdk/go/cog"
	"github.com/grafana/grafana-foundation-sdk/go/cog/variants"
	"github.com/grafana/grafana-foundation-sdk/go/common"
	"github.com/grafana/grafana-foundation-sdk/go/dashboard"
	"github.com/grafana/grafana-foundation-sdk/go/prometheus"
	"github.com/grafana/grafana-foundation-sdk/go/stat"
	"github.com/grafana/grafana-foundation-sdk/go/statetimeline"
	"github.com/grafana/grafana-foundation-sdk/go/table"
	"github.com/grafana/grafana-foundation-sdk/go/timeseries"
	"github.com/grafana/grafana-foundation-sdk/go/xychart"
)

const (
	promVar     = "datasource"
	infinityVar = "energyd"

	unitEUR     = "currencyEUR"
	unitKWh     = "kwatth"
	unitM3      = "m3"
	unitWatt    = "watt"
	unitCelsius = "celsius"
	unitVolt    = "volt"

	// One hue per quantity on every panel, checked against Grafana's dark surface.
	colorElec  = "#5794F2"
	colorGas   = "#D6742A"
	colorPrice = "#A566CC"
	colorFixed = "#8E8E8E"

	// grafanaVersion is what panels declare they were written for.
	grafanaVersion = "13.0.0"

	// nowWindow anchors instant queries to now. They run at the end of the panel's
	// range, and the dashboard's range ends tomorrow so the price curve fits.
	nowWindow = "5m"

	hoursURL = "/api/hours?from=${__from:date:seconds}&to=${__to:date:seconds}"
	bandsURL = "/api/bands?from=${__from:date:seconds}&to=${__to:date:seconds}"
	// monthsURL covers 13 months. Panel time overrides do not reach the URL, and a
	// legend reduces over all rows returned.
	monthsURL = "/api/months?days=395"

	// floorWatts is the always-on load: a low percentile and not the minimum,
	// because a dropped reading or a cycling load makes the minimum a lie.
	floorWatts = `max(quantile_over_time(0.05, homewizard_active_power_watts[48h]))`
	meterWatts = `max(homewizard_active_power_watts)`
	plugWatts  = `label_replace(max by (instance) (tasmota_power_watts), "plug", "$1", "instance", "([^.]+).*")`
	// meanPrice prices plugs; it ignores when a plug ran.
	meanPrice = `scalar(energyd_mean_price_30d_eur_per_kwh)`
)

func pad(hour int) string { return fmt.Sprintf("%02d", hour) }

func promDS() common.DataSourceRef {
	return common.DataSourceRef{Type: new("prometheus"), Uid: new("${" + promVar + "}")}
}

func infinityDS() common.DataSourceRef {
	return common.DataSourceRef{Type: new("yesoreyeram-infinity-datasource"), Uid: new("${" + infinityVar + "}")}
}

func prom(expr, legendFmt string) *prometheus.DataqueryBuilder {
	return prometheus.NewDataqueryBuilder().Expr(expr).LegendFormat(legendFmt)
}

func promInstant(expr, legendFmt string) *prometheus.DataqueryBuilder {
	return prom(expr, legendFmt).Instant()
}

type column struct{ selector, text, kind string }

func tsColumn() column { return column{"ts", "time", "timestamp_epoch_s"} }

func num(selector, text string) column { return column{selector, text, "number"} }

func text(selector, title string) column { return column{selector, title, "string"} }

// infinity is a JSON query against energyd's API. The URL is relative, because
// the datasource carries the base URL.
func infinity(url, format string, columns ...column) *variants.UnknownDataqueryBuilder {
	cols := make([]map[string]any, 0, len(columns))
	for _, c := range columns {
		cols = append(cols, map[string]any{"selector": c.selector, "text": c.text, "type": c.kind})
	}

	return variants.NewUnknownDataqueryBuilderFromObject(variants.UnknownDataquery{
		"refId":         "A",
		"datasource":    map[string]any{"type": "yesoreyeram-infinity-datasource", "uid": "${" + infinityVar + "}"},
		"type":          "json",
		"source":        "url",
		"parser":        "backend", // required, or Infinity returns rows unparsed and the panel is empty
		"format":        format,
		"url":           url,
		"url_options":   map[string]any{"method": "GET"},
		"root_selector": "",
		"columns":       cols,
	})
}

func series(url string, columns ...column) *variants.UnknownDataqueryBuilder {
	return infinity(url, "timeseries", append([]column{tsColumn()}, columns...)...)
}

func legend(calcs ...string) *common.VizLegendOptionsBuilder {
	return common.NewVizLegendOptionsBuilder().
		ShowLegend(true).
		DisplayMode(common.LegendDisplayModeTable).
		Placement(common.LegendPlacementBottom).
		Calcs(calcs)
}

func simpleLegend() *common.VizLegendOptionsBuilder {
	return common.NewVizLegendOptionsBuilder().
		ShowLegend(true).
		DisplayMode(common.LegendDisplayModeList).
		Placement(common.LegendPlacementBottom)
}

// palette gives each series its own colour; the SDK's default paints them alike.
func palette() *dashboard.FieldColorBuilder {
	return dashboard.NewFieldColorBuilder().Mode(dashboard.FieldColorModeIdPaletteClassic)
}

func graph(title, desc, unit string, span uint32) *timeseries.PanelBuilder {
	return timeseries.NewPanelBuilder().
		Title(title).Description(desc).Unit(unit).
		Span(span).Height(9).FillOpacity(10).
		ColorScheme(palette()).
		Legend(legend("lastNotNull", "max", "mean"))
}

// bars is the panel type for energy and money: they are amounts per period, so
// a line between them would invent values that never existed.
func bars(title, desc, unit string, span uint32) *timeseries.PanelBuilder {
	return graph(title, desc, unit, span).
		DrawStyle(common.GraphDrawStyleBars).
		BarAlignment(common.BarAlignmentAfter).
		FillOpacity(70).
		LineWidth(0).
		Legend(legend("sum", "max")).
		Datasource(infinityDS())
}

// zeroBased stops an axis starting just below the data, which turns small
// differences between bars into large ones.
func zeroBased(p *timeseries.PanelBuilder) *timeseries.PanelBuilder { return p.AxisSoftMin(0) }

func stacked(p *timeseries.PanelBuilder) *timeseries.PanelBuilder {
	return p.Stacking(common.NewStackingConfigBuilder().Mode(common.StackingModeNormal))
}

// colored pins a series to one hue, so the same quantity keeps its colour on
// every panel however many series a panel has.
func colored(p *timeseries.PanelBuilder, name, color string) *timeseries.PanelBuilder {
	return p.OverrideByName(name, []dashboard.DynamicConfigValue{colorOf(color)})
}

func colorOf(color string) dashboard.DynamicConfigValue {
	return dashboard.DynamicConfigValue{Id: "color", Value: map[string]any{"mode": "fixed", "fixedColor": color}}
}

func lineOnRight(unit string) []dashboard.DynamicConfigValue {
	return []dashboard.DynamicConfigValue{
		{Id: "custom.drawStyle", Value: "line"},
		{Id: "custom.lineInterpolation", Value: "stepAfter"},
		{Id: "custom.axisPlacement", Value: "right"},
		{Id: "custom.fillOpacity", Value: 0},
		{Id: "custom.lineWidth", Value: 2},
		{Id: "unit", Value: unit},
		colorOf(colorPrice),
	}
}

// queries names each query of a panel. Grafana rejects queries sharing an ID, and
// an empty ID counts, which shows an error and drops a series.
func queries(targets ...*prometheus.DataqueryBuilder) []*prometheus.DataqueryBuilder {
	for i, t := range targets {
		t.RefId(string(rune('A' + i)))
	}

	return targets
}

func tile(title, desc, unit string, targets ...*prometheus.DataqueryBuilder) *stat.PanelBuilder {
	p := stat.NewPanelBuilder().
		Title(title).Description(desc).Unit(unit).
		Datasource(promDS()).Span(6).Height(4).
		TimeFrom(nowWindow).
		HideTimeOverride(true).
		GraphMode(common.BigValueGraphModeNone).
		// Vertical puts values side by side. Stacked, the second value overflows a
		// tile this short and is simply not shown.
		Orientation(common.VizOrientationVertical).
		// The default thresholds paint any number above 80 red, which says nothing.
		ColorScheme(dashboard.NewFieldColorBuilder().Mode(dashboard.FieldColorModeIdFixed).FixedColor("text")).
		ReduceOptions(common.NewReduceDataOptionsBuilder().Calcs([]string{"lastNotNull"}))
	for _, t := range queries(targets...) {
		p = p.WithTarget(t)
	}

	return p
}

func threshold(steps ...dashboard.Threshold) *dashboard.ThresholdsConfigBuilder {
	return dashboard.NewThresholdsConfigBuilder().Mode(dashboard.ThresholdsModeAbsolute).Steps(steps)
}

func bandMappings() []dashboard.ValueMapping {
	result := func(label, color string, index int32) dashboard.ValueMappingResult {
		return dashboard.ValueMappingResult{Text: new(label), Color: new(color), Index: new(index)}
	}

	return []dashboard.ValueMapping{{ValueMap: &dashboard.ValueMap{
		Type: dashboard.MappingTypeValueToText,
		Options: map[string]dashboard.ValueMappingResult{
			"0": result("cheap", "green", 0),
			"1": result("middle", "yellow", 1),
			"2": result("dear", "red", 2),
		},
	}}}
}

func eurColumns(names ...string) func(*table.PanelBuilder) *table.PanelBuilder {
	return func(p *table.PanelBuilder) *table.PanelBuilder {
		for _, name := range names {
			p = p.OverrideByName(name, []dashboard.DynamicConfigValue{{Id: "unit", Value: "prefix:€"}})
		}

		return p
	}
}

// versioned declares the Grafana version a panel was written for. Without one,
// Grafana treats an XY chart's options as pre-11 and migrates them, wrapping the
// field matchers again so they match nothing. The SDK has no builder for this.
type versioned struct{ cog.Builder[dashboard.Panel] }

func (v versioned) Build() (dashboard.Panel, error) {
	p, err := v.Builder.Build()
	p.PluginVersion = new(grafanaVersion)

	return p, err
}

func answersPanels() []cog.Builder[dashboard.Panel] {
	return []cog.Builder[dashboard.Panel]{
		tile("Price now", "All-in electricity price this hour: market, fee, tax and VAT. The band says where it sits in today's prices.", unitEUR,
			promInstant(`energyd_price_eur_per_kwh{level="all_in",period="current"}`, "now"),
			promInstant(`energyd_price_eur_per_kwh{level="all_in",period="next"}`, "next hour")),
		tile("Now against today", "Where this hour sits within today's prices: cheapest third, middle, or dearest third.", "none",
			promInstant(`energyd_price_band`, "band")).
			Mappings(bandMappings()).
			ColorMode(common.BigValueColorModeBackground),
		tile("Next cheap window", "Start of the cheapest three hours still ahead, for the dishwasher or the laundry. Automation beats looking at this.", "dateTimeFromNow",
			promInstant(`energyd_cheapest_window_start_timestamp_seconds * 1000`, "starts")),
		tile("Power now", "What the whole home draws right now, at the P1 meter.", unitWatt,
			promInstant(meterWatts, "now")),
		tile("Today (computed)", "Computed cost so far today, including fixed cost. It lags the meter by up to 15 minutes, and NextEnergy's figure replaces it a day later.", unitEUR,
			promInstant(`energyd_cost_today_eur`, "today")),
		tile("Month so far", "This month from NextEnergy's daily figures, computed where they have not arrived, against the monthly advance.", unitEUR,
			promInstant(`energyd_cost_month_eur`, "cost"),
			promInstant(`energyd_advance_eur`, "advance")),
		tile("Year-end settlement (estimate)", "Projected annual statement: contract-year cost minus all twelve advances. Negative is a refund. This is an estimate, not a bill.", unitEUR,
			promInstant(`energyd_settlement_estimate_eur`, "settlement")).
			ColorScheme(dashboard.NewFieldColorBuilder().Mode(dashboard.FieldColorModeIdThresholds)).
			Thresholds(threshold(
				dashboard.Threshold{Color: "green"},
				dashboard.Threshold{Value: new(1.0), Color: "red"},
			)).
			ColorMode(common.BigValueColorModeValue),
		tile("Always-on floor", "The lowest 5% of power over two days, so a dropped reading cannot pull it down, and what that costs in a year at the 30-day mean price. Everything that never turns off is in here, and for this home it is the biggest lever.", unitWatt,
			promInstant(floorWatts, "floor"),
			promInstant(floorWatts+` / 1000 * 8760 * `+meanPrice, "per year")).
			OverrideByName("per year", []dashboard.DynamicConfigValue{{Id: "unit", Value: unitEUR}}),
	}
}

func todayPanels() []cog.Builder[dashboard.Panel] {
	return []cog.Builder[dashboard.Panel]{
		// Two axes on purpose: the question is whether use lines up with price, and
		// that takes both on one time scale.
		colored(bars("Hourly use and price", "Bars are kWh per hour, from NextEnergy when delivered and the meter before that. The step line is the all-in price for that hour, including tomorrow once published.", unitKWh, 24), "kWh", colorElec).
			Legend(legend("mean", "max")).
			WithTarget(series(hoursURL, num("kwh", "kWh"), num("all_in_eur_kwh", "price"))).
			OverrideByName("price", lineOnRight(unitEUR)),
		colored(graph("Power", "What the home draws at the P1 meter, with each smart plug under it. The gap between the top line and the plugs is everything unmetered.", unitWatt, 12), "total", colorElec).
			Datasource(promDS()).
			TimeFrom("6h").
			WithTarget(prom(meterWatts, "total").RefId("A")).
			WithTarget(prom(plugWatts, "{{plug}}").RefId("B")),
		colored(bars("Hourly gas", "m³ per hour from the meter. Every hour of a gas day has the same price, so this shows when the boiler ran and not what it cost.", unitM3, 12), "m³", colorGas).
			Legend(legend("sum", "max")).
			WithTarget(series(hoursURL, num("m3", "m³"))),
		statetimeline.NewPanelBuilder().
			Title("Price band").
			Description("Each hour against its own day's prices: cheapest third, middle, dearest third. Use it to plan loads that can wait.").
			Datasource(infinityDS()).
			Span(24).Height(4).
			Legend(simpleLegend()).
			ShowValue(common.VisibilityModeNever).
			Mappings(bandMappings()).
			WithTarget(series(bandsURL, num("band", "band"))),
	}
}

func monthPanels() []cog.Builder[dashboard.Panel] {
	const window = "[30d]"

	return []cog.Builder[dashboard.Panel]{
		bargauge.NewPanelBuilder().
			Title("Plugs by cost, 30 days").
			Description("Plug kWh times the 30-day mean all-in price. This ignores when a plug ran, so it ranks devices and is not a bill. Unmetered is the meter minus all plugs. A negative value means plugs double-count, for example a plug inside a plug-monitored strip.").
			Unit(unitEUR).
			Datasource(promDS()).Span(12).Height(12).
			TimeFrom(nowWindow).
			HideTimeOverride(true).
			Orientation(common.VizOrientationHorizontal).
			DisplayMode(common.BarGaugeDisplayModeBasic).
			ColorScheme(palette()).
			Legend(simpleLegend()).
			ReduceOptions(common.NewReduceDataOptionsBuilder().Calcs([]string{"lastNotNull"})).
			WithTarget(promInstant(`sort_desc(label_replace(max by (instance) (increase(tasmota_kwh_total`+window+`)) * `+meanPrice+`, "plug", "$1", "instance", "([^.]+).*"))`, "{{plug}}").RefId("A")).
			WithTarget(promInstant(`label_replace((max(avg_over_time(homewizard_active_power_watts`+window+`)) * 720 / 1000 - sum(max by (instance) (increase(tasmota_kwh_total`+window+`)))) * `+meanPrice+`, "plug", "unmetered", "", "")`, "{{plug}}").RefId("B")),
		colored(colored(colored(stacked(bars("Daily cost", "Each day's cost split into electricity, gas and fixed cost. NextEnergy's daily figures once delivered; computed before that.", unitEUR, 12)),
			"electricity", colorElec), "gas", colorGas), "fixed", colorFixed).
			TimeFrom("30d").
			WithTarget(series("/api/days?days=30", num("elec_energy_eur", "electricity"), num("gas_energy_eur", "gas"), num("fixed_eur", "fixed"))),
		colored(colored(graph("Price capture", "Load-weighted market price minus the plain mean, in cents. Zero means use ignores price, and negative means use lands on cheap hours. A constant load has zero capture by construction, so above-floor is the figure that shows behaviour.", "none", 24),
			"all use", colorFixed), "above floor", colorElec).
			Datasource(infinityDS()).
			FillOpacity(0).
			ShowPoints(common.VisibilityModeAlways).
			PointSize(8).
			TimeFrom("13M").
			WithTarget(series(monthsURL, num("capture_ct_kwh", "all use"), num("capture_above_floor_ct_kwh", "above floor"))),
	}
}

func gasPanels() []cog.Builder[dashboard.Panel] {
	return []cog.Builder[dashboard.Panel]{
		colored(bars("Gas per day", "m³ per day. Flat use on warm days is hot water. A negative day is NextEnergy's own correction, often just before the annual statement.", unitM3, 12), "m³", colorGas).
			TimeFrom("90d").
			WithTarget(series("/api/days?days=90", num("gas_m3", "m³"))),
		graph("Outdoor temperature", "Daily mean outdoor temperature, on the same days as the gas bars beside it.", unitCelsius, 12).
			Datasource(infinityDS()).
			TimeFrom("90d").
			WithTarget(series("/api/days?days=90", num("mean_c", "outdoor"))),
		colored(bars("Gas per degree day", "Weekly m³ per degree day, base 18°C. It separates the weather from the house: a rising trend means the home or the boiler got worse. Daily values are noise and are not shown.", unitM3, 12), "m³ per degree day", colorGas).
			TimeFrom("2y").
			WithTarget(series("/api/degreedays?period=week&days=730", num("m3_per_degree", "m³ per degree day"))),
		versioned{xychart.NewPanelBuilder().
			Title("Gas against outdoor temperature").
			Description("One point per day over the last year. The slope is what heating costs per degree colder; the height at warm temperatures is hot water.").
			Unit(unitM3).
			Datasource(infinityDS()).
			Span(12).Height(9).
			ColorScheme(palette()).
			Legend(simpleLegend()).
			Mapping(xychart.SeriesMappingManual).
			Series([]cog.Builder[xychart.XYSeriesConfig]{
				xychart.NewXYSeriesConfigBuilder().
					Name(xychart.NewXychartXYSeriesConfigNameBuilder().Fixed("per day")).
					Frame(xychart.NewXychartXYSeriesConfigFrameBuilder().Matcher(xychart.NewMatcherConfigBuilder().Id("byIndex").Options(0))).
					X(xychart.NewXychartXYSeriesConfigXBuilder().Matcher(xychart.NewMatcherConfigBuilder().Id("byName").Options("outdoor"))).
					Y(xychart.NewXychartXYSeriesConfigYBuilder().Matcher(xychart.NewMatcherConfigBuilder().Id("byName").Options("m³"))),
			}).
			Tooltip(common.NewVizTooltipOptionsBuilder().Mode(common.TooltipDisplayModeSingle).Sort(common.SortOrderNone)).
			TimeFrom("1y").
			OverrideByName("outdoor", []dashboard.DynamicConfigValue{{Id: "unit", Value: unitCelsius}}).
			WithTarget(infinity("/api/days?days=365", "table", num("mean_c", "outdoor"), num("gas_m3", "m³")))},
		graph("Indoor temperature", "Indoor temperature and setpoint from the Nefit thermostat. A setpoint far above indoor means the boiler is catching up.", unitCelsius, 12).
			Datasource(promDS()).
			TimeFrom("7d").
			WithTarget(prom(`nefit_temperature_celsius`, "{{sensor}}")),
		statetimeline.NewPanelBuilder().
			Title("Boiler").
			Description("What the boiler is doing, from the Nefit thermostat. Central heating and hot water explain the gas bars above.").
			Datasource(promDS()).
			Span(24).Height(5).
			Legend(simpleLegend()).
			ShowValue(common.VisibilityModeNever).
			TimeFrom("48h").
			WithTarget(prom(`nefit_boiler_state`, "{{state}}")),
	}
}

func yearPanels() []cog.Builder[dashboard.Panel] {
	eur := eurColumns("daily figures", "advances", "settlement", "billed", "difference")

	return []cog.Builder[dashboard.Panel]{
		colored(zeroBased(bars("Monthly electricity", "kWh per month, 13 months so the same month last year is on screen.", unitKWh, 8)), "kWh", colorElec).
			TimeFrom("13M").
			WithTarget(series(monthsURL, num("elec_kwh", "kWh"))),
		colored(zeroBased(bars("Monthly gas", "m³ per month, 13 months so the same month last year is on screen.", unitM3, 8)), "m³", colorGas).
			TimeFrom("13M").
			WithTarget(series(monthsURL, num("gas_m3", "m³"))),
		colored(zeroBased(bars("Monthly cost against last year", "Total cost per month as bars. The line is the same month a year earlier.", unitEUR, 8)), "this year", colorElec).
			TimeFrom("13M").
			OverrideByName("a year earlier", []dashboard.DynamicConfigValue{
				{Id: "custom.drawStyle", Value: "line"},
				{Id: "custom.lineInterpolation", Value: "stepAfter"},
				{Id: "custom.fillOpacity", Value: 0},
				{Id: "custom.lineWidth", Value: 2},
				colorOf(colorFixed),
			}).
			WithTarget(series(monthsURL, num("total_eur", "this year"), num("prev_year_total_eur", "a year earlier"))),
		eur(table.NewPanelBuilder().
			Title("Contract years").
			Description("Each contract year: NextEnergy's daily figures against what it billed, which is twelve advances plus the annual statement. A difference can be the calorific correction, which daily figures do not carry.").
			Datasource(infinityDS()).
			Span(24).Height(8).
			Decimals(0).
			// Infinity sorts table columns by name, and years read left to right.
			WithTransformation(dashboard.DataTransformerConfig{Id: "organize", Options: map[string]any{
				"indexByName": map[string]int{
					"from": 0, "to": 1, "kWh": 2, "m³": 3, "daily figures": 4,
					"advances": 5, "settlement": 6, "billed": 7, "difference": 8,
				},
			}}).
			WithTarget(infinity("/api/years", "table",
				text("start", "from"), text("end", "to"),
				num("elec_kwh", "kWh"), num("gas_m3", "m³"),
				num("daily_figures_eur", "daily figures"), num("advances_eur", "advances"),
				num("settlement_eur", "settlement"), num("billed_eur", "billed"), num("difference_eur", "difference")))),
		colored(colored(graph("Computed against NextEnergy", "Our computed day cost against NextEnergy's daily figure, so drift in the model shows up instead of hiding. Fixed cost is included in both. The NextEnergy line stops where its figures have not arrived.", unitEUR, 24),
			"NextEnergy", colorElec), "computed", colorPrice).
			Datasource(infinityDS()).
			TimeFrom("30d").
			WithTarget(series("/api/days?days=30", num("nextenergy_eur", "NextEnergy"), num("computed_eur", "computed"))),
	}
}

func detailPanels() []cog.Builder[dashboard.Panel] {
	columns := []column{text("weekday", "day")}
	for hour := range 24 {
		columns = append(columns, num("h"+pad(hour), pad(hour)))
	}

	heat := table.NewPanelBuilder().
		Title("Use above the floor by weekday and hour").
		Description("Mean kWh above each day's smallest hour, over the last 90 days. It shows habits with the constant load taken out.").
		Datasource(infinityDS()).
		Unit("none").
		Decimals(2).
		MinWidth(36).
		Span(24).Height(10).
		// Infinity sorts columns by name, which puts the day last.
		WithTransformation(dashboard.DataTransformerConfig{Id: "organize", Options: map[string]any{
			"indexByName": map[string]int{"day": 0},
		}}).
		ColorScheme(dashboard.NewFieldColorBuilder().Mode(dashboard.FieldColorModeIdContinuousGrYlRd)).
		CellOptions(common.TableCellOptions{TableColoredBackgroundCellOptions: common.NewTableColoredBackgroundCellOptions()}).
		WithTarget(infinity("/api/weekdayhours", "table", columns...))

	return []cog.Builder[dashboard.Panel]{
		heat,
		tile("Gas meter", "The gas meter's lifetime reading, to check against the meter itself.", unitM3,
			promInstant(`max(homewizard_gas_m3_total)`, "reading")),
		tile("Power failures", "Lifetime counts from the meter. Each new failure is also marked on the time graphs.", "none",
			promInstant(`max(homewizard_any_power_fail_count)`, "any"),
			promInstant(`max(homewizard_long_power_fail_count)`, "long")),
		graph("Voltage", "Voltage per phase at the meter.", unitVolt, 12).
			Datasource(promDS()).
			TimeFrom("7d").
			WithTarget(prom(`homewizard_voltage_volts`, "{{phase}}")),
		graph("Sags and swells", "Grid events per phase per day, from the meter's counters.", "none", 12).
			Datasource(promDS()).
			TimeFrom("30d").
			WithTarget(prom(`increase(homewizard_voltage_sags_total[1d])`, "sag {{phase}}").RefId("A")).
			WithTarget(prom(`increase(homewizard_voltage_swells_total[1d])`, "swell {{phase}}").RefId("B")),
	}
}

// buildLeiden assembles the Leiden home dashboard. Build() validates it, so a
// malformed panel fails the generating derivation.
//
//nolint:staticcheck // v1 model required for portable file-based provisioning
func buildLeiden() (dashboard.Dashboard, error) {
	b := dashboard.NewDashboardBuilder("Leiden").
		Uid("leiden-energy").
		Description("What energy costs this home and why: NextEnergy's daily figures, day-ahead prices, the P1 meter and the plugs. Generated from pkgs/dashboards.").
		Tags([]string{"energy", "leiden", "nix", "generated"}).
		Refresh("1m").
		// A browser timezone would send offset 0 for absolute ranges and shift
		// every day bar; bills are in this zone.
		Timezone("Europe/Amsterdam").
		Time("now-1d/d", "now+1d/d").
		WithVariable(dashboard.NewDatasourceVariableBuilder(promVar).Label("Prometheus").Type("prometheus")).
		WithVariable(dashboard.NewDatasourceVariableBuilder(infinityVar).Label("energyd").Type("yesoreyeram-infinity-datasource").Regex("/^energyd$/")).
		Annotation(dashboard.NewAnnotationQueryBuilder().
			Name("Power failures").
			Datasource(promDS()).
			Enable(true).
			IconColor("red").
			Expr(`changes(homewizard_any_power_fail_count[5m]) > 0`).
			TitleFormat("Power failure"))

	rows := []struct {
		title     string
		collapsed bool
		panels    []cog.Builder[dashboard.Panel]
	}{
		{"Answers", false, answersPanels()},
		{"Today and tomorrow", false, todayPanels()},
		{"This month", false, monthPanels()},
		{"Gas and heating", false, gasPanels()},
		{"Contract years", false, yearPanels()},
		{"Detail", true, detailPanels()},
	}

	for _, r := range rows {
		row := dashboard.NewRowBuilder(r.title)

		if r.collapsed {
			row = row.Collapsed(true)
			for _, p := range r.panels {
				row = row.WithPanel(p)
			}

			b = b.WithRow(row)

			continue
		}

		b = b.WithRow(row)
		for _, p := range r.panels {
			b = b.WithPanel(p)
		}
	}

	return b.Build()
}
