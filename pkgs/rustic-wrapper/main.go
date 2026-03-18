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
	"fmt"
	"os"
	"os/exec"
	"syscall"
	"time"
)

func main() {
	fmt.Fprintf(os.Stderr, "rustic-wrapper: starting (pid=%d, args=%v)\n", os.Getpid(), os.Args)

	if len(os.Args) != 3 {
		fmt.Fprintf(os.Stderr, "usage: %s <script> <lockfile>\n", os.Args[0])
		os.Exit(1)
	}

	script := os.Args[1]
	lockfile := os.Args[2]

	fmt.Fprintf(os.Stderr, "rustic-wrapper: script=%s lockfile=%s\n", script, lockfile)

	// Wait for the Nix store firmlink to appear. On early boot after
	// login, the synthetic firmlink /nix/store may not be mounted yet.
	fmt.Fprintf(os.Stderr, "rustic-wrapper: waiting for /nix/store...\n")
	waitForPath("/nix/store")
	fmt.Fprintf(os.Stderr, "rustic-wrapper: /nix/store available\n")

	// Acquire an exclusive, non-blocking lock. If another instance is
	// already running (e.g. a slow backup that spans two schedule
	// intervals), exit cleanly rather than stacking up.
	fd, err := syscall.Open(lockfile, syscall.O_CREAT|syscall.O_RDWR, 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "rustic-wrapper: open lockfile: %v\n", err)
		os.Exit(1)
	}
	defer syscall.Close(fd)

	if err := syscall.Flock(fd, syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		fmt.Fprintf(os.Stderr, "rustic-wrapper: lock held, another backup is running, skipping\n")
		os.Exit(0)
	}
	defer syscall.Flock(fd, syscall.LOCK_UN)

	fmt.Fprintf(os.Stderr, "rustic-wrapper: lock acquired, executing: /bin/bash %s\n", script)

	// Run the backup script as a child process. The compiled wrapper
	// stays alive as the parent so macOS TCC attributes file access
	// to the .app bundle (this binary) rather than to /bin/bash.
	cmd := exec.Command("/bin/bash", script)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			fmt.Fprintf(os.Stderr, "rustic-wrapper: script exited with code %d\n", exitErr.ExitCode())
			os.Exit(exitErr.ExitCode())
		}
		fmt.Fprintf(os.Stderr, "rustic-wrapper: exec: %v\n", err)
		os.Exit(1)
	}

	fmt.Fprintf(os.Stderr, "rustic-wrapper: script exited successfully\n")
}

// waitForPath polls until path exists, checking every 500ms.
func waitForPath(path string) {
	for {
		if _, err := os.Stat(path); err == nil {
			return
		}
		time.Sleep(500 * time.Millisecond)
	}
}
