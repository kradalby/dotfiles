# Homebridge Usage Guide

## Per-Instance Plugin Configuration

Each homebridge instance can have its own set of plugins. This is the **recommended approach**.

### Example Configuration

```nix
# In your NixOS configuration
{
  services.homebridges = {
    # Instance 1: Living room with TV and cameras
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

    # Instance 2: Bedroom with vacuum only
    bedroom = {
      enable = true;
      port = 51782;
      uiPort = 8582;

      plugins = with pkgs.homebridgePlugins; [
        homebridge-xiaomi-roborock-vacuum
      ];
    };

    # Instance 3: Basement with boiler
    basement = {
      enable = true;
      port = 51783;
      uiPort = 8583;

      plugins = with pkgs.homebridgePlugins; [
        homebridge-nefit-easy
        homebridge-mqttthing
      ];
    };
  };
}
```

## Available Plugins

All plugins are in `pkgs.homebridgePlugins`:

- `homebridge-philips-tv6` - Philips Android TV control
- `homebridge-mqttthing` - MQTT device support
- `homebridge-camera-ffmpeg` - Camera support via ffmpeg
- `homebridge-nefit-easy` - Nefit Easy boiler control
- `homebridge-xiaomi-roborock-vacuum` - Xiaomi vacuum support

## How It Works

When you configure:
```nix
plugins = with pkgs.homebridgePlugins; [
  homebridge-mqttthing
  homebridge-camera-ffmpeg
];
```

The module automatically creates a custom homebridge package using:
```nix
pkgs.homebridge-with-plugins.withPlugins [
  pkgs.homebridgePlugins.homebridge-mqttthing
  pkgs.homebridgePlugins.homebridge-camera-ffmpeg
]
```

This builds a homebridge wrapper with **only those specific plugins** in the NODE_PATH.

## Advanced: Custom Package Override

If you need full control, you can override the package directly:

```nix
{
  services.homebridges.my-instance = {
    enable = true;

    # Option 1: Just use plugins (recommended)
    plugins = with pkgs.homebridgePlugins; [ homebridge-mqttthing ];

    # Option 2: Override package completely
    package = pkgs.homebridge-with-plugins.withPlugins [
      pkgs.homebridgePlugins.homebridge-mqttthing
      # Could even add plugins from other sources here
    ];
  };
}
```

## No Plugins

If you don't need any plugins, just omit the `plugins` option:

```nix
{
  services.homebridges.minimal = {
    enable = true;
    # No plugins configured = bare homebridge
  };
}
```

This will give you homebridge + homebridge-config-ui-x (always included), with no additional plugins.

## Multiple Instances with Different Plugins

The beauty of this approach is each instance is independent:

```nix
{
  services.homebridges = {
    # Heavy instance with all plugins
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

    # Lightweight instance with one plugin
    test = {
      enable = true;
      port = 51782;
      uiPort = 8582;
      plugins = with pkgs.homebridgePlugins; [
        homebridge-mqttthing
      ];
    };
  };
}
```

Each instance gets its own:
- User account (`homebridge-main`, `homebridge-test`)
- Data directory (`/var/lib/homebridge-main`, `/var/lib/homebridge-test`)
- Service (`homebridge-main.service`, `homebridge-test.service`)
- Plugin set (as configured)

## Benefits of Per-Instance Plugins

1. **Lighter instances** - Only load what you need
2. **Easier debugging** - Isolate plugin issues
3. **Better security** - Separate concerns
4. **Flexible deployment** - Mix and match per room/function
5. **Clear configuration** - See exactly what each instance uses

## Migration from Old Setup

**Old approach** (single package with all plugins):
```nix
package = pkgs.homebridge;  # Had all plugins baked in
```

**New approach** (per-instance plugin selection):
```nix
plugins = with pkgs.homebridgePlugins; [
  homebridge-mqttthing  # Only what this instance needs
];
# package is auto-generated from plugins
```

## Checking What's Installed

To see what plugins an instance has:

```bash
# Check the homebridge package
nix-store -q --tree /run/current-system | grep homebridge

# Or check the NODE_PATH in the service
systemctl cat homebridge-INSTANCE | grep NODE_PATH
```

## Troubleshooting

### Plugin not found at runtime

Make sure the plugin is in the instance's `plugins` list:
```nix
plugins = with pkgs.homebridgePlugins; [
  homebridge-your-plugin  # Add here
];
```

### All instances have same plugins

Check that each instance has its own `plugins` configuration, not sharing the package.

### Want to share plugins across instances

Define them once:
```nix
let
  commonPlugins = with pkgs.homebridgePlugins; [
    homebridge-mqttthing
  ];
in {
  services.homebridges = {
    instance1.plugins = commonPlugins ++ [ pkgs.homebridgePlugins.homebridge-camera-ffmpeg ];
    instance2.plugins = commonPlugins ++ [ pkgs.homebridgePlugins.homebridge-philips-tv6 ];
  };
}
```
