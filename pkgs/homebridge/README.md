# Homebridge Package (Modern buildNpmPackage)

This is a modern, maintainable homebridge package using `buildNpmPackage` instead of the legacy `node2nix` approach.

**Key Feature**: Per-instance plugin selection - each homebridge instance can have its own set of plugins!

## Structure

```
pkgs/homebridge/
├── default.nix           # Main wrapper combining homebridge + plugins
├── plugins/              # Individual plugin packages
│   ├── camera-ffmpeg.nix
│   ├── mqttthing.nix
│   ├── nefit-easy.nix
│   ├── philips-tv6.nix
│   └── xiaomi-roborock-vacuum.nix
└── README.md            # This file
```

## Benefits over old node2nix approach

| Old (node2nix) | New (buildNpmPackage) |
|----------------|----------------------|
| 8,708 lines of generated code | ~200 lines of clean Nix |
| Regenerate with `node2nix` command | Just update version + hashes |
| Hard to maintain | Easy to maintain |
| Legacy approach | Modern nixpkgs standard |
| Generate 2 files per package | One file per package |

## Quick Start

Configure homebridge with per-instance plugins in your NixOS config:

```nix
{
  services.homebridges.living-room = {
    enable = true;
    port = 51781;
    uiPort = 8581;

    # Select only the plugins this instance needs
    plugins = with pkgs.homebridgePlugins; [
      homebridge-mqttthing
      homebridge-camera-ffmpeg
    ];
  };
}
```

See `USAGE.md` for complete examples.

## Available Plugins

All plugins are in `pkgs.homebridgePlugins`:

- `homebridge-philips-tv6` - Philips Android TV control
- `homebridge-mqttthing` - MQTT device support
- `homebridge-camera-ffmpeg` - Camera support via ffmpeg
- `homebridge-nefit-easy` - Nefit Easy boiler control
- `homebridge-xiaomi-roborock-vacuum` - Xiaomi vacuum support

Core packages (always included):
- `homebridge` - Main homebridge package (from nixpkgs)
- `homebridge-config-ui-x` - Web UI for homebridge (from nixpkgs)

## How to Update

### Update Homebridge Core

Homebridge core comes from nixpkgs, so it updates automatically with nixpkgs upgrades.

To use a specific version, you can override:
```nix
homebridge = pkgs.homebridge.override {
  # Add any overrides here if needed
};
```

### Update a Plugin

**Example: Updating homebridge-mqttthing from 1.1.47 to 1.1.50**

1. **Update version in the plugin file** (`plugins/mqttthing.nix`):
   ```nix
   version = "1.1.50"; # NOTE: manual update required
   ```

2. **Clear the hash** (set to empty string temporarily):
   ```nix
   hash = ""; # Run nix build to get the correct hash
   npmDepsHash = ""; # Will update in next step
   ```

3. **Build to get source hash**:
   ```bash
   cd /Users/kradalby/git/dotfiles
   nix build .#homebridge-with-plugins 2>&1 | grep "got:"
   ```

   Copy the hash from the error message and update the `hash` field.

4. **Calculate npmDepsHash**:

   First, fetch the source and find package-lock.json:
   ```bash
   # Fetch the source temporarily
   nix-shell -p nix-prefetch-github --run "nix-prefetch-github arachnetech homebridge-mqttthing --rev v1.1.50"

   # Or clone it temporarily
   git clone --depth 1 --branch v1.1.50 https://github.com/arachnetech/homebridge-mqttthing /tmp/mqttthing
   cd /tmp/mqttthing

   # Calculate the hash
   nix-shell -p prefetch-npm-deps --run "prefetch-npm-deps package-lock.json"
   ```

   Copy the output hash and update `npmDepsHash` in the plugin file.

5. **Test the build**:
   ```bash
   nix build .#homebridge-with-plugins
   ```

6. **Done!** The plugin is updated.

### Alternative: Let Nix Tell You the Hashes

An easier approach is to let Nix calculate hashes for you:

1. Update version
2. Clear both hashes (set to "")
3. Run `nix build` - it will fail and tell you the correct source hash
4. Update source hash
5. Run `nix build` again - it will fail and tell you the correct npmDepsHash
6. Update npmDepsHash
7. Run `nix build` - success!

## Adding a New Plugin

1. **Create a new plugin file** in `plugins/`:

```nix
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "homebridge-your-plugin";
  version = "1.0.0"; # NOTE: manual update required

  src = fetchFromGitHub {
    owner = "plugin-author";
    repo = "homebridge-your-plugin";
    rev = "v${version}";
    hash = ""; # Let nix tell you
  };

  npmDepsHash = ""; # Let nix tell you

  # Set to true if plugin has no build script
  dontNpmBuild = true;

  # If plugin HAS a build script:
  # npmBuildScript = "build";

  meta = with lib; {
    description = "Your plugin description";
    homepage = "https://github.com/author/repo";
    license = licenses.mit; # or asl20, isc, etc
    maintainers = [];
  };
}
```

2. **Add to plugins list** in `default.nix`:
```nix
plugins = [
  # ... existing plugins ...
  (callPackage ./plugins/your-plugin.nix {})
];
```

3. **Calculate hashes** using the method above

4. **Test**:
```bash
nix build .#homebridge-with-plugins
```

## Finding Plugin Information

### NPM Registry
```bash
curl -s "https://registry.npmjs.org/homebridge-plugin-name/latest" | grep -E '"version"|"repository"'
```

### GitHub
Most homebridge plugins follow this pattern:
- GitHub: `https://github.com/author/homebridge-plugin-name`
- Tags: Usually `v1.0.0` format
- npm name: `homebridge-plugin-name`

## Troubleshooting

### Build fails with "command not found: prefetch-npm-deps"
```bash
# Use nix-shell to get the tool
nix-shell -p prefetch-npm-deps --run "prefetch-npm-deps package-lock.json"
```

### Plugin doesn't work at runtime
Check that:
1. Plugin is in the `plugins` list in `default.nix`
2. Plugin built successfully
3. NODE_PATH includes the plugin (should be automatic)

### Hash mismatch errors
This means you need to update the hash. Just clear it (set to "") and let nix tell you the correct value.

## Comparison with Old Setup

**Old approach** (`pkgs/overlays/homebridge/` and `pkgs/overlays/homebridge-plugins/`):
- Total: 8,708 lines of generated code
- Update process: `node2nix -i node-packages.json --nodejs-18`
- Maintenance: High (regenerate everything, manual fixes)
- Files: `node-packages.nix`, `node-env.nix`, `default.nix`, `override.nix`

**New approach** (this directory):
- Total: ~200 lines of clean Nix
- Update process: Change version + hash
- Maintenance: Low (just version bumps)
- Files: One file per plugin + main wrapper

## Migration Notes

This package replaces:
- `/pkgs/overlays/homebridge/` (old node2nix setup)
- `/pkgs/overlays/homebridge-plugins/` (old node2nix setup)

The old directories can be removed once this package is tested and working.

## Integration with NixOS Module

Update your `modules/homebridge.nix` to use this package:

```nix
package = mkOption {
  type = types.package;
  description = "Package to use";
  default = pkgs.homebridge-with-plugins; # Changed from old overlay
};
```

See `modules/homebridge.nix` for the full module definition.
