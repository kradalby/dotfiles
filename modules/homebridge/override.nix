{ pkgs, system }:
let
  nodePackages = import ./default.nix {
    inherit pkgs system;
  };
in
nodePackages // {
  "homebridge" = nodePackages."homebridge-camera-ffmpeg".override {
    buildInputs = [ pkgs.ffmpeg ];
  };
}
