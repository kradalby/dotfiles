package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

// energydFile reads a source file of the service these panels chart. Nix sets
// ENERGYD_SRC, because a build sees only this package's own directory.
func energydFile(t *testing.T, path string) []byte {
	t.Helper()

	root := os.Getenv("ENERGYD_SRC")
	if root == "" {
		root = "../energyd"
	}

	src, err := os.ReadFile(filepath.Join(root, path))
	require.NoError(t, err)

	return src
}

func model(t *testing.T) map[string]any {
	t.Helper()

	d, err := buildLeiden()
	require.NoError(t, err)

	raw, err := json.Marshal(d)
	require.NoError(t, err)

	var out map[string]any
	require.NoError(t, json.Unmarshal(raw, &out))

	return out
}

// panels flattens top-level panels and those nested in collapsed rows.
func panels(t *testing.T) []map[string]any {
	t.Helper()

	var out []map[string]any

	var walk func(items []any)
	walk = func(items []any) {
		for _, item := range items {
			p := item.(map[string]any)
			if p["type"] == "row" {
				nested, _ := p["panels"].([]any)
				walk(nested)

				continue
			}

			out = append(out, p)
		}
	}

	walk(model(t)["panels"].([]any))
	require.NotEmpty(t, out)

	return out
}

func TestDashboardIdentity(t *testing.T) {
	m := model(t)
	require.Equal(t, "leiden-energy", m["uid"])
	require.Equal(t, "Leiden", m["title"])
	require.NotEmpty(t, m["description"])
	require.Equal(t, "Europe/Amsterdam", m["timezone"], "a browser timezone shifts day bars")
}

func TestEveryDataPanelHasADescription(t *testing.T) {
	for _, p := range panels(t) {
		require.NotEmpty(t, p["description"], "%v has no help text", p["title"])
	}
}

// The convention wants a legend on every panel. Stat and table builders have no
// legend option, so they are the only exceptions.
func TestPanelsThatCanCarryALegendDo(t *testing.T) {
	for _, p := range panels(t) {
		switch p["type"] {
		case "stat", "table":
			continue
		}

		options, _ := p["options"].(map[string]any)
		legend, _ := options["legend"].(map[string]any)
		require.Equal(t, true, legend["showLegend"], "%v (%v) has no legend", p["title"], p["type"])
	}
}

// Without parser backend, Infinity returns rows unparsed and the panel is empty.
func TestInfinityQueriesUseTheBackendParser(t *testing.T) {
	seen := 0

	for _, p := range panels(t) {
		targets, _ := p["targets"].([]any)
		for _, target := range targets {
			q := target.(map[string]any)
			if _, isInfinity := q["root_selector"]; !isInfinity {
				continue
			}

			seen++
			require.Equal(t, "backend", q["parser"], p["title"])
			require.True(t, strings.HasPrefix(q["url"].(string), "/api/"), p["title"])
		}
	}

	require.Positive(t, seen)
}

// A typo'd column renders as a silently empty series, so every selector must be
// a JSON field the ledger or the API really emits.
func TestInfinityColumnsExistInTheAPI(t *testing.T) {
	var fields strings.Builder

	for _, path := range []string{"ledger/ledger.go", "api/api.go"} {
		fields.Write(energydFile(t, path))
	}

	known := map[string]bool{"weekday": true}
	for _, m := range regexp.MustCompile(`json:"([a-z0-9_]+)"`).FindAllStringSubmatch(fields.String(), -1) {
		known[m[1]] = true
	}

	for hour := range 24 {
		known["h"+pad(hour)] = true
	}

	for _, p := range panels(t) {
		targets, _ := p["targets"].([]any)
		for _, target := range targets {
			columns, _ := target.(map[string]any)["columns"].([]any)
			for _, column := range columns {
				selector := column.(map[string]any)["selector"].(string)
				require.True(t, known[selector], "%v: column %q is not in the API", p["title"], selector)
			}
		}
	}
}

// Conventions demand that metric names be checked against source: a rename
// matches nothing and the panel just goes quiet.
func TestEnergydMetricsExistInTheService(t *testing.T) {
	src := energydFile(t, "cmd/energyd/metrics.go")

	raw, err := json.Marshal(model(t))
	require.NoError(t, err)

	pattern := regexp.MustCompile(`energyd_[a-z0-9_]+`)
	used := pattern.FindAllString(string(raw), -1)
	require.NotEmpty(t, used)

	for _, name := range used {
		require.Contains(t, string(src), `"`+name+`"`, "panel queries a metric the service does not expose")
	}
}

