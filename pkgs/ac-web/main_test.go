package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

// validateBranch is the exec trust boundary; empty is allowed (main repo),
// everything shady is rejected.
func TestValidateBranch(t *testing.T) {
	ok := []string{"", "foo", "kradalby/3049", "feature/bar-baz", "v1.2.3"}
	bad := []string{"-rf", "../etc", "a b", "foo;bar", "a..b", "foo$(x)", "back`tick`"}
	for _, s := range ok {
		if err := validateBranch(s); err != nil {
			t.Errorf("validateBranch(%q) = %v, want nil", s, err)
		}
	}
	for _, s := range bad {
		if err := validateBranch(s); err == nil {
			t.Errorf("validateBranch(%q) = nil, want error", s)
		}
	}
}

func TestValidateRepo(t *testing.T) {
	dir := t.TempDir()
	if err := os.MkdirAll(filepath.Join(dir, "good", ".git"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(dir, "notrepo"), 0o755); err != nil {
		t.Fatal(err)
	}
	gitRoot = dir

	if err := validateRepo("good"); err != nil {
		t.Errorf("validateRepo(good) = %v, want nil", err)
	}
	for _, s := range []string{"", "notrepo", "missing", "../good", "a/b", "a..b"} {
		if err := validateRepo(s); err == nil {
			t.Errorf("validateRepo(%q) = nil, want error", s)
		}
	}
}

func TestServerRe(t *testing.T) {
	for _, s := range []string{"ac-dotfiles", "ac-headscale-kradalby-3049"} {
		if !serverRe.MatchString(s) {
			t.Errorf("serverRe rejected valid %q", s)
		}
	}
	for _, s := range []string{"", "dotfiles", "ac-;rm", "ac- x", "../x"} {
		if serverRe.MatchString(s) {
			t.Errorf("serverRe accepted invalid %q", s)
		}
	}
}

func TestAgo(t *testing.T) {
	now := time.Now()
	cases := []struct {
		in   time.Time
		want string
	}{
		{time.Time{}, ""},
		{now.Add(-30 * time.Second), "just now"},
		{now.Add(-3 * time.Hour), "3h"},
		{now.Add(-2 * 24 * time.Hour), "2d"},
	}
	for _, c := range cases {
		if got := ago(c.in); got != c.want {
			t.Errorf("ago(%v) = %q, want %q", c.in, got, c.want)
		}
	}
}
