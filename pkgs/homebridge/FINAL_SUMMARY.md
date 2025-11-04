# ✅ Homebridge Migration Complete - Per-Instance Plugin Support

## What Changed

Your homebridge setup has been completely modernized with **per-instance plugin selection**.

### Before (Old node2nix approach)
- ❌ All plugins baked into one package
- ❌ All instances got ALL plugins whether they needed them or not
- ❌ 8,708 lines of generated code
- ❌ Hard to maintain

### After (Modern buildNpmPackage approach)
- ✅ Each instance selects only the plugins it needs
- ✅ Plugins are compiled on-demand per instance
- ✅ ~200 lines of clean, maintainable Nix
- ✅ Easy to maintain and update

## How to Use

### Configuration Example

```nix
# In your NixOS configuration
{
  services.homebridges = {
    # Living room - TV and cameras
    living-room = {
      enable = true;
      port = 51781;
      uiPort = 8581;

      plugins = with pkgs.homebridgePlugins; [
        homebridge-philips-tv6
        homebridge-camera-ffmpeg
        homebridge-mqttthing
      ];
    };

    # Bedroom - just the vacuum
    bedroom = {
      enable = true;
      port = 51782;
      uiPort = 8582;

      plugins = with pkgs.homebridgePlugins; [
        homebridge-xiaomi-roborock-vacuum
      ];
    };
  };
}
```

**Result**:
- `living-room` instance gets 3 plugins
- `bedroom` instance gets only 1 plugin
- Each instance is isolated and optimized

## Available Plugins

Use `pkgs.homebridgePlugins.<name>`:

| Plugin | Purpose |
|--------|---------|
| `homebridge-philips-tv6` | Philips Android TV control |
| `homebridge-mqttthing` | MQTT devices |
| `homebridge-camera-ffmpeg` | Camera support |
| `homebridge-nefit-easy` | Nefit Easy boiler |
| `homebridge-xiaomi-roborock-vacuum` | Xiaomi vacuum |

## Files Created

```
pkgs/homebridge/
├── default.nix              # Main package (accepts plugins parameter)
├── plugins.nix             # Exposes individual plugins
├── plugins/                # Individual plugin definitions
│   ├── camera-ffmpeg.nix
│   ├── mqttthing.nix
│   ├── nefit-easy.nix
│   ├── philips-tv6.nix
│   └── xiaomi-roborock-vacuum.nix
├── README.md               # Technical guide
├── USAGE.md                # Usage examples (START HERE!)
├── MIGRATION.md            # Migration status
├── QUICKSTART.md           # Hash calculation
└── update-hashes.sh        # Helper script
```

## Files Modified

- `pkgs/overlays/default.nix` - Exposes `homebridge-with-plugins` and `homebridgePlugins`
- `modules/homebridge.nix` - Added `plugins` option for per-instance selection

## Files Removed

- `pkgs/overlays/homebridge/` (5,274 lines of generated code)
- `pkgs/overlays/homebridge-plugins/` (3,434 lines of generated code)

## Next Steps

### 1. Calculate Plugin Hashes (One-Time Setup)

On a Linux machine:
```bash
cd /path/to/dotfiles/pkgs/homebridge
./update-hashes.sh
```

This calculates the hashes for all 5 plugins (see `QUICKSTART.md` for details).

### 2. Update Your Configuration

Update your NixOS config to specify plugins per instance:

```nix
# Find your current homebridge config and add plugins:
services.homebridges.<instance-name> = {
  enable = true;
  # ... existing config ...

  # ADD THIS:
  plugins = with pkgs.homebridgePlugins; [
    # List only the plugins THIS instance needs
    homebridge-mqttthing
  ];
};
```

### 3. Deploy

```bash
# On your homebridge server:
sudo nixos-rebuild switch
```

### 4. Verify

```bash
# Check service is running
systemctl status homebridge-*

# Check logs
journalctl -u homebridge-<instance> -f

# Verify plugins are loaded (should show only the ones you configured)
# Check homebridge UI at http://localhost:8581
```

## How Per-Instance Plugins Work

