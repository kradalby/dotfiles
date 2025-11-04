{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "homebridge-mqttthing";
  version = "1.1.47"; # NOTE: manual update required

  src = fetchFromGitHub {
    owner = "arachnetech";
    repo = "homebridge-mqttthing";
    rev = "v${version}";
    hash = ""; # Run nix build to get the correct hash
  };

  npmDepsHash = ""; # Run: nix-shell -p prefetch-npm-deps --run "prefetch-npm-deps package-lock.json"

  dontNpmBuild = true; # No build script needed for this plugin

  meta = with lib; {
    description = "Homebridge plugin supporting various services over MQTT";
    homepage = "https://github.com/arachnetech/homebridge-mqttthing";
    license = licenses.asl20;
    maintainers = [];
  };
}
