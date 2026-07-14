#!/usr/bin/env bash
set -euo pipefail
# Toggle Tailscale account between host-specific pair.
# Invoked from skhd. Uses the macOS app binary directly since skhd runs
# /bin/sh and does not source the fish alias.

PATH="/opt/homebrew/bin:$HOME/.nix-profile/bin:/run/current-system/sw/bin:$PATH"
export PATH

TS_APP=/Applications/Tailscale.app
TS=$TS_APP/Contents/MacOS/Tailscale

# Notifications go through a tiny AppleScript applet built by nix-darwin
# activation; its bundle icon is Tailscale's. terminal-notifier and alerter
# both hang on Sonoma+ waiting for UNUserNotificationCenter authorization.
# Title + message are URL-encoded into the bundle's custom URL scheme;
# `open --args` is swallowed by Cocoa on macOS 26.
notify() {
  t=$(printf '%s' "$1" | jq -sRr @uri)
  m=$(printf '%s' "$2" | jq -sRr @uri)
  /usr/bin/open "tailscalenotify://show?title=${t}&msg=${m}" >/dev/null 2>&1 || true
}

fail() {
  echo "tailscale-switch-toggle: $1" >&2
  notify "Tailscale switch failed" "$1"
  exit 1
}

host=$(hostname -s)
case "$host" in
  kratail2)
    a="kristoffer@tailscale.com"
    b="kradalby@kradalby.no"
    ;;
  krair)
    a="kradalby@kradalby.no"
    b="kd@sandefjordfiber.no"
    ;;
  *)
    fail "no pair configured for $host"
    ;;
esac

list=$("$TS" switch --list --json)
current=$(printf '%s' "$list" | jq -r '.[] | select(.selected == true) | .account')

if [ "$current" = "$a" ]; then
  target="$b"
else
  target="$a"
fi

id=$(printf '%s' "$list" | jq -r --arg acct "$target" \
  'map(select(.account == $acct)) | .[0].id // empty')

[ -n "$id" ] || fail "account not found: $target"

notify "Tailscale" "Switching to ${target}…"
"$TS" switch "$id"
notify "Tailscale" "${current} → ${target}"
