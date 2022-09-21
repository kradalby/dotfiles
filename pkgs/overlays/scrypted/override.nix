{
  pkgs,
  system,
}: let
  nodePackages = import ./default.nix {
    inherit pkgs system;
  };
in
  nodePackages
  // {
    "wrtc" = nodePackages."wrtc".override {
      buildInputs = [pkgs.nodePackages.node-gyp-build pkgs.gcc];
    };
    "@scrypted/server" = nodePackages."@scrypted/server".override {
      buildInputs = [pkgs.leveldb pkgs.nodePackages.node-gyp-build];
    };
    "@scrypted/ffmpeg" = nodePackages."@scrypted/ffmpeg".override {
      buildInputs = [pkgs.ffmpeg pkgs.nodePackages.node-gyp-build];
    };
  }
