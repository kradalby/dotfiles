#!/usr/bin/env bash
set -euo pipefail
# TODO(ghostty): Workaround for Ghostty lacking an exec/command keybind action.
# Uses ghostty-tab (github.com/seruman/boo, installed as ghostty-tab) to open a
# new Ghostty tab with a command via AppleScript, completely out-of-band from
# the current surface. Uses --initial-input instead of --command so the new tab
# starts with the user's login shell (fish) which has the Nix-managed PATH for
# mosh.
# Ref: https://github.com/ghostty-org/ghostty/issues/9961
# Ref: https://github.com/ghostty-org/ghostty/discussions/10919

exec ghostty-tab tab new --initial-input "mosh dev.ldn.fap.no
"
