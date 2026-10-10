package main

import (
	"flag"
	"io"
	"os"
	"os/exec"
	"slices"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestParseTags(t *testing.T) {
	require.Equal(t, []string{"tag:server", "tag:isolated"}, parseTags(" tag:server, tag:isolated ,"))
	require.Nil(t, parseTags(" , "), "parseTags of empties should be nil")
}

func TestKeyCapabilities(t *testing.T) {
	require.False(t, keyCapabilities(nil, false).Devices.Create.Reusable,
		"default key must be single-use (reusable=false)")
	require.True(t, keyCapabilities(nil, true).Devices.Create.Reusable,
		"-reusable must produce a reusable key")
	c := keyCapabilities([]string{"tag:server"}, false)
	require.True(t, c.Devices.Create.Preauthorized, "key must be preauthorized")
	require.Equal(t, []string{"tag:server"}, c.Devices.Create.Tags)
}

func TestPlatformTable(t *testing.T) {
	require.Len(t, order, len(platforms), "order and platforms must name the same set")
	for _, name := range order {
		p, ok := platforms[name]
		require.True(t, ok, "order names %q which is not in platforms", name)
		require.NotEmpty(t, p.tokenURL, "platform %q tokenURL", name)
		require.NotEmpty(t, p.tailnet, "platform %q tailnet", name)
		require.NotEmpty(t, p.secret, "platform %q secret", name)
		require.NotEmpty(t, p.credID, "platform %q credID", name)
		require.NotEmpty(t, p.credKey, "platform %q credKey", name)
	}
}

func TestTargetBeforeFlags(t *testing.T) {
	cmd := exec.Command(os.Args[0], "-test.run=^TestAuthkeyCommandHelper$", "--", "missing-platform", "-rotate", "-tags", "tag:test", "-expiry", "2h")
	cmd.Env = append(os.Environ(), "TEST_AUTHKEY_HELPER=1")
	out, err := cmd.CombinedOutput()
	var exitErr *exec.ExitError
	require.ErrorAs(t, err, &exitErr)
	require.Equal(t, 1, exitErr.ExitCode(), "valid syntax must reach platform validation: %s", out)
	require.Contains(t, string(out), "unknown platform")
}

func TestAuthkeyCommandHelper(t *testing.T) {
	if os.Getenv("TEST_AUTHKEY_HELPER") != "1" {
		return
	}
	separator := slices.Index(os.Args, "--")
	require.Positive(t, separator)
	os.Args = append([]string{os.Args[0]}, os.Args[separator+1:]...)
	main()
	t.Fatal("main returned instead of rejecting the unknown platform")
}

func TestParseArgs(t *testing.T) {
	for _, tt := range []struct {
		name      string
		args      []string
		wantError bool
	}{
		{"platform first", []string{"kradalby", "-rotate", "-secret", "service.age", "-expiry", "2h"}, false},
		{"flags first", []string{"-rotate", "-secret", "service.age", "-expiry", "2h", "kradalby"}, false},
		{"no platform", []string{"-rotate"}, true},
		{"multiple platforms", []string{"kradalby", "headscale", "-rotate"}, true},
		{"unknown flag", []string{"kradalby", "-unknown"}, true},
	} {
		t.Run(tt.name, func(t *testing.T) {
			fs := flag.NewFlagSet("authkey", flag.ContinueOnError)
			fs.SetOutput(io.Discard)
			rotate := fs.Bool("rotate", false, "")
			secret := fs.String("secret", "", "")
			expiry := fs.Duration("expiry", 24*time.Hour, "")
			target, err := parseArgs(fs, tt.args)
			if tt.wantError {
				require.Error(t, err)
				return
			}
			require.NoError(t, err)
			require.Equal(t, "kradalby", target)
			require.True(t, *rotate)
			require.Equal(t, "service.age", *secret)
			require.Equal(t, 2*time.Hour, *expiry)
		})
	}
}
