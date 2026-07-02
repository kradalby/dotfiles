// Package builders maps short builder names to nix remote-builder specs and
// assembles the NIX_CONFIG that offloads builds to them.
package builders

import (
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"time"
)

// Builder is one remote builder endpoint. JSON tags match the shape
// builtins.toJSON emits from common/rnb-builders.nix.
type Builder struct {
	Name              string   `json:"name"`
	Host              string   `json:"host"` // groups endpoints of one machine for --auto
	HostName          string   `json:"hostName"`
	Systems           []string `json:"systems"`
	SSHUser           string   `json:"sshUser"`
	SSHKey            string   `json:"sshKey"`
	MaxJobs           int      `json:"maxJobs"`
	SpeedFactor       int      `json:"speedFactor"`
	SupportedFeatures []string `json:"supportedFeatures"`
	MandatoryFeatures []string `json:"mandatoryFeatures"`
	PublicHostKey     string   `json:"publicHostKey"`
	HasRosetta        bool     `json:"hasRosetta"`
}

// dash is the machines-file sentinel for an unset field.
const dash = "-"

func strOrDash(v string) string {
	if v == "" {
		return dash
	}
	return v
}

func joinOrDash(xs []string) string {
	if len(xs) == 0 {
		return dash
	}
	return strings.Join(xs, ",")
}

func numOrDash(n int) string {
	if n <= 0 {
		return dash
	}
	return strconv.Itoa(n)
}

// Spec renders the builder as one nix machines-file line, the eight
// space-separated fields nix's `builders` setting expects:
//
//	ssh-ng://user@host systems key maxjobs speed supported mandatory pubkey
func (b Builder) Spec() string {
	uri := "ssh-ng://"
	if b.SSHUser != "" {
		uri += b.SSHUser + "@"
	}
	uri += b.HostName
	return strings.Join([]string{
		uri,
		joinOrDash(b.Systems),
		strOrDash(b.SSHKey),
		numOrDash(b.MaxJobs),
		numOrDash(b.SpeedFactor),
		joinOrDash(b.SupportedFeatures),
		joinOrDash(b.MandatoryFeatures),
		strOrDash(b.PublicHostKey),
	}, " ")
}

// Registry is the set of configured builders.
type Registry []Builder

// Load reads the registry JSON from the first available of: explicit path,
// $RNB_BUILDERS, then $XDG_CONFIG_HOME/rnb/builders.json (~/.config fallback).
// It returns the path it used so callers can report it.
func Load(explicit string) (Registry, string, error) {
	path := explicit
	if path == "" {
		path = os.Getenv("RNB_BUILDERS")
	}
	if path == "" {
		path = filepath.Join(configHome(), "rnb", "builders.json")
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, path, err
	}
	var r Registry
	if err := json.Unmarshal(data, &r); err != nil {
		return nil, path, fmt.Errorf("parsing %s: %w", path, err)
	}
	return r, path, nil
}

func configHome() string {
	if x := os.Getenv("XDG_CONFIG_HOME"); x != "" {
		return x
	}
	return filepath.Join(os.Getenv("HOME"), ".config")
}

// Names returns every configured builder name, in registry order.
func (r Registry) Names() []string {
	out := make([]string, len(r))
	for i, b := range r {
		out[i] = b.Name
	}
	return out
}

// Resolve maps names to builders, erroring on the first unknown name.
func (r Registry) Resolve(names []string) ([]Builder, error) {
	out := make([]Builder, 0, len(names))
	for _, n := range names {
		i := slices.IndexFunc(r, func(b Builder) bool { return b.Name == n })
		if i < 0 {
			return nil, fmt.Errorf("unknown builder %q (configured: %s)", n, strings.Join(r.Names(), ", "))
		}
		out = append(out, r[i])
	}
	return out, nil
}

// Reachable reports whether host:22 accepts a TCP connection within a short
// timeout. It is the default probe for Select.
func Reachable(hostName string) bool {
	c, err := net.DialTimeout("tcp", net.JoinHostPort(hostName, "22"), 1500*time.Millisecond)
	if err != nil {
		return false
	}
	_ = c.Close()
	return true
}

// Select picks, per Host group, the reachable endpoint with the highest speed
// factor — preferring LAN over tailnet automatically. probe decides
// reachability (injected so tests need no sockets). Result is name-sorted.
func (r Registry) Select(probe func(string) bool) []Builder {
	best := map[string]Builder{}
	for _, b := range r {
		if !probe(b.HostName) {
			continue
		}
		if cur, ok := best[b.Host]; !ok || b.SpeedFactor > cur.SpeedFactor {
			best[b.Host] = b
		}
	}
	out := make([]Builder, 0, len(best))
	for _, b := range best {
		out = append(out, b)
	}
	slices.SortFunc(out, func(a, b Builder) int { return strings.Compare(a.Name, b.Name) })
	return out
}

// NixConfig builds the NIX_CONFIG body pointing nix at the given builders.
//
// Default (merge=false): builders are replaced and max-jobs is forced to 0, so
// every build goes remote. merge=true keeps existing builders (typically from
// `nix config show builders`, e.g. the local rosetta VM) and allows local
// building. base is the inherited $NIX_CONFIG to extend, if any.
func NixConfig(bs []Builder, merge bool, existing, base string) string {
	specs := make([]string, 0, len(bs)+1)
	if merge && existing != "" {
		specs = append(specs, existing)
	}
	for _, b := range bs {
		specs = append(specs, b.Spec())
	}

	lines := []string{"builders = " + strings.Join(specs, " ; ")}
	if !merge {
		lines = append(lines, "max-jobs = 0")
	}
	lines = append(lines, "builders-use-substitutes = true")

	body := strings.Join(lines, "\n")
	if base != "" {
		return base + "\n" + body
	}
	return body
}

// Print renders a shell statement setting NIX_CONFIG to value. fish toggles
// fish syntax (set -gx) vs POSIX (export).
func Print(value string, fish bool) string {
	if fish {
		return "set -gx NIX_CONFIG " + fishQuote(value)
	}
	return "export NIX_CONFIG=" + posixQuote(value)
}

// PrintClear renders the statement that unsets NIX_CONFIG.
func PrintClear(fish bool) string {
	if fish {
		return "set -e NIX_CONFIG"
	}
	return "unset NIX_CONFIG"
}

func fishQuote(s string) string {
	s = strings.ReplaceAll(s, `\`, `\\`)
	s = strings.ReplaceAll(s, `'`, `\'`)
	return "'" + s + "'"
}

func posixQuote(s string) string {
	return "'" + strings.ReplaceAll(s, `'`, `'\''`) + "'"
}
