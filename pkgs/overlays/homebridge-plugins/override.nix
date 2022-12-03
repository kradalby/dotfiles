{
  pkgs,
  system,
}:
let

 nodePackages =  import ./default.nix {
    inherit pkgs system;
  }
    // {
      "homebridge-camera-ffmpeg" = nodePackages."homebridge-camera-ffmpeg".override {
        buildInputs = [pkgs.ffmpeg];
      }
in

  nodePackages;
