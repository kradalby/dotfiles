#!/usr/bin/env bash
set -euo pipefail

# osxphotos is not in nixpkgs, so it is expected on PATH (brew/pipx) rather
# than in runtimeInputs.

CONFIG="@config@"
DIR="/Volumes/album"

command -v osxphotos >/dev/null || {
  echo "osxphotos not on PATH (brew install osxphotos)" >&2
  exit 1
}

# macOS creates /Volumes/<name> on the boot disk for an unmounted share, and an
# export into that fills the system SSD. The sentinel is made by hand on the
# server, never here.
[ -e "$DIR/.album-here" ] || {
  echo "album share not mounted at $DIR" >&2
  exit 1
}

osxphotos export --load-config "$CONFIG" "$DIR"

# After the export: --cleanup deletes everything it did not put there.
osxphotos persons --json | jq '.["persons"] | {people: keys}' >"$DIR/people.json.tmp"
mv "$DIR/people.json.tmp" "$DIR/people.json"
