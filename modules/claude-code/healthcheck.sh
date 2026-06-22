#!/usr/bin/env bash
# claude remote-control watchdog.
#
# Restart an instance ONLY when it has been stuck disconnected from the
# claude.ai bridge past THRESHOLD seconds. Healthy, busy, and idle instances are
# left untouched. Silent self-heal: actions print to stdout, which the unit
# captures (journal on Linux, log file on macOS). Usage:
#
#   healthcheck.sh <instance-name> [<instance-name> ...]
#   healthcheck.sh --self-test
#
# NOTE: this scrapes the reconnect spinner ("Reconnecting ... disconnected
# <N>[smh]") that `claude remote-control` prints. That string is not a stable
# API and rides pkgs.master.claude-code, which updates often. The app's own
# counter resets to 0s on each successful reconnect, so brief flaps stay small;
# only a genuinely stuck/lost-login instance lets it grow. --self-test parses the
# canned samples below, so a format drift fails loudly. Upgrade path: a real
# `claude remote-control status` command, if one ever ships.
set -euo pipefail

THRESHOLD=300 # seconds disconnected before we restart
WINDOW=2      # minutes of recent log to consider (freshness)
OS=$(uname)

# disc_seconds <text> -> echoes the disconnect counter from the text in seconds,
# or nothing if no reconnect token is present.
disc_seconds() {
  local tok n unit
  tok=$(grep -oE 'disconnected [0-9]+[smh]' <<<"$1" | tail -1) || true
  [ -n "$tok" ] || return 0
  n=${tok##disconnected }
  unit=${n: -1}
  n=${n%[smh]}
  case "$unit" in
    s) echo "$n" ;;
    m) echo "$((n * 60))" ;;
    h) echo "$((n * 3600))" ;;
  esac
}

# should_restart <log window> -> 0 (restart) / 1 (leave alone). Pure decision
# logic, exercised by --self-test. We look only at the LAST non-blank line: while
# disconnected the spinner redraws every ~1-2s, so a stuck instance ends on a
# reconnect line; one that flapped and recovered ends on normal activity.
should_restart() {
  local last secs
  last=$(printf '%s' "$1" | tr '\r' '\n' | grep -vE '^[[:space:]]*$' | tail -1) || true
  secs=$(disc_seconds "$last")
  [ -n "$secs" ] && [ "$secs" -ge "$THRESHOLD" ]
}

# fetch_window <instance> -> prints the instance's fresh (last WINDOW min) log.
# Empty output (idle/connected, emitting nothing) correctly means "leave alone".
fetch_window() {
  case "$OS" in
    Linux)
      journalctl --user -u "claude-code-$1.service" --since "-${WINDOW}min" -o cat 2>/dev/null
      ;;
    Darwin)
      local log="$HOME/Library/Logs/claude-code-$1.log"
      # No journald timestamps here, so gate on file mtime: an idle instance
      # isn't writing, so a stale file means "not stuck right now".
      if [ -f "$log" ] && find "$log" -mmin "-${WINDOW}" 2>/dev/null | grep -q .; then
        tail -n 50 "$log" 2>/dev/null
      fi
      ;;
  esac
}

restart_instance() {
  case "$OS" in
    Linux) systemctl --user restart "claude-code-$1.service" ;;
    Darwin) launchctl kickstart -k "gui/$(id -u)/claude-code-$1" ;;
  esac
}

main() {
  local name window
  for name in "$@"; do
    window=$(fetch_window "$name")
    if should_restart "$window"; then
      echo "claude-code-health: $name stuck disconnected >= ${THRESHOLD}s, restarting"
      restart_instance "$name" || echo "claude-code-health: restart of $name FAILED"
    fi
  done
}

self_test() {
  local fail=0 got
  check() { # <desc> <yes|no> <log>
    if should_restart "$3"; then got=yes; else got=no; fi
    if [ "$got" = "$2" ]; then
      echo "ok:   $1"
    else
      echo "FAIL: $1 (expected $2, got $got)"
      fail=1
    fi
  }
  check "6-min disconnect -> restart" yes \
    '·—· Reconnecting · retrying in 602ms · disconnected 6m'
  check "360s disconnect -> restart" yes \
    '·/· Reconnecting · retrying in 2.0s · disconnected 360s'
  check "10s flap -> leave alone" no \
    '·—· Reconnecting · retrying in 602ms · disconnected 10s'
  check "flap then recovered -> leave alone" no \
    $'·—· Reconnecting · retrying in 1s · disconnected 48s\n    Capacity: 1/5 · New sessions will be created in the current directory'
  check "idle / empty -> leave alone" no ""
  check "normal activity only -> leave alone" no \
    '    Capacity: 0/5 · New sessions will be created in the current directory'
  check "just below threshold (299s) -> leave alone" no \
    '·—· Reconnecting · retrying in 1s · disconnected 299s'
  [ "$fail" -eq 0 ] && echo "all self-tests passed"
  return "$fail"
}

case "${1:-}" in
  --self-test) self_test ;;
  "") echo "usage: $0 <instance-name> [...] | --self-test" >&2; exit 2 ;;
  *) main "$@" ;;
esac
