final: prev: {
  golines = prev.callPackage ./golines.nix {
    buildGoModule = prev.buildGo117Module;
  };
  headscale = prev.callPackage ./headscale.nix {
    buildGoModule = prev.buildGo117Module;
  };
}
