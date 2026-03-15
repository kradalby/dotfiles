{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  python3,
  makeWrapper,
}: let
  versions = import ../../metadata/versions.nix;
in
  buildNpmPackage rec {
    pname = "homebridge-config-ui-x";
    version = versions.pkgs.homebridge.configUi;

    src = fetchFromGitHub {
      owner = "homebridge";
      repo = "homebridge-config-ui-x";
      rev = "v${version}";
      hash = "sha256-PJ+dpI4vuT1NbmbqDe5sLXWayCHu1LPjX/SgNxNpKjE=";
    };

    npmDepsHash = "sha256-lENiS4SDxESpHzQrq9uuBWQmdbOpfDls6FKqq/KCp9w=";
    makeCacheWritable = true;
    npmFlags = ["--legacy-peer-deps"];

    nativeBuildInputs = [
      python3
      makeWrapper
    ];

    # Skip UI build - it's complex and not currently used
    # Only build the server component
    npmBuildScript = "build:server";

    # Install the built files
    postInstall = ''
      # Ensure bin directory exists
      mkdir -p $out/bin
    '';

    meta = with lib; {
      description = "Homebridge Config UI X - A web-based management tool for Homebridge";
      longDescription = ''
        Homebridge Config UI X is a web-based management, configuration and control platform
        for Homebridge. It allows you to install, remove and update Homebridge plugins,
        monitor your Homebridge server and view logs.
      '';
      homepage = "https://github.com/homebridge/homebridge-config-ui-x";
      changelog = "https://github.com/homebridge/homebridge-config-ui-x/releases/tag/v${version}";
      license = licenses.mit;
      maintainers = [];
      # node-pty native compilation fails on macOS (openpty undeclared);
      # only deployed on Linux (home.ldn) anyway
      platforms = platforms.linux;
    };
  }
