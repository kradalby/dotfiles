#!/usr/bin/env bash
# Helper script to calculate hashes for homebridge plugins
# This script helps you update plugin hashes semi-automatically

set -e

PLUGINS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/plugins" && pwd)"

echo "=== Homebridge Plugin Hash Calculator ==="
echo

calculate_plugin_hash() {
    local plugin_file="$1"
    local plugin_name=$(basename "$plugin_file" .nix)

    echo "Processing: $plugin_name"

    # Extract version, owner, repo from the nix file
    local version=$(grep 'version = "' "$plugin_file" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')
    local owner=$(grep 'owner = "' "$plugin_file" | sed 's/.*owner = "\([^"]*\)".*/\1/')
    local repo=$(grep 'repo = "' "$plugin_file" | sed 's/.*repo = "\([^"]*\)".*/\1/')

    echo "  Version: $version"
    echo "  Repo: $owner/$repo"

    # Calculate source hash using nix-prefetch-github
    echo "  Calculating source hash..."
    local src_hash=$(nix-shell -p nix-prefetch-github --run "nix-prefetch-github $owner $repo --rev v$version" 2>/dev/null | grep '"hash":' | sed 's/.*"hash": "\([^"]*\)".*/\1/')

    if [ -z "$src_hash" ]; then
        echo "  ❌ Failed to calculate source hash"
        return 1
    fi

    echo "  ✓ Source hash: $src_hash"

    # Clone repo temporarily to get package-lock.json
    local tmpdir=$(mktemp -d)
    echo "  Cloning repository to calculate npm deps hash..."
    git clone --quiet --depth 1 --branch "v$version" "https://github.com/$owner/$repo" "$tmpdir" 2>/dev/null || {
        echo "  ❌ Failed to clone repository"
        rm -rf "$tmpdir"
        return 1
    }

    # Calculate npmDepsHash
    if [ -f "$tmpdir/package-lock.json" ]; then
        echo "  Calculating npmDepsHash..."
        local npm_hash=$(nix-shell -p prefetch-npm-deps --run "prefetch-npm-deps $tmpdir/package-lock.json" 2>/dev/null)

        if [ -z "$npm_hash" ]; then
            echo "  ❌ Failed to calculate npmDepsHash"
            rm -rf "$tmpdir"
            return 1
        fi

        echo "  ✓ npmDepsHash: $npm_hash"

        # Update the file
        sed -i.bak "s|hash = \"[^\"]*\";|hash = \"$src_hash\";|" "$plugin_file"
        sed -i.bak "s|npmDepsHash = \"[^\"]*\";|npmDepsHash = \"$npm_hash\";|" "$plugin_file"
        rm -f "$plugin_file.bak"

        echo "  ✅ Updated $plugin_name"
    else
        echo "  ⚠️  No package-lock.json found"
        # Still update source hash
        sed -i.bak "s|hash = \"[^\"]*\";|hash = \"$src_hash\";|" "$plugin_file"
        rm -f "$plugin_file.bak"
    fi

    rm -rf "$tmpdir"
    echo
}

# Process all plugins
for plugin in "$PLUGINS_DIR"/*.nix; do
    calculate_plugin_hash "$plugin" || echo "Skipping $plugin due to errors"
done

echo "=== Done ==="
echo
echo "Now test the build with:"
echo "  cd /Users/kradalby/git/dotfiles"
echo "  nix build .#homebridge-with-plugins"
