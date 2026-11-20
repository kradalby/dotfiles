#!/usr/bin/env bash
# nh-gate — the check that runs before nh's activating subcommands. It is the
# nh in the devShell, so `nh os switch` cannot be reached without it. $NH is
# the real nh, prepended by nh-gate.nix.

set -euo pipefail
NH="${NH:?set by nh-gate.nix}"

# `nh os switch` resolves sudo from PATH, and the sudo in
# `environment.systemPackages` is a plain store binary — only the /run/wrappers
# copy carries the setuid bit. A devShell that lands sw/bin first makes
# activation die on "must be owned by uid 0"; pin the wrappers dir first.
export PATH="/run/wrappers/bin:$PATH"

# shortcut: nh 4.5.0 passes `systemd-run --output=cat`, which systemd < 261
# (NixOS 26.05) rejects, so every activation fails (nh#874). Drop once nh ships
# the version-detecting fallback.
export NH_NO_SYSTEMD_RUN="${NH_NO_SYSTEMD_RUN:-1}"

# Find the `<os|darwin|home> <verb>` pair and whether a target host is set.
# Scanning stops at `--`: everything after it belongs to nix.
verb=-1
gated=0
remote=0
args=("$@")
for i in "${!args[@]}"; do
  case "${args[$i]}" in
    --) break ;;
    --target-host | --target-host=*) remote=1 ;;
    os | darwin | home)
      case "${args[$((i + 1))]:-}" in
        switch | boot | test) verb=$((i + 1)) gated=1 ;;
        dry-activate) verb=$((i + 1)) ;;
      esac
      ;;
  esac
done

# Without this nh copies the whole closure from here; with it the target pulls
# what it can from its own substituters (tsnixcache, cachix) first.
if ((verb >= 0 && remote)); then
  set -- "${args[@]:0:verb+1}" --use-substitutes "${args[@]:verb+1}"
fi

# build, dry-activate, search, clean and --help are never gated: build is how
# you preview a dirty tree.
if ((!gated)) || git-ready; then
  exec "$NH" "$@"
fi

# Break-glass. A human at a terminal can override mid-incident; an agent
# cannot, because its shell has no TTY. Deliberately not an environment
# variable — one an agent can set is not a gate.
if [[ -t 0 && -t 1 ]]; then
  read -r -p "nh ${args[verb - 1]} ${args[verb]} anyway? type 'yes' to override: " answer
  if [[ "$answer" == "yes" ]]; then
    exec "$NH" "$@"
  fi
fi

echo "nh ${args[verb - 1]} ${args[verb]} refused: the repo is not in a deployable state." >&2
exit 1
