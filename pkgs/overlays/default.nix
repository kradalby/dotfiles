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

  # glauth-ui = prev.callPackage ./glauth-ui.nix { pkgs = prev; inherit mach-nix; };
}
