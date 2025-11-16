{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  python3,
  nodejs,
}:

buildNpmPackage rec {
  pname = "homebridge";
  version = "1.8.4";

  src = fetchFromGitHub {
    owner = "homebridge";
    repo = "homebridge";
    rev = "v${version}";
    hash = "sha256-92mfisXSrl8D7taJWgZ+iO6EprJPmINnQgtOQ72YYPI=";
  };

  npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Will be replaced with correct hash from build error

  nativeBuildInputs = [
    python3
  ];

  # Homebridge has a build step
  npmBuildScript = "build";

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
