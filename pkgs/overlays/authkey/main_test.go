package main

import (
	"reflect"
	"testing"
)

func TestParseTags(t *testing.T) {
	got := parseTags(" tag:server, tag:isolated ,")
	want := []string{"tag:server", "tag:isolated"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("parseTags = %v, want %v", got, want)
	}
	if parseTags(" , ") != nil {
		t.Fatalf("parseTags of empties should be nil")
	}
}

func TestPlatformTable(t *testing.T) {
	if len(order) != len(platforms) {
		t.Fatalf("order has %d entries, platforms has %d", len(order), len(platforms))
	}
	for _, name := range order {
		p, ok := platforms[name]
		if !ok {
			t.Fatalf("order names %q which is not in platforms", name)
		}
		if p.tokenURL == "" || p.tailnet == "" || p.secret == "" || p.credID == "" || p.credKey == "" {
			t.Fatalf("platform %q has an empty required field: %+v", name, p)
		}
	}
}
