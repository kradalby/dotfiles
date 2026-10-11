#!/usr/bin/env bash
set -euo pipefail

source_root="$1"
catalog="$source_root/.agents/plugins/marketplace.json"
marketplace="$(jq -er '.name' "$catalog")"

# Activation can run from a trusted repo with its own marketplace overrides.
cd "$HOME"
configured="$(codex plugin marketplace list --json)"
if jq -e --arg name "$marketplace" --arg source "$source_root" '
  any(.marketplaces[]; .name == $name and
    (.marketplaceSource.sourceType != "local" or .marketplaceSource.source != $source))
' <<<"$configured" >/dev/null; then
  codex plugin marketplace remove "$marketplace"
fi
codex plugin marketplace add "$source_root"

# The same skill was previously installed from two Anthropic marketplaces.
if [ "$marketplace" = "claude-plugins-official" ]; then
  codex plugin remove frontend-design@claude-code-plugins
fi

# Always refresh: source revisions can change without a plugin-version bump.
jq -r '.plugins[].name' "$catalog" | while IFS= read -r name; do
  codex plugin add "$name@$marketplace"
done
