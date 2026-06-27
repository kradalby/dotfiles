// Command rnb selects nix remote builders by short name and either execs a
// command with NIX_CONFIG set (like env) or prints a shell statement to source.
package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"syscall"

	"github.com/kradalby/dotfiles/pkgs/overlays/rnb/builders"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "rnb: "+err.Error())
		os.Exit(1)
	}
}

func run(args []string) error {
	fs := flag.NewFlagSet("rnb", flag.ContinueOnError)
	var merge, auto, doPrint, posix, clear bool
	var config string
	fs.BoolVar(&merge, "m", false, "")
	fs.BoolVar(&merge, "merge", false, "add to existing builders and keep local building")
	fs.BoolVar(&auto, "auto", false, "pick reachable builders automatically (ignores names)")
	fs.BoolVar(&doPrint, "print", false, "print a shell statement to source instead of exec")
	fs.BoolVar(&posix, "posix", false, "with --print, emit POSIX export (default: fish)")
	fs.BoolVar(&clear, "clear", false, "with --print, emit the NIX_CONFIG unset statement")
	fs.StringVar(&config, "config", "", "path to builders.json (overrides $RNB_BUILDERS/XDG)")
	fs.Usage = func() { usage(fs, config) }

	if err := fs.Parse(args); err != nil {
		if err == flag.ErrHelp {
			return nil
		}
		return err
	}

	// --print --clear needs neither a registry nor a command.
	if doPrint && clear {
		fmt.Println(builders.PrintClear(!posix))
		return nil
	}

	names, command := splitArgs(fs.Args())

	reg, path, err := builders.Load(config)
	if err != nil {
		return fmt.Errorf("loading builders (%s): %w", path, err)
	}

	var selected []builders.Builder
	if auto {
		if selected = reg.Select(builders.Reachable); len(selected) == 0 {
			return fmt.Errorf("--auto: no configured builders reachable")
		}
	} else {
		if len(names) == 0 {
			fs.Usage()
			return fmt.Errorf("no builder name given")
		}
		if selected, err = reg.Resolve(names); err != nil {
			return err
		}
	}

	existing := ""
	if merge {
		existing = currentBuilders()
	}
	cfg := builders.NixConfig(selected, merge, existing, os.Getenv("NIX_CONFIG"))

	if doPrint {
		fmt.Println(builders.Print(cfg, !posix))
		return nil
	}

	if len(command) == 0 {
		return fmt.Errorf("no command: use `rnb <name>... -- <cmd>` or --print")
	}
	bin, err := exec.LookPath(command[0])
	if err != nil {
		return fmt.Errorf("%s: %w", command[0], err)
	}
	return syscall.Exec(bin, command, replaceEnv("NIX_CONFIG", cfg))
}

// splitArgs divides positional args at the first "--": builder names before,
// the command after.
func splitArgs(rest []string) (names, command []string) {
	for i, a := range rest {
		if a == "--" {
			return rest[:i], rest[i+1:]
		}
	}
	return rest, nil
}

// currentBuilders returns nix's effective `builders` setting (e.g. the local
// rosetta VM as @/etc/nix/machines), for --merge. Best effort.
func currentBuilders() string {
	out, err := exec.Command("nix", "config", "show", "builders").Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

// replaceEnv returns os.Environ() with key forced to val.
func replaceEnv(key, val string) []string {
	prefix := key + "="
	out := make([]string, 0, len(os.Environ())+1)
	for _, e := range os.Environ() {
		if !strings.HasPrefix(e, prefix) {
			out = append(out, e)
		}
	}
	return append(out, key+"="+val)
}

func usage(fs *flag.FlagSet, config string) {
	w := fs.Output()
	fmt.Fprint(w, `rnb — run a nix command against on-demand remote builders

Usage:
  rnb [flags] <name>... -- <command>...   set NIX_CONFIG and exec command
  rnb --print [flags] <name>...           print a shell statement to source
  rnb --print --clear                     print the NIX_CONFIG unset statement

Flags:
  -m, --merge   add to existing builders and keep local building
                (default: replace builders, force all builds remote / max-jobs=0)
      --auto    pick reachable builders automatically (ignores <name>...)
      --print   print a shell statement instead of exec'ing the command
      --posix   with --print, emit POSIX 'export' (default: fish 'set -gx')
      --clear   with --print, emit the NIX_CONFIG unset statement
      --config  path to builders.json (default: $RNB_BUILDERS or
                $XDG_CONFIG_HOME/rnb/builders.json)

Examples:
  rnb dev.ldn -- nix build .#foo
  rnb -m dev-ldn -- colmena apply
  rnb --auto -- darwin-rebuild switch --flake .#krair
  rnb --print dev.ldn | source           # fish: set NIX_CONFIG in this shell
  eval "$(rnb --print --posix dev.ldn)"  # bash/sh
`)
	if reg, _, err := builders.Load(config); err == nil && len(reg) > 0 {
		fmt.Fprintln(w, "\nConfigured builders: "+strings.Join(reg.Names(), ", "))
	}
}
