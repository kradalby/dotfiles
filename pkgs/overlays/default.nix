{...}: let
in
  final: prev: {
    tailscale-tools = prev.callPackage ./tailscale-tools.nix {};

    setec = prev.callPackage ./setec.nix {};

    squibble = prev.callPackage ./squibble.nix {};

    eb = prev.callPackage ./eb.nix {};

    cook-cli = prev.callPackage ./cook.nix {};

    webrepl_cli = prev.callPackage ./webrepl_cli.nix {};

    ts-preauthkey = prev.callPackage ./ts-preauthkey {};

    rustic = prev.callPackage ./rustic.nix {};

    rustic-wrapper = prev.callPackage ../rustic-wrapper {};

    p3-controller = prev.callPackage ../p3-controller {};

    boo = prev.callPackage ./boo.nix {};

    pm-cli = prev.callPackage ./pm-cli.nix {};

    # osxphotos = prev.callPackage ./osxphotos.nix {};
  }
