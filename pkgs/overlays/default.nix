{...}: let
in
  final: prev: {
    tailscale-tools = prev.callPackage ./tailscale-tools.nix {
      buildGoModule = prev.buildGo122Module;
    };

    setec = prev.callPackage ./setec.nix {
      buildGoModule = prev.buildGo122Module;
    };

    squibble = prev.callPackage ./squibble.nix {
      buildGoModule = prev.buildGo122Module;
    };

    homebridge = prev.callPackage ./homebridge/override.nix {};

    homebridgePlugins = prev.callPackage ./homebridge-plugins {};

    eb = prev.callPackage ./eb.nix {};

    tasmota-exporter = prev.callPackage ./tasmota-exporter.nix {};

    # elm-review = prev.callPackage ./node-elm-review.nix {};

    cook-cli = prev.callPackage ./cook.nix {};

    webrepl_cli = prev.callPackage ./webrepl_cli.nix {
    };

    # osxphotos = prev.callPackage ./osxphotos.nix {};
  }
