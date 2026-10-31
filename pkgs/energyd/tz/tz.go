// Package tz holds the one timezone every period boundary in energyd uses.
package tz

import (
	"time"
	_ "time/tzdata" // the hardened unit must not depend on host zoneinfo
)

// Amsterdam is the zone NextEnergy bills and reports in, whatever the host runs.
var Amsterdam = mustLoad("Europe/Amsterdam")

func mustLoad(name string) *time.Location {
	loc, err := time.LoadLocation(name)
	if err != nil {
		panic(err)
	}

	return loc
}

// Day returns local midnight of the local day containing t.
func Day(t time.Time) time.Time {
	y, m, d := t.In(Amsterdam).Date()

	return time.Date(y, m, d, 0, 0, 0, 0, Amsterdam)
}

// DateString formats t's local day as YYYY-MM-DD.
func DateString(t time.Time) string { return t.In(Amsterdam).Format(time.DateOnly) }

// ParseDate reads a YYYY-MM-DD local day.
func ParseDate(s string) (time.Time, error) {
	return time.ParseInLocation(time.DateOnly, s, Amsterdam)
}
