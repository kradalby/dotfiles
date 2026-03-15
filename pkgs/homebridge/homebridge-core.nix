{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  python3,
  nodejs,
}: let
  versions = import ../../metadata/versions.nix;
in
  buildNpmPackage rec {
    pname = "homebridge";
    version = versions.pkgs.homebridge.core;

    src = fetchFromGitHub {
      owner = "homebridge";
      repo = "homebridge";
      rev = "v${version}";
      hash = "sha256-6w2SDnP7P89j3/oLR77D0ubOzDb93krrRJQsDrhPTR4=";
    };

    npmDepsHash = "sha256-m6ZLwDyWEwll7PYRHREThj+SvkfCNgODrpo8DTk6j8w=";

    nativeBuildInputs = [
      python3
    ];

    # Run tsc directly instead of build script that tries to install rimraf
    buildPhase = ''
      runHook preBuild

      # Run TypeScript compiler directly
      npx tsc

      runHook postBuild
    '';

    # Install the built files
    postInstall = ''
      # Ensure bin directory exists
      mkdir -p $out/bin
    '';

    meta = with lib; {
      description = "HomeKit support for the impatient";
      longDescription = ''
        Homebridge is a lightweight NodeJS server you can run on your home network that
        emulates the iOS HomeKit API. It supports Plugins, which are community-contributed
        modules that provide a basic bridge from HomeKit to various 3rd-party APIs
        provided by manufacturers of "smart home" devices.
      '';
      homepage = "https://homebridge.io";
      changelog = "https://github.com/homebridge/homebridge/releases/tag/v${version}";
      license = licenses.asl20;
      maintainers = [];
      platforms = platforms.linux ++ platforms.darwin;
      mainProgram = "homebridge";
    };
  }
