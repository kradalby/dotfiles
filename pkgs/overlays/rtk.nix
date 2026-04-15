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
      hash = "sha256-QmjuAFyM4Bgl1ZY4SrWijSuiQvusZ5+9aq4lvLMnUF4=";
    };

    cargoHash = "sha256-rjFaxbvwcwJgxwXDKjpUWI4JFX2xnbf+oxAyS3HolBY=";

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
