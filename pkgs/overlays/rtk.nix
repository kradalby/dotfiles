{
  lib,
  fetchFromGitHub,
  rustPlatform,
  git,
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
      hash = "sha256-aB9SWF9jYHeH3Apz5v4mQptLa6tS9cIfyfo6rHqsD8w=";
    };

    cargoHash = "sha256-0dpZRBPubzd2GuK02/jbNBWOR/TpFM5lVMucEii/JxM=";

    nativeCheckInputs = [git];

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
