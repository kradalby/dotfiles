package main

import (
	"bufio"
	"context"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"
)

func main() {
	var (
		queueDir = flag.String("queue-dir", "/var/lib/nix-push", "directory for queue files")
		target   = flag.String("target", "", "nix store URL (e.g. ssh-ng://root@10.65.0.29)")
		sshKey   = flag.String("ssh-key", "", "path to SSH private key")
		interval = flag.Duration("interval", 30*time.Second, "poll interval")
	)
	flag.Parse()

	if *target == "" {
		slog.Error("--target is required")
		os.Exit(1)
	}

	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
	defer cancel()

	slog.Info("nix-push starting",
		"queue-dir", *queueDir,
		"target", *target,
		"interval", *interval,
	)

	ticker := time.NewTicker(*interval)
	defer ticker.Stop()

	// Run once immediately, then on ticker.
	for {
		if err := processQueue(ctx, *queueDir, *target, *sshKey); err != nil {
			slog.Error("processing queue", "err", err)
		}

		select {
		case <-ctx.Done():
			slog.Info("shutting down")
			return
		case <-ticker.C:
		}
	}
}

func processQueue(ctx context.Context, queueDir, target, sshKey string) error {
	queueFile := filepath.Join(queueDir, "queue")
	processingFile := filepath.Join(queueDir, "processing")
	lockFile := filepath.Join(queueDir, "lock")

	// Acquire file lock.
	lock, err := os.OpenFile(lockFile, os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return fmt.Errorf("opening lock file: %w", err)
	}
	defer lock.Close()

	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX); err != nil {
		return fmt.Errorf("acquiring lock: %w", err)
	}
	defer syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)

	// Check if queue file exists and has content.
	info, err := os.Stat(queueFile)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("stat queue: %w", err)
	}
	if info.Size() == 0 {
		return nil
	}

	// Atomically move queue -> processing.
	if err := os.Rename(queueFile, processingFile); err != nil {
		return fmt.Errorf("rename queue to processing: %w", err)
	}

	// Release lock so the post-build-hook can write new paths.
	syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)

	// Read and deduplicate paths.
	paths, err := readPaths(processingFile)
	if err != nil {
		return fmt.Errorf("reading paths: %w", err)
	}

	if len(paths) == 0 {
		os.Remove(processingFile)
		return nil
	}

	slog.Info("pushing store paths", "count", len(paths))

	// Push paths via nix copy.
	if err := nixCopy(ctx, target, sshKey, paths); err != nil {
		slog.Error("nix copy failed, requeueing paths", "err", err)

		// Requeue: acquire lock, prepend failed paths to queue.
		if lockErr := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX); lockErr != nil {
			return fmt.Errorf("reacquiring lock for requeue: %w", lockErr)
		}

		if requeueErr := requeuePaths(queueFile, processingFile, paths); requeueErr != nil {
			return fmt.Errorf("requeueing paths: %w", requeueErr)
		}

		return fmt.Errorf("nix copy: %w", err)
	}

	os.Remove(processingFile)
	slog.Info("push complete", "count", len(paths))
	return nil
}

func readPaths(filename string) ([]string, error) {
	f, err := os.Open(filename)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	seen := make(map[string]struct{})
	var paths []string

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		// Each line may have multiple space-separated paths (from $OUT_PATHS).
		for _, p := range strings.Fields(line) {
			if _, ok := seen[p]; !ok {
				seen[p] = struct{}{}
				paths = append(paths, p)
			}
		}
	}
	return paths, scanner.Err()
}

func nixCopy(ctx context.Context, target, sshKey string, paths []string) error {
	args := []string{"copy", "--to", target}
	args = append(args, paths...)

	cmd := exec.CommandContext(ctx, "nix", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if sshKey != "" {
		cmd.Env = append(os.Environ(),
			fmt.Sprintf("NIX_SSHOPTS=-i %s -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10", sshKey),
		)
	}

	return cmd.Run()
}

func requeuePaths(queueFile, processingFile string, failedPaths []string) error {
	// Read any new paths that accumulated in the queue.
	var existing []byte
	if data, err := os.ReadFile(queueFile); err == nil {
		existing = data
	}

	// Write failed paths + any new paths.
	f, err := os.Create(queueFile)
	if err != nil {
		return err
	}
	defer f.Close()

	for _, p := range failedPaths {
		fmt.Fprintln(f, p)
	}
	if len(existing) > 0 {
		f.Write(existing)
	}

	os.Remove(processingFile)
	return nil
}
