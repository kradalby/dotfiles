// rustic-wrapper is a compiled Mach-O entry point for the
// RusticBackup.app FDA wrapper on macOS.
//
// macOS TCC (Transparency, Consent, and Control) determines Full Disk
// Access by checking the "responsible process" — the binary that
// launchd directly spawns. If that binary is a script (#!/bin/bash),
// TCC resolves to /bin/bash as the process image, and the .app's FDA
// grant is never checked. A compiled binary avoids this: TCC sees the
// Mach-O inside the .app bundle and checks the bundle's FDA grant.
// Child processes (bash, rustic, rclone) inherit the grant through
// the TCC attribution chain.
//
// Usage: rustic-wrapper <script> <lockfile>
//
//	script:   path to the bash backup script to execute
//	lockfile: path to the flock lockfile for preventing concurrent runs
package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"syscall"
	"time"

	"github.com/cenkalti/backoff/v5"
)

// storeWait bounds the /nix/store poll: it sits BEFORE the flock, so an
// unbounded wait would let launchd stack a new hung instance per fire interval.
// Ten minutes covers any sane post-login mount delay; past that, exit non-zero
// and let the next launchd fire retry.
const storeWait = 10 * time.Minute

func main() {
	slog.Info("starting", "pid", os.Getpid(), "args", os.Args)

	if len(os.Args) != 3 {
		fmt.Fprintf(os.Stderr, "usage: %s <script> <lockfile>\n", os.Args[0])
		os.Exit(1)
	}

	script := os.Args[1]
	lockfile := os.Args[2]

	slog.Info("configured", "script", script, "lockfile", lockfile)

	// Wait for the Nix store firmlink to appear. On early boot after
	// login, the synthetic firmlink /nix/store may not be mounted yet.
	slog.Info("waiting for /nix/store")
	if err := waitForPath("/nix/store", storeWait); err != nil {
		slog.Error("/nix/store never appeared, giving up so launchd can retry", "waited", storeWait, "err", err)
		os.Exit(1)
	}
	slog.Info("/nix/store available")

	// Acquire an exclusive, non-blocking lock. If another instance is
	// already running (e.g. a slow backup that spans two schedule
	// intervals), exit cleanly rather than stacking up.
	fd, err := syscall.Open(lockfile, syscall.O_CREAT|syscall.O_RDWR, 0o644)
	if err != nil {
		slog.Error("open lockfile", "path", lockfile, "err", err)
		os.Exit(1)
	}
	defer syscall.Close(fd)

	if err := syscall.Flock(fd, syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		slog.Info("lock held, another backup is running, skipping")
		os.Exit(0)
	}
	defer syscall.Flock(fd, syscall.LOCK_UN)

	slog.Info("lock acquired, executing", "cmd", "/bin/bash "+script)

	// Run the backup script as a child process. The compiled wrapper
	// stays alive as the parent so macOS TCC attributes file access
	// to the .app bundle (this binary) rather than to /bin/bash.
	cmd := exec.Command("/bin/bash", script)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			slog.Error("script exited with error", "code", exitErr.ExitCode())
			os.Exit(exitErr.ExitCode())
		}
		slog.Error("exec", "err", err)
		os.Exit(1)
	}

	slog.Info("script exited successfully")
}

// waitForPath polls until path exists, checking every 500ms, giving up after
// maxWait.
func waitForPath(path string, maxWait time.Duration) error {
	_, err := backoff.Retry(context.Background(), func() (struct{}, error) {
		_, err := os.Stat(path)
		return struct{}{}, err
	},
		backoff.WithBackOff(backoff.NewConstantBackOff(500*time.Millisecond)),
		backoff.WithMaxElapsedTime(maxWait))
	return err
}
