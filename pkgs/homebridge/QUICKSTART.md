# Quick Start - Calculate Hashes and Build

Run this on a **Linux machine** or via **remote builder**.

## One-Command Solution

```bash
cd /Users/kradalby/git/dotfiles/pkgs/homebridge
./update-hashes.sh
```

This will:
1. Calculate source hashes for all 5 plugins
2. Calculate npmDepsHash for all 5 plugins
3. Update all plugin .nix files automatically
4. Show you the build command to test

## Then Test Build

```bash
cd /Users/kradalby/git/dotfiles
nix build .#homebridge-with-plugins
```

If successful, you'll see a `result` symlink pointing to the built package.

## Manual Method (If Script Fails)

For each plugin, run these two commands:

### 1. homebridge-philips-tv6

```bash
# Source hash
nix-shell -p nix-prefetch-github --run \
  "nix-prefetch-github 98oktay homebridge-philips-tv6 --rev v1.0.7"

# Clone and get npmDepsHash
git clone --depth 1 --branch v1.0.7 \
  https://github.com/98oktay/homebridge-philips-tv6 /tmp/philips-tv6
nix-shell -p prefetch-npm-deps --run \
  "prefetch-npm-deps /tmp/philips-tv6/package-lock.json"

# Copy both hashes to pkgs/homebridge/plugins/philips-tv6.nix
```

### 2. homebridge-mqttthing

```bash
# Source hash
nix-shell -p nix-prefetch-github --run \
  "nix-prefetch-github arachnetech homebridge-mqttthing --rev v1.1.47"

# Clone and get npmDepsHash
git clone --depth 1 --branch v1.1.47 \
  https://github.com/arachnetech/homebridge-mqttthing /tmp/mqttthing
nix-shell -p prefetch-npm-deps --run \
  "prefetch-npm-deps /tmp/mqttthing/package-lock.json"

# Copy both hashes to pkgs/homebridge/plugins/mqttthing.nix
```

### 3. homebridge-camera-ffmpeg

```bash
# Source hash
nix-shell -p nix-prefetch-github --run \
  "nix-prefetch-github Sunoo homebridge-camera-ffmpeg --rev v3.1.4"

# Clone and get npmDepsHash
git clone --depth 1 --branch v3.1.4 \
  https://github.com/Sunoo/homebridge-camera-ffmpeg /tmp/camera-ffmpeg
nix-shell -p prefetch-npm-deps --run \
  "prefetch-npm-deps /tmp/camera-ffmpeg/package-lock.json"

# Copy both hashes to pkgs/homebridge/plugins/camera-ffmpeg.nix
```

### 4. homebridge-nefit-easy

```bash
# Source hash
nix-shell -p nix-prefetch-github --run \
  "nix-prefetch-github robertklep homebridge-nefit-easy --rev v2.3.1"

# Clone and get npmDepsHash
git clone --depth 1 --branch v2.3.1 \
  https://github.com/robertklep/homebridge-nefit-easy /tmp/nefit-easy
nix-shell -p prefetch-npm-deps --run \
  "prefetch-npm-deps /tmp/nefit-easy/package-lock.json"

# Copy both hashes to pkgs/homebridge/plugins/nefit-easy.nix
```

### 5. homebridge-xiaomi-roborock-vacuum

```bash
# Source hash
nix-shell -p nix-prefetch-github --run \
  "nix-prefetch-github homebridge-xiaomi-roborock-vacuum homebridge-xiaomi-roborock-vacuum --rev v1.0.0-alpha.1"

# Clone and get npmDepsHash
git clone --depth 1 --branch v1.0.0-alpha.1 \
  https://github.com/homebridge-xiaomi-roborock-vacuum/homebridge-xiaomi-roborock-vacuum /tmp/roborock
nix-shell -p prefetch-npm-deps --run \
  "prefetch-npm-deps /tmp/roborock/package-lock.json"

# Copy both hashes to pkgs/homebridge/plugins/xiaomi-roborock-vacuum.nix
```

## Verify All Hashes Are Set

```bash
# Check all plugins have non-empty hashes
grep 'hash = ""' pkgs/homebridge/plugins/*.nix
grep 'npmDepsHash = ""' pkgs/homebridge/plugins/*.nix

# Should return nothing if all hashes are set
```

## Build and Deploy

```bash
# Build
nix build .#homebridge-with-plugins

# Deploy to server
ssh YOUR_SERVER "cd /path/to/dotfiles && git pull && sudo nixos-rebuild switch"
```

## Troubleshooting

### "No package-lock.json found"
Some plugins might not have a package-lock.json. In that case:
1. Clone the repo
2. Run `npm install` to generate package-lock.json
3. Then run prefetch-npm-deps

### Build fails even with hashes
Check the error message - it might be:
- Missing dependencies in buildInputs
- Need to set `dontNpmBuild = true`
- Need to specify `npmBuildScript`

See existing plugins for examples.

### Script says "command not found"
Make sure you're running on Linux with Nix installed. Darwin (macOS) has issues with some of these tools.

## Time Estimate

- Automated (script): ~5 minutes
- Manual (all 5 plugins): ~15 minutes
- Build and test: ~10 minutes

**Total: ~15-25 minutes**
