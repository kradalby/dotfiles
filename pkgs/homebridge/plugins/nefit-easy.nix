{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "homebridge-nefit-easy";
  version = "2.3.1"; # NOTE: manual update required

  src = fetchFromGitHub {
    owner = "robertklep";
    repo = "homebridge-nefit-easy";
    rev = "v${version}";
    hash = ""; # Run nix build to get the correct hash
  };

  npmDepsHash = ""; # Run: nix-shell -p prefetch-npm-deps --run "prefetch-npm-deps package-lock.json"

  dontNpmBuild = true; # No build script needed for this plugin

  meta = with lib; {
    description = "Homebridge plugin for Nefit Easy™ (aka Worcester Wave™, Junkers Control™)";
    homepage = "https://github.com/robertklep/homebridge-nefit-easy";
    license = licenses.mit;
    maintainers = [];
  };
}
