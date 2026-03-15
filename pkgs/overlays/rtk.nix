{
  lib,
  fetchFromGitHub,
  rustPlatform,
}: let
  versions = import ../../metadata/versions.nix;
in
  rustPlatform.buildRustPackage {
    pname = "rtk";
    # NOTE: manual update required
    # https://github.com/rtk-ai/rtk/releases
    version = versions.pkgs.overlays.rtk;

    src = fetchFromGitHub {
      owner = "rtk-ai";
      repo = "rtk";
      tag = "v${versions.pkgs.overlays.rtk}";
      hash = "sha256-QGHCa8rO4YBFXdrz78FhWKFxY7DmRxCXM8iYQv4yTYE=";
    };

    cargoHash = "sha256-gNJjtQah7NFSgFVYJftK19dECzDvLCi2E33na2PtKmc=";

    # Tests need a writable $HOME for the SQLite tracking DB
    preCheck = ''
      export HOME=$(mktemp -d)
    '';

    meta = {
      description = "CLI proxy that reduces LLM token consumption by 60-90%";
      homepage = "https://github.com/rtk-ai/rtk";
      license = lib.licenses.mit;
      mainProgram = "rtk";
      platforms = lib.platforms.linux ++ lib.platforms.darwin;
    };
  }
