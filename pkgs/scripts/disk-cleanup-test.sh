#!/usr/bin/env bash
# Every tool that deletes is a mock: the run must never touch this machine.
set -euo pipefail

SCRIPT=${1:-$(dirname "$0")/disk-cleanup.sh}
ROOT=$(mktemp -d)
trap 'rm -rf -- "$ROOT"' EXIT
mkdir -p "$ROOT/bin" "$ROOT/home/.cache/go-build"
export HOME="$ROOT/home" LOG="$ROOT/calls" STATE="$ROOT"
export PATH="$ROOT/bin:$PATH"

# Each mock logs its call. RELIEF_<tool> says what / drops to once that tool runs.
mock() {
  cat >"$ROOT/bin/$1" <<MOCK
#!$BASH
echo "$1 \$*" >>"\$LOG"
[ -z "\${RELIEF_$2:-}" ] || echo "\$RELIEF_$2" >"\$STATE/root"
MOCK
  chmod +x "$ROOT/bin/$1"
}
mock tmp-cleanup tmp
mock docker docker
mock nix-collect-garbage nix

cat >"$ROOT/bin/df" <<MOCK
#!$BASH
case "\$2" in
  /tmp) printf ' Use%%\n %s%%\n' "\$(cat "\$STATE/tmp")" ;;
  *) printf ' Use%%\n %s%%\n' "\$(cat "\$STATE/root")" ;;
esac
MOCK
chmod +x "$ROOT/bin/df"

# run ROOT_PCT TMP_PCT ARGS...: sets rc and resets the call log.
run() {
  echo "$1" >"$ROOT/root"
  echo "$2" >"$ROOT/tmp"
  shift 2
  : >"$LOG"
  rc=0
  bash "$SCRIPT" "$@" >"$ROOT/out" 2>&1 || rc=$?
}
called() { grep -q "^$1" "$LOG"; }

run 50 50 -y
[[ $rc == 0 && ! -s "$LOG" ]]
echo 'ok   below thresholds nothing runs'

run 50 90 -y
[[ $rc == 3 ]]
called 'tmp-cleanup -f 101 -y$'
if called docker || called nix-collect-garbage; then exit 1; fi
echo 'ok   full /tmp only runs tmp-cleanup, without touching overflow'

old="$HOME/.cache/go-build/old" new="$HOME/.cache/go-build/new"
touch "$new"
touch -d '1 day ago' "$old"
RELIEF_docker=80 run 90 50 -y
[[ $rc == 0 && ! -e "$old" && -e "$new" ]]
called 'tmp-cleanup -f 101 -y -o 7$'
called 'docker system prune -af$'
if called nix-collect-garbage; then exit 1; fi
echo 'ok   full / stops as soon as a step brings it under, keeps fresh go cache'

RELIEF_tmp=80 run 90 50 -y
if called docker; then exit 1; fi
echo 'ok   first step that frees enough ends the run'

run 90 50 -y
[[ $rc == 3 ]]
called 'nix-collect-garbage $'
echo 'ok   every step runs when nothing helps, exit 3, no -d and no --volumes'

touch -d '1 day ago' "$old"
run 90 90
[[ $rc == 3 && -e "$old" ]]
called 'tmp-cleanup -f 101 -o 7$'
if called docker || called nix-collect-garbage; then exit 1; fi
grep -q 'would run: docker system prune -af' "$ROOT/out"
echo 'ok   dry-run deletes nothing and names the steps'
