#!/usr/bin/env bash

CONFIG="$HOME/Sync/config/osxphotos.toml"
DIR="/Volumes/storage/hugin/album/"

osxphotos export --load-config "$CONFIG" "$DIR"
osxphotos persons --json | jq '.["persons"] | {people: keys}' > "$DIR/people.json"
chmod -R 755 $DIR
