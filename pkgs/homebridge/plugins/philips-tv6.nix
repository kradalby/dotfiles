{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "homebridge-philips-tv6";
  version = "1.0.7"; # NOTE: manual update required

  src = fetchFromGitHub {
    owner = "98oktay";
    repo = "homebridge-philips-tv6";
    rev = "v${version}";
    hash = ""; # Run nix build to get the correct hash
  };

  npmDepsHash = ""; # Run: nix-shell -p prefetch-npm-deps --run "prefetch-npm-deps package-lock.json"

  dontNpmBuild = true; # No build script needed for this plugin

  meta = with lib; {
    description = "Homebridge Plugin for Philips Android TV API v6+";
    homepage = "https://github.com/98oktay/homebridge-philips-tv6";
    license = licenses.isc;
    maintainers = [];
  };
}
