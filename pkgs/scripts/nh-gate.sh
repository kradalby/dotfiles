#!/usr/bin/env bash
# colmena-gate — the check that runs before colmena's mutating subcommands.
# Wrapped onto colmena in the devShell, so `colmena apply` cannot be reached
# without it. Receives colmena's own argv; exit 0 lets the run proceed.

set -euo pipefail

# Match the subcommand anywhere in argv rather than "the first non-flag":
# global options take values (`colmena -f ./flake.nix apply`), so positional
# scanning would read the value as the subcommand. An unrelated argument that
# happens to equal a subcommand name gates a run that did not need it — this
# errs closed, which is the right direction for a gate.
sub=""
for arg in "$@"; do
  case "$arg" in
    apply | apply-local | upload-keys)
      sub="$arg"
      break
      ;;
  esac
done

# build, eval, repl, exec, nix-info and --help are never gated: build is how
# you preview a dirty tree, and exec is how you verify a host afterwards.
[[ -n "$sub" ]] || exit 0

if git-ready; then
  exit 0
fi

# Break-glass. A human at a terminal can override mid-incident; an agent
# cannot, because its shell has no TTY. Deliberately not an environment
# variable — one an agent can set is not a gate.
if [[ -t 0 && -t 1 ]]; then
  read -r -p "colmena $sub anyway? type 'yes' to override: " answer
  if [[ "$answer" == "yes" ]]; then
    exit 0
  fi
fi

echo "colmena $sub refused: the repo is not in a deployable state." >&2
exit 1
