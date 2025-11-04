{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  ffmpeg,
}:

buildNpmPackage rec {
  pname = "homebridge-camera-ffmpeg";
  version = "3.1.4"; # NOTE: manual update required

  src = fetchFromGitHub {
    owner = "Sunoo";
    repo = "homebridge-camera-ffmpeg";
    rev = "v${version}";
    hash = ""; # Run nix build to get the correct hash
  };

  npmDepsHash = ""; # Run: nix-shell -p prefetch-npm-deps --run "prefetch-npm-deps package-lock.json"

  # This plugin has a TypeScript build step
  npmBuildScript = "build";

  # Make ffmpeg available at runtime
  buildInputs = [ffmpeg];

  meta = with lib; {
    description = "Homebridge Plugin Providing FFmpeg-based Camera Support";
    homepage = "https://github.com/Sunoo/homebridge-camera-ffmpeg";
    license = licenses.isc;
    maintainers = [];
  };
}
