package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

// validateBranch is the exec trust boundary; empty is allowed (main repo),
// everything shady is rejected.
func TestValidateBranch(t *testing.T) {
	ok := []string{"", "foo", "kradalby/3049", "feature/bar-baz", "v1.2.3"}
	bad := []string{"-rf", "../etc", "a b", "foo;bar", "a..b", "foo$(x)", "back`tick`"}
	for _, s := range ok {
		require.NoError(t, validateBranch(s), "validateBranch(%q)", s)
	}
	for _, s := range bad {
		require.Error(t, validateBranch(s), "validateBranch(%q)", s)
	}
}

func TestValidateRepo(t *testing.T) {
	dir := t.TempDir()
	require.NoError(t, os.MkdirAll(filepath.Join(dir, "good", ".git"), 0o755))
	require.NoError(t, os.MkdirAll(filepath.Join(dir, "notrepo"), 0o755))
	orig := gitRoot
	t.Cleanup(func() { gitRoot = orig })
	gitRoot = dir

	require.NoError(t, validateRepo("good"))
	for _, s := range []string{"", "notrepo", "missing", "../good", "a/b", "a..b"} {
		require.Error(t, validateRepo(s), "validateRepo(%q)", s)
	}
}

func TestServerRe(t *testing.T) {
	// Opaque herdr workspace handles: any bare token (letters, digits, . _ -).
	for _, s := range []string{"ac-dotfiles", "dotfiles", "ws_1", "01H9-abc.def"} {
		require.True(t, serverRe.MatchString(s), "serverRe rejected valid %q", s)
	}
	for _, s := range []string{"", "a/b", "x;rm", "a b", "../x"} {
		require.False(t, serverRe.MatchString(s), "serverRe accepted invalid %q", s)
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
		{now.Add(-5 * time.Minute), "5m"},
		{now.Add(-3 * time.Hour), "3h"},
		{now.Add(-2 * 24 * time.Hour), "2d"},
	}
	for _, c := range cases {
		require.Equal(t, c.want, ago(c.in), "ago(%v)", c.in)
	}
}

// parseWorktrees is the most intricate parsing in the package and feeds the
// delete identity (Rel) that handleRmWorktree passes to `git worktree remove`.
func TestParseWorktrees(t *testing.T) {
	prefix := "/home/k/worktrees/headscale/"
	out := []byte(`worktree /home/k/git/headscale
HEAD aaa
branch refs/heads/main

worktree /home/k/worktrees/headscale/kradalby/3049
HEAD bbb
branch refs/heads/kradalby/3049

worktree /home/k/worktrees/headscale/renamed-dir
HEAD ccc
branch refs/heads/actual-branch

worktree /home/k/worktrees/headscale/detached
HEAD ddd
detached

worktree /home/k/worktrees/headscale2/other
HEAD eee
branch refs/heads/sibling
`)
	got := parseWorktrees(out, prefix)
	want := []worktree{
		{Branch: "kradalby/3049", Rel: "kradalby/3049", path: "/home/k/worktrees/headscale/kradalby/3049"},
		{Branch: "actual-branch", Rel: "renamed-dir", path: "/home/k/worktrees/headscale/renamed-dir"},
		{Branch: "detached", Rel: "detached", path: "/home/k/worktrees/headscale/detached"},
	}
	require.Equal(t, want, got)
}

// parseSessions decodes the ac↔ac-web porcelain contract; a drift here silently
// empties the UI, so pin the shape (incl. the optional 6th workdir field).
func TestParseSessions(t *testing.T) {
	out := []byte("ac-dotfiles\tdotfiles\t\tclaude\t1\t/home/k/git/dotfiles\n" +
		"ac-hs-x\theadscale\tx\topencode\t0\t/home/k/worktrees/headscale/x\n" +
		"ac-old\tolddotfiles\tb\tclaude\t0\n" + // 5-field (no workdir): still valid
		"garbage\n" + // too few fields: skipped
		"\n") // blank: skipped
	got := parseSessions(out)
	want := []session{
		{Server: "ac-dotfiles", Repo: "dotfiles", Branch: "", Agent: "claude", Attached: true, Workdir: "/home/k/git/dotfiles"},
		{Server: "ac-hs-x", Repo: "headscale", Branch: "x", Agent: "opencode", Attached: false, Workdir: "/home/k/worktrees/headscale/x"},
		{Server: "ac-old", Repo: "olddotfiles", Branch: "b", Agent: "claude", Attached: false, Workdir: ""},
	}
	require.Equal(t, want, got)
}

// TestRoutes pins the security-relevant wiring: mutating endpoints reject GET
// (so a forged img/link can't fire them) and reject invalid input before any
// command runs (fail() returns before exec, so this never shells out).
func TestRoutes(t *testing.T) {
	orig := gitRoot
	t.Cleanup(func() { gitRoot = orig })
	gitRoot = t.TempDir() // so validateRepo("") fails on shape, never touching a real repo

	h := routes()
	cases := []struct {
		method, path string
		form         string
		want         int
	}{
		{"GET", "/spawn", "", http.StatusMethodNotAllowed},
		{"GET", "/kill", "", http.StatusMethodNotAllowed},
		{"GET", "/rmworktree", "", http.StatusMethodNotAllowed},
		{"POST", "/spawn", "repo=", http.StatusBadRequest},
		{"POST", "/kill", "server=a/b", http.StatusBadRequest},
		{"POST", "/rmworktree", "repo=&path=", http.StatusBadRequest},
	}
	for _, c := range cases {
		req := httptest.NewRequest(c.method, c.path, strings.NewReader(c.form))
		req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, req)
		require.Equal(t, c.want, rec.Code, "%s %s (%q)", c.method, c.path, c.form)
	}
}