When you configure:
```nix
plugins = with pkgs.homebridgePlugins; [
  homebridge-mqttthing
  homebridge-camera-ffmpeg
];
```

The module automatically calls:
```nix
pkgs.homebridge-with-plugins.withPlugins [
  pkgs.homebridgePlugins.homebridge-mqttthing
  pkgs.homebridgePlugins.homebridge-camera-ffmpeg
]
```

This creates a custom homebridge wrapper with:
- `NODE_PATH` pointing to: homebridge + homebridge-config-ui-x + your 2 plugins
- Only those packages are accessible to this instance
- Other instances can have completely different plugin sets

## Benefits

1. **Lighter instances** - Only load what you need (saves memory)
2. **Easier debugging** - Isolate plugin issues to specific instances
3. **Better security** - Separate concerns by function/room
4. **Flexible deployment** - Mix and match per use case
5. **Clear configuration** - See exactly what each instance uses
6. **No bloat** - Don't load camera plugin if instance doesn't use cameras

## Documentation

- **`USAGE.md`** - Start here! Complete usage examples
- **`README.md`** - Technical details and update process
- **`QUICKSTART.md`** - How to calculate hashes (one-time)
- **`MIGRATION.md`** - Migration status and details
- **`STATUS.md`** - Quick overview

## Key Features

### ✅ Per-Instance Plugin Selection
Each homebridge instance can have its own plugin list.

### ✅ Shared Plugin Definitions
All plugins defined once in `pkgs.homebridgePlugins`, used anywhere.

### ✅ Zero Plugin Default
If you don't specify `plugins = []`, you get bare homebridge (+ config-ui).

### ✅ Easy to Add New Plugins
Just add a new `.nix` file in `plugins/` and expose it in `plugins.nix`.

### ✅ Upstream Core Packages
Uses `pkgs.homebridge` and `pkgs.homebridge-config-ui-x` from nixpkgs directly.

## Comparison

| Feature | Old Setup | New Setup |
|---------|-----------|-----------|
| **Plugin Selection** | All or nothing | Per-instance |
| **Lines of Code** | 8,708 generated | ~200 clean |
| **Instances** | All same plugins | Each different |
| **Memory Usage** | High (all plugins loaded) | Low (only needed plugins) |
| **Debugging** | Hard (which plugin?) | Easy (isolated) |
| **Updates** | Regenerate all | Change version + hash |
| **Maintainability** | Low | High |

## Example: Three Different Instances

```nix
{
  services.homebridges = {
    # Heavy instance - all the things
    main = {
      enable = true;
      plugins = with pkgs.homebridgePlugins; [
        homebridge-philips-tv6
        homebridge-mqttthing
        homebridge-camera-ffmpeg
        homebridge-nefit-easy
        homebridge-xiaomi-roborock-vacuum
      ];
    };

    # Light instance - just MQTT
    iot-devices = {
      enable = true;
      port = 51782;
      uiPort = 8582;
      plugins = with pkgs.homebridgePlugins; [
        homebridge-mqttthing
      ];
    };

    # Minimal instance - testing only
    test = {
      enable = true;
      port = 51783;
      uiPort = 8583;
      plugins = [];  # No plugins, just homebridge
    };
  };
}
```

Result:
- `main`: Heavy, 5 plugins loaded
- `iot-devices`: Light, 1 plugin loaded
- `test`: Minimal, 0 plugins loaded

Each is independent and optimized for its purpose!

## Success Criteria

You'll know everything is working when:

- ✅ Each instance starts successfully
- ✅ Only configured plugins appear in each instance's UI
- ✅ HomeKit accessories work as expected
- ✅ No errors in logs about missing plugins
- ✅ Different instances have different plugin lists

## Getting Help

If you need help:

1. Check `USAGE.md` for configuration examples
2. Check logs: `journalctl -u homebridge-<instance> -f`
3. Verify plugin hashes are calculated (not empty strings)
4. Check NODE_PATH in service: `systemctl cat homebridge-<instance>`

---

**Status**: ✅ Complete and ready to use (after hash calculation)

**Next Action**: Calculate hashes on Linux machine, then deploy!
