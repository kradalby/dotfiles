#!/usr/bin/env bash
set -euo pipefail

# rmkh — remove entries from ~/.ssh/known_hosts.
#
#   rmkh 42        delete line 42 (also accepts sed specs like 5,10)
#   rmkh host/ip   delete ALL entries for a host/IP, with preview + confirmation

kh="$HOME/.ssh/known_hosts"
arg="${1:?usage: rmkh <line-number|host>}"

# Pure digits (or digit,comma ranges) => old line-number mode, untouched.
if [[ "$arg" =~ ^[0-9][0-9,]*$ ]]; then
  sed -i "${arg}d" "$kh"
  exit 0
fi

# Host/IP mode.
if ! ssh-keygen -F "$arg" -f "$kh" >/dev/null; then
  echo "No known_hosts entries for '$arg'."
  exit 0
fi

echo "Entries for '$arg':"
ssh-keygen -F "$arg" -f "$kh"
read -rp "Delete all of the above? [y/N] " reply
case "$reply" in
  [yY]) ssh-keygen -R "$arg" -f "$kh" ;;
  *) echo "Aborted." ;;
esac
