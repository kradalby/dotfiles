# Homebridge Migration Status

## ✅ What's Been Done

### 1. Created Modern Package Structure
```
pkgs/homebridge/
├── default.nix              # Main wrapper combining homebridge + plugins
├── plugins/                 # Individual plugin packages (buildNpmPackage)
│   ├── camera-ffmpeg.nix
│   ├── mqttthing.nix
│   ├── nefit-easy.nix
│   ├── philips-tv6.nix
│   └── xiaomi-roborock-vacuum.nix
├── README.md                # Complete documentation
├── MIGRATION.md            # This file
└── update-hashes.sh        # Helper script for hash calculation
```

### 2. Migrated from node2nix to buildNpmPackage
- **Old approach**: 8,708 lines of generated code across 2 packages
- **New approach**: ~200 lines of clean, maintainable Nix
- **No more code generation**: Just update version + hashes

### 3. Updated Integration Points
- ✅ Updated `pkgs/overlays/default.nix` to expose `homebridge-with-plugins`
- ✅ Updated `modules/homebridge.nix` to use new package as default
- ✅ Commented out old node2nix packages in overlay (kept for backwards compat)

### 4. Created Documentation
- ✅ Comprehensive README.md with update instructions
- ✅ Helper script for hash calculation
- ✅ Migration guide (this file)

## ⏳ What Needs To Be Done (Requires Linux Machine)

### 1. Calculate Plugin Hashes

Each plugin needs two hashes:
1. **Source hash** - hash of the GitHub repository at the specific version
2. **npmDepsHash** - hash of all npm dependencies from package-lock.json

**Current plugin versions to hash:**
- `homebridge-philips-tv6@1.0.7` (owner: 98oktay)
- `homebridge-mqttthing@1.1.47` (owner: arachnetech)
- `homebridge-camera-ffmpeg@3.1.4` (owner: Sunoo)
- `homebridge-nefit-easy@2.3.1` (owner: robertklep)
- `homebridge-xiaomi-roborock-vacuum@1.0.0-alpha.1` (owner: homebridge-xiaomi-roborock-vacuum)

**Methods to calculate hashes:**

#### Option A: Use the helper script (recommended)
```bash
# On a Linux machine with Nix:
cd /Users/kradalby/git/dotfiles/pkgs/homebridge
./update-hashes.sh
```

#### Option B: Manual hash calculation
For each plugin:

1. Get source hash:
```bash
nix-shell -p nix-prefetch-github --run \
  "nix-prefetch-github OWNER REPO --rev vVERSION" | grep hash
```

2. Clone repo and get npmDepsHash:
```bash
git clone --depth 1 --branch vVERSION https://github.com/OWNER/REPO /tmp/plugin
cd /tmp/plugin
nix-shell -p prefetch-npm-deps --run "prefetch-npm-deps package-lock.json"
```

3. Update the plugin's .nix file with both hashes

#### Option C: Let Nix tell you (iterative)
```bash
# 1. Try to build (will fail with hash error)
nix build .#homebridge-with-plugins

# 2. Copy the correct hash from error message to plugin file
# 3. Try again (will fail with npmDepsHash error)
# 4. Copy the correct npmDepsHash from error message
# 5. Repeat for each plugin
```

### 2. Test the Build

Once all hashes are calculated:

```bash
# On a Linux machine:
cd /Users/kradalby/git/dotfiles
nix build .#homebridge-with-plugins

# Or if using NixOS/Linux system:
sudo nixos-rebuild build --flake .#YOUR_SYSTEM
# (only if homebridge is enabled on that system)
```

### 3. Deploy to Your Homebridge Server

Once tested:

```bash
# On the server running homebridge:
cd /path/to/dotfiles
sudo nixos-rebuild switch --flake .#SERVER_NAME
```

### 4. Clean Up Old Files

After confirming the new package works:

```bash
# Remove old node2nix directories
rm -rf pkgs/overlays/homebridge/
rm -rf pkgs/overlays/homebridge-plugins/

# Update overlay to remove commented lines
# Edit pkgs/overlays/default.nix and remove:
#   # homebridge = prev.callPackage ./homebridge/override.nix {};
#   # homebridgePlugins = prev.callPackage ./homebridge-plugins {};
```

## 📋 Testing Checklist

Before removing old packages, verify:

- [ ] All plugins build successfully
- [ ] homebridge-with-plugins builds successfully
- [ ] Homebridge service starts without errors
- [ ] All plugins are recognized by homebridge
- [ ] Homebridge config UI (port 8581) is accessible
- [ ] HomeKit accessories are working
- [ ] No runtime errors in homebridge logs

Check logs with:
```bash
journalctl -u homebridge-INSTANCE_NAME -f
```

## 🔍 Comparison

### Before (node2nix)
```bash
$ wc -l pkgs/overlays/homebridge/node-packages.nix
5274 lines

$ wc -l pkgs/overlays/homebridge-plugins/node-packages.nix
3434 lines

Total: 8,708 lines of generated code
```

### After (buildNpmPackage)
```bash
$ find pkgs/homebridge -name "*.nix" -exec wc -l {} + | tail -1
~200 lines total (all hand-written, maintainable)
```

### Update Process Comparison

**Old (node2nix):**
```bash
cd pkgs/overlays/homebridge
node2nix -i node-packages.json --nodejs-18
# Regenerates 5,274 lines
# Often breaks, requires manual fixes
```

**New (buildNpmPackage):**
```nix
# Just edit one line:
version = "1.1.50"; # NOTE: manual update required

# Then recalculate hashes (one command):
nix-shell -p nix-prefetch-github --run "nix-prefetch-github owner repo --rev v1.1.50"
```

## 🎯 Why This Migration Matters

1. **Maintainability**: 200 lines vs 8,708 lines
2. **Modern**: Aligns with nixpkgs 25.05 best practices
3. **Upstream Support**: Uses nixpkgs homebridge/homebridge-config-ui-x directly
4. **No Code Generation**: No more running node2nix and debugging generated code
5. **Easier Updates**: Just change version + hash, not regenerate everything
6. **Better Documentation**: Clear, simple package definitions
7. **Future-Proof**: buildNpmPackage is the standard going forward

## 📚 Resources

- [nixpkgs buildNpmPackage docs](https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/javascript.section.md)
- [Homebridge GitHub](https://github.com/homebridge/homebridge)
- [Plugin README](./README.md) - Complete usage and update guide
- [Helper Script](./update-hashes.sh) - Automated hash calculation

## 🚀 Next Steps

1. **On a Linux machine** (or via remote builder):
   - Run `./update-hashes.sh` or manually calculate hashes
   - Test build with `nix build .#homebridge-with-plugins`

2. **Deploy to homebridge server**:
   - Push changes to git
   - Pull on server
   - `sudo nixos-rebuild switch`

3. **Verify everything works**:
   - Check homebridge service status
   - Check logs for errors
   - Test HomeKit accessories

4. **Clean up** (after confirming success):
   - Remove old node2nix directories
   - Update overlay to remove commented lines
   - Celebrate 8,500 fewer lines of generated code! 🎉
