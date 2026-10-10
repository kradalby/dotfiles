#!/usr/bin/env bash
set -euo pipefail

script=${1:-$(dirname "$0")/nix-dev-env.sh}
script=$(realpath "$script")
direnv_bin=$(command -v direnv)
root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
mkdir -p "$root/bin" "$root/direnv/src" "$root/flake/src" "$root/plain" "$root/direnv/src/nested" \
  "$root/allowed parent/child/src"
touch "$root/direnv/.envrc" "$root/flake/flake.nix" "$root/direnv/src/nested/.envrc"
touch "$root/allowed parent/child/flake.nix"
printf '%s\n' 'export REVIEW_PARENT_ENV=allowed-parent' >"$root/allowed parent/.envrc"

cat >"$root/bin/direnv" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$PWD" >>"$TEST_CALLS/direnv.calls"
printf "export REVIEW_ENV=%q\n" "$PWD"
MOCK
cat >"$root/bin/nix" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$PWD" >>"$TEST_CALLS/nix.calls"
printf '%s\n' '{"variables":{"PATH":{"value":"/review/dev/bin"}}}'
MOCK
sed -i "1c#!$BASH" "$root/bin/direnv" "$root/bin/nix"
chmod +x "$root/bin/direnv" "$root/bin/nix"
export PATH="$root/bin:$PATH" TEST_CALLS="$root"
export CLAUDE_ENV_FILE="$root/env" XDG_CACHE_HOME="$root/cache"
export HOME="$root/home" XDG_CONFIG_HOME="$root/config" XDG_DATA_HOME="$root/data"
unset DIRENV_DIR DIRENV_FILE DIRENV_DIFF DIRENV_WATCHES DIRENV_CONFIG

run_hook() {
  jq -nc --arg cwd "$1" '{new_cwd:$cwd}' | bash "$script"
}

"$direnv_bin" allow "$root/allowed parent"
PATH="$(dirname "$direnv_bin"):$PATH" run_hook "$root/allowed parent/child/src"
[[ $(bash -c 'source "$1"; printf "%s" "${REVIEW_PARENT_ENV:-}"' test "$CLAUDE_ENV_FILE.snapshot") == allowed-parent ]]
[[ ! -f "$root/nix.calls" ]]
echo 'ok   allowed ancestor .envrc takes precedence over a child flake'

run_hook "$root/direnv"
run_hook "$root/direnv/src"
grep -qF "export REVIEW_ENV=$root/direnv/src" "$CLAUDE_ENV_FILE.snapshot"
[[ $(tail -1 "$root/direnv.calls") == "$root/direnv/src" ]]
run_hook "$root/direnv/src/nested"
grep -qF "export REVIEW_ENV=$root/direnv/src/nested" "$CLAUDE_ENV_FILE.snapshot"
echo 'ok   ancestor and nested direnv environments retain the reported cwd'

run_hook "$root/flake/src"
grep -qF '/review/dev/bin' "$CLAUDE_ENV_FILE.snapshot"
[[ $(cat "$root/nix.calls") == "$root/flake" ]]
run_hook "$root/flake"
[[ $(wc -l <"$root/nix.calls") == 1 ]]
echo 'ok   subdirectories use and cache the parent flake'

run_hook "$root/plain"
[[ $(cat "$CLAUDE_ENV_FILE.snapshot") == true && $(wc -l <"$CLAUDE_ENV_FILE") == 1 ]]
echo 'ok   leaving a project clears its snapshot without duplicate source lines'