// These are why the old dashboard had empty panels. They must not come back.
func TestDeadQueriesStayGone(t *testing.T) {
	raw, err := json.Marshal(model(t))
	require.NoError(t, err)

	for _, dead := range []string{"sensor_temperature", "core.ldn.fap.no", "node_network"} {
		require.NotContains(t, string(raw), dead)
	}
}

// A plug's counter can drop by rounding at midnight. increase() reads the drop as
// a reset and adds the whole register, so plug cost must come from power.
func TestPlugCostDoesNotTrustThePlugCounter(t *testing.T) {
	raw, err := json.Marshal(model(t))
	require.NoError(t, err)

	require.NotContains(t, string(raw), "tasmota_kwh_total")
}

func TestPowerFailuresAreAnnotations(t *testing.T) {
	annotations := model(t)["annotations"].(map[string]any)["list"].([]any)
	require.Len(t, annotations, 1)
	require.Contains(t, annotations[0].(map[string]any)["expr"], "homewizard_any_power_fail_count")
}

func TestRowsCoverTheAgreedQuestions(t *testing.T) {
	var titles []string
	for _, item := range model(t)["panels"].([]any) {
		p := item.(map[string]any)
		if p["type"] == "row" {
			titles = append(titles, p["title"].(string))
		}
	}

	require.Equal(t, []string{"Answers", "Today and tomorrow", "This month", "Gas and heating", "Contract years", "Detail"}, titles)
}

// An instant query runs at the end of the panel's range. The dashboard's range
// ends tomorrow so the price curve fits, which would leave instant panels asking
// Prometheus about the future and showing no data.
func TestInstantPanelsAreAnchoredToNow(t *testing.T) {
	seen := 0

	for _, p := range panels(t) {
		targets, _ := p["targets"].([]any)
		for _, target := range targets {
			if target.(map[string]any)["instant"] != true {
				continue
			}

			seen++
			require.NotEmpty(t, p["timeFrom"], "%v uses an instant query with no time override", p["title"])
		}
	}

	require.Positive(t, seen)
}

func TestScatterPanelDeclaresItsVersion(t *testing.T) {
	found := false

	for _, p := range panels(t) {
		if p["type"] == "xychart" {
			found = true

			require.NotEmpty(t, p["pluginVersion"], "with no version Grafana migrates the matchers and the panel errors")
		}
	}

	require.True(t, found)
}

// Grafana reduces a legend over all rows returned. A panel showing 30 days that
// fetched four years would total four years under a 30-day title.
func TestHistoryPanelsOnlyFetchTheirRange(t *testing.T) {
	seen := 0

	for _, p := range panels(t) {
		targets, _ := p["targets"].([]any)
		for _, target := range targets {
			url, _ := target.(map[string]any)["url"].(string)
			if !regexp.MustCompile(`^/api/(days|months|degreedays)`).MatchString(url) {
				continue
			}

			seen++
			require.Contains(t, url, "days=", "%v fetches all history", p["title"])
		}
	}

	require.Positive(t, seen)
}

func TestEstimatesSayTheyAreEstimates(t *testing.T) {
	titles := map[string]bool{}
	for _, p := range panels(t) {
		titles[p["title"].(string)] = true
	}

	require.True(t, titles["Year-end settlement (estimate)"])
	require.True(t, titles["Today (computed)"])
}

// Computed euros on undelivered days must not be charted as NextEnergy's.
func TestComputedPanelChartsOnlyDeliveredFiguresAsNextEnergy(t *testing.T) {
	for _, p := range panels(t) {
		if p["title"] != "Computed against NextEnergy" {
			continue
		}

		raw, err := json.Marshal(p["targets"])
		require.NoError(t, err)
		require.Contains(t, string(raw), "nextenergy_eur")
		require.NotContains(t, string(raw), "total_eur")

		return
	}

	t.Fatal("panel not found")
}

