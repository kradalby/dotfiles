{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "homebridge-xiaomi-roborock-vacuum";
  version = "1.0.0-alpha.1"; # NOTE: manual update required

  src = fetchFromGitHub {
    owner = "homebridge-xiaomi-roborock-vacuum";
    repo = "homebridge-xiaomi-roborock-vacuum";
    rev = "v${version}";
    hash = ""; # Run nix build to get the correct hash
  };

  npmDepsHash = ""; # Run: nix-shell -p prefetch-npm-deps --run "prefetch-npm-deps package-lock.json"

  # This plugin has a TypeScript build step
  npmBuildScript = "build";

  meta = with lib; {
    description = "Xiaomi Vacuum Cleaner plugin for Homebridge";
    homepage = "https://github.com/homebridge-xiaomi-roborock-vacuum/homebridge-xiaomi-roborock-vacuum";
    license = licenses.mit;
    maintainers = [];
  };
}
