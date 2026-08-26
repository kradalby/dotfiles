#!/usr/bin/env bash
# Regression check for the one mistake that loses a running session: a session
# directory's own mtime does not track writes nested inside it, so age must be
# the newest mtime anywhere below. Dry-run only; the fixture is the only thing
# this creates, and it is removed on exit.
set -o errexit -o nounset

SCRIPT=${1:-$(dirname "$0")/tmp-cleanup.sh}
ROOT=/tmp/claude-999999
trap 'rm -rf -- "$ROOT"' EXIT
rm -rf -- "$ROOT"

# stale: nothing written for two days, in or below it
mkdir -p "$ROOT/-fixture/stale/tasks"
echo x >"$ROOT/-fixture/stale/tasks/old.output"
touch -d '2 days ago' "$ROOT/-fixture/stale/tasks/old.output" \
  "$ROOT/-fixture/stale/tasks" "$ROOT/-fixture/stale"

# trap: dir mtime two days stale, but a nested file written just now
mkdir -p "$ROOT/-fixture/trap/tasks"
echo x >"$ROOT/-fixture/trap/tasks/live.output"
touch -d '2 days ago' "$ROOT/-fixture/trap/tasks" "$ROOT/-fixture/trap"

out=$(bash "$SCRIPT" -s 60 2>&1) || true
fail=0

if grep -qE '^\[DRY\] +'"$ROOT"'/-fixture/stale ' <<<"$out"; then
  echo "ok   stale session would be removed"
else
  echo "FAIL stale session was not removed"
  fail=1
fi

if grep -qE '^\[(DRY|RM)\] +'"$ROOT"'/-fixture/trap ' <<<"$out"; then
  echo "FAIL live session removed on stale dir mtime — the trap"
  fail=1
else
  echo "ok   live session kept despite stale dir mtime"
fi

if grep -qE '^\[(DRY|RM)\] +'"$ROOT"' ' <<<"$out"; then
  echo "FAIL claude-<pid> root removed; it must stay on the skip list"
  fail=1
else
  echo "ok   claude-<pid> root left alone"
fi

exit "$fail"