// The old Leiden dashboard is what this one replaces, so everything it showed that
// still has data must stay reachable. Its Bandwidth and Temperature panels queried
// series that no longer exist, which TestDeadQueriesStayGone covers.
func TestEverythingTheOldDashboardShowedIsStillHere(t *testing.T) {
	raw, err := json.Marshal(model(t))
	require.NoError(t, err)

	for _, expr := range []string{
		"tasmota_power_watts",
		"homewizard_active_power_watts",
		"homewizard_gas_m3_total",
		"homewizard_any_power_fail_count",
		"homewizard_long_power_fail_count",
	} {
		require.Contains(t, string(raw), expr)
	}
}

// Live power was the first thing the old dashboard showed. Folding it away is not
// an improvement, whatever else is added.
func TestLivePowerAndIntraDayGasAreVisibleWithoutExpandingARow(t *testing.T) {
	visible := map[string]map[string]any{}

	for _, item := range model(t)["panels"].([]any) {
		p := item.(map[string]any)
		if p["type"] != "row" {
			visible[p["title"].(string)] = p
		}
	}

	require.Contains(t, visible, "Power")
	require.Contains(t, visible, "Hourly gas")
	require.Contains(t, visible, "Power now")

	raw, err := json.Marshal(visible["Power"]["targets"])
	require.NoError(t, err)
	require.Contains(t, string(raw), "homewizard_active_power_watts")
	require.Contains(t, string(raw), "tasmota_power_watts")

	raw, err = json.Marshal(visible["Hourly gas"]["targets"])
	require.NoError(t, err)
	require.Contains(t, string(raw), `"m3"`)
}

func TestDashboardRefreshesOftenEnoughForLivePower(t *testing.T) {
	require.Equal(t, "1m", model(t)["refresh"])
}

func TestEveryBuilderProducesADashboard(t *testing.T) {
	for name, build := range builders {
		d, err := build()
		require.NoError(t, err, name)
		require.NotEmpty(t, d.Title, name)
	}
}

func TestRunWritesEachDashboardValidJSON(t *testing.T) {
	dir := t.TempDir()
	require.NoError(t, run(dir))

	raw, err := os.ReadFile(filepath.Join(dir, "leiden.json"))
	require.NoError(t, err)

	var out map[string]any
	require.NoError(t, json.Unmarshal(raw, &out))
	require.Equal(t, "leiden-energy", out["uid"])
}

// Grafana rejects queries with the same ID as duplicates, and an empty ID counts.
// The panel then shows an error and drops a series, which no build step catches.
func TestPanelsWithSeveralQueriesGiveEachAUniqueID(t *testing.T) {
	seen := 0

	for _, p := range panels(t) {
		targets, _ := p["targets"].([]any)
		if len(targets) < 2 {
			continue
		}

		seen++
		ids := map[string]bool{}

		for _, target := range targets {
			id, _ := target.(map[string]any)["refId"].(string)
			require.NotEmpty(t, id, "%v has a query with no ID", p["title"])
			require.False(t, ids[id], "%v repeats query ID %s", p["title"], id)
			ids[id] = true
		}
	}

	require.Positive(t, seen)
}

// Titles are the only label a tile has, so a tile must be wide enough to show one.
func TestAnswerTilesAreWideEnoughForTheirTitles(t *testing.T) {
	for _, p := range panels(t) {
		if p["type"] != "stat" {
			continue
		}

		width := p["gridPos"].(map[string]any)["w"].(float64)
		require.GreaterOrEqual(t, width, 6.0, "%v", p["title"])
	}
}

// Infinity sorts table columns by name, which puts the day after hour 23, off the
// edge of the screen. A table of 25 columns also has to fit without scrolling.
func TestWeekdayTableStartsWithTheDayAndFitsOnScreen(t *testing.T) {
	for _, p := range panels(t) {
		if p["title"] != "Use above the floor by weekday and hour" {
			continue
		}

		raw, err := json.Marshal(p["transformations"])
		require.NoError(t, err)
		require.Contains(t, string(raw), `"day":0`)

		config := p["fieldConfig"].(map[string]any)["defaults"].(map[string]any)
		require.Equal(t, "none", config["unit"], "a unit on every cell does not fit 25 columns")
		require.LessOrEqual(t, config["custom"].(map[string]any)["minWidth"], 40.0)

		return
	}

	t.Fatal("panel not found")
}
