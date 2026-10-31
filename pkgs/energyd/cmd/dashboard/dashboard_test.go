package main

import (
	"encoding/json"
	"os"
	"regexp"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func model(t *testing.T) map[string]any {
	t.Helper()

	d, err := buildDashboard()
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

	for _, path := range []string{"../../ledger/ledger.go", "../../api/api.go"} {
		src, err := os.ReadFile(path)
		require.NoError(t, err)
		fields.Write(src)
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
	src, err := os.ReadFile("../energyd/metrics.go")
	require.NoError(t, err)

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
