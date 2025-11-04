# Individual homebridge plugins
# Import this to get access to all available plugins
{callPackage}:

{
  homebridge-philips-tv6 = callPackage ./plugins/philips-tv6.nix {};
  homebridge-mqttthing = callPackage ./plugins/mqttthing.nix {};
  homebridge-camera-ffmpeg = callPackage ./plugins/camera-ffmpeg.nix {};
  homebridge-nefit-easy = callPackage ./plugins/nefit-easy.nix {};
  homebridge-xiaomi-roborock-vacuum = callPackage ./plugins/xiaomi-roborock-vacuum.nix {};
}
