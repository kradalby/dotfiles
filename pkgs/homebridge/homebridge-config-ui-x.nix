{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  python3,
  nodejs,
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
    hash = "sha256-PV2vkPDYClsRD6u0fZ9CIdjLNkJRaCmbZkxD0PbW4do=";
  };

  npmDepsHash = "sha256-33pbyktTl+g9Hidu84ZkEvjaf6Lyy/tUJsF7ft8g6PE=";

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
    platforms = platforms.linux ++ platforms.darwin;
  };
}
