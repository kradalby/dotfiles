// Command dashboards writes the Grafana dashboards that belong to this fleet
// rather than to one service, because they chart several services side by side.
// It is a build-time generator: a Nix derivation runs it for file provisioning, and
// Build() validates each model, so a broken panel fails that derivation.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"

	"github.com/grafana/grafana-foundation-sdk/go/dashboard"
)

//nolint:staticcheck // v1 model required for portable file-based provisioning
var builders = map[string]func() (dashboard.Dashboard, error){
	"leiden": buildLeiden,
}

func main() {
	out := flag.String("out", ".", "directory to write <name>.json into")
	flag.Parse()

	if err := run(*out); err != nil {
		fmt.Fprintln(os.Stderr, "dashboards:", err)
		os.Exit(1)
	}
}

func run(dir string) error {
	for name, build := range builders {
		d, err := build()
		if err != nil {
			return fmt.Errorf("build %s: %w", name, err)
		}

		raw, err := json.MarshalIndent(d, "", "  ")
		if err != nil {
			return fmt.Errorf("marshal %s: %w", name, err)
		}

		if err := os.WriteFile(filepath.Join(dir, name+".json"), append(raw, '\n'), 0o600); err != nil {
			return fmt.Errorf("write %s: %w", name, err)
		}
	}

	return nil
}
