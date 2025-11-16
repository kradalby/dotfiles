# Individual homebridge plugins
# Import this to get access to all available plugins
{callPackage}:

{
  homebridge-mqttthing = callPackage ./homebridge-mqttthing.nix {};
}
