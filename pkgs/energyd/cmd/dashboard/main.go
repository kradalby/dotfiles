// Command dashboard prints the Leiden Grafana dashboard as JSON. It is a
// build-time generator: a Nix derivation captures stdout for file provisioning,
// and Build() validates the model, so a broken panel fails that derivation.
package main

import (
	"encoding/json"
	"fmt"
	"os"
)

func main() {
	d, err := buildDashboard()
	if err != nil {
		fmt.Fprintln(os.Stderr, "dashboard:", err)
		os.Exit(1)
	}

	out, err := json.MarshalIndent(d, "", "  ")
	if err != nil {
		fmt.Fprintln(os.Stderr, "dashboard:", err)
		os.Exit(1)
	}

	fmt.Println(string(out))
}
