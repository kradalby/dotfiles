{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}: let
  versions = import ../../../metadata/versions.nix;
in
buildNpmPackage rec {
  pname = "homebridge-mqttthing";
  version = versions.pkgs.homebridge.mqttthing; # NOTE: manual update required

  src = fetchFromGitHub {
    owner = "arachnetech";
    repo = "homebridge-mqttthing";
    rev = "93f81e506c7579f4250c1e0bedcb822a8be517e0"; # Using commit hash as tags don't follow standard format
    hash = "sha256-qlXIuyrygE6nvntSurP8IqCMQUjIhW6X6RdH+Jij1uI=";
  };

  npmDepsHash = "sha256-HxqTAve8I+m8o7DPPAXHJGeWEa26P0olbTszrMvXIME=";

  dontNpmBuild = true; # No build script needed for this plugin

  meta = with lib; {
    description = "Homebridge plugin supporting various services over MQTT";
    homepage = "https://github.com/arachnetech/homebridge-mqttthing";
    license = licenses.asl20;
    maintainers = [];
  };
}
