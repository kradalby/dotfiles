package main

import (
	"encoding/json"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"testing"

	"github.com/kradalby/dotfiles/pkgs/overlays/rnb/builders"
	"github.com/stretchr/testify/require"
)

func TestRunCommand(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, listener.Close()) })
	registry := filepath.Join(t.TempDir(), "builders.json")
	data, err := json.Marshal(builders.Registry{{Name: "local", Host: "local", HostName: listener.Addr().String(), Systems: []string{"x86_64-linux"}}})
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(registry, data, 0o600))

	for _, selector := range []string{"--auto", "local"} {
		t.Run(selector, func(t *testing.T) {
			cmd := exec.Command(os.Args[0], "-test.run=^TestRunCommandHelper$", "--", "--config", registry, selector, "--", os.Args[0], "-test.run=^TestSelectedCommandHelper$", "--", "--literal-command-flag")
			cmd.Env = append(os.Environ(), "TEST_RNB_HELPER=1", "NIX_CONFIG=")
			out, err := cmd.CombinedOutput()
			require.NoError(t, err, "%s", out)
			require.Contains(t, string(out), "selected command ran")
		})
	}
}

func TestRunCommandHelper(t *testing.T) {
	if os.Getenv("TEST_RNB_HELPER") != "1" {
		return
	}
	separator := slices.Index(os.Args, "--")
	require.Positive(t, separator)
	require.NoError(t, run(os.Args[separator+1:]))
	t.Fatal("run returned instead of replacing the process")
}

func TestSelectedCommandHelper(t *testing.T) {
	if os.Getenv("TEST_RNB_HELPER") != "1" {
		return
	}
	require.Contains(t, os.Getenv("NIX_CONFIG"), "builders = ssh-ng://127.0.0.1:")
	require.Contains(t, os.Getenv("NIX_CONFIG"), "max-jobs = 0")
	require.Equal(t, "--literal-command-flag", os.Args[len(os.Args)-1])
	_, err := os.Stdout.WriteString("selected command ran\n")
	require.NoError(t, err)
}
