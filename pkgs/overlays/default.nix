{ mach-nix, ... }:
final: prev: {
  golines = prev.callPackage ./golines.nix {
    buildGoModule = prev.buildGo117Module;
  };

  headscale = prev.callPackage ./headscale.nix {
    buildGoModule = prev.buildGo118Module;
  };

  act = prev.callPackage ./act.nix {
    buildGoModule = prev.buildGo118Module;
  };

  imapchive = prev.callPackage ./imapchive.nix {
    buildGoModule = prev.buildGo118Module;
  };

  homebridge = prev.callPackage ./homebridge/override.nix { };

  # glauth-ui = prev.callPackage ./glauth-ui.nix { pkgs = prev; inherit mach-nix; };
}
