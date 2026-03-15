{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}: let
  versions = import ../../metadata/versions.nix;
in
  buildNpmPackage {
    pname = "homebridge-mqttthing";
    version = versions.pkgs.homebridge.mqttthing; # NOTE: manual update required

    src = fetchFromGitHub {
      owner = "arachnetech";
      repo = "homebridge-mqttthing";
      rev = "ce703ab9765d95a668cc637d83913b77d2705c77"; # Using commit hash as tags don't follow standard format
      hash = "sha256-uC7xeTI4wqEVIgSelTvMyEMHY9Vxyk/3hDGFaKAIY2g=";
    };

    npmDepsHash = "sha256-LyCK7C7991/LZsG7IfFdeLBtLl25PcRfT0kym80+8bU=";

    dontNpmBuild = true; # No build script needed for this plugin

    meta = with lib; {
      description = "Homebridge plugin supporting various services over MQTT";
      homepage = "https://github.com/arachnetech/homebridge-mqttthing";
      license = licenses.asl20;
      maintainers = [];
    };
  }
