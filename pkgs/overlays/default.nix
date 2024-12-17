{...}: let
in
  final: prev: {
    tailscale-tools = prev.callPackage ./tailscale-tools.nix {};

    setec = prev.callPackage ./setec.nix {};

    squibble = prev.callPackage ./squibble.nix {};

    homebridge = prev.callPackage ./homebridge/override.nix {};

    homebridgePlugins = prev.callPackage ./homebridge-plugins {};

    eb = prev.callPackage ./eb.nix {};

    tasmota-exporter = prev.callPackage ./tasmota-exporter.nix {};

    # elm-review = prev.callPackage ./node-elm-review.nix {};

    cook-cli = prev.callPackage ./cook.nix {};

    webrepl_cli = prev.callPackage ./webrepl_cli.nix {};

    ts-preauthkey = prev.callPackage ./ts-preauthkey {};

    tailscale-restic-proxy = prev.callPackage ./tailscale-restic-proxy.nix {};

    # osxphotos = prev.callPackage ./osxphotos.nix {};
  }
