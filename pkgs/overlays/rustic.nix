{
  lib,
  fetchFromGitHub,
  rustPlatform,
  installShellFiles,
  makeWrapper,
  rclone,
}: let
  versions = import ../../metadata/versions.nix;
in
  rustPlatform.buildRustPackage {
    pname = "rustic";
    # NOTE: manual update required
    # https://github.com/rustic-rs/rustic/releases
    version = versions.pkgs.overlays.rustic;

    src = fetchFromGitHub {
      owner = "rustic-rs";
      repo = "rustic";
      rev = "v${versions.pkgs.overlays.rustic}";
      hash = "sha256-2xSQ+nbP7/GsIWvj9sgG+jgIIIesfEW8T9z5Tijd90E=";
    };

    cargoHash = "sha256-4yiWIlibYldr3qny0KRRIHBqHCx6R9gDiiheGkJrwEY=";

    nativeBuildInputs = [
      installShellFiles
      makeWrapper
    ];

    # No native C deps -- rustic uses rustls (pure Rust TLS)

    postInstall = ''
      wrapProgram $out/bin/rustic \
        --prefix PATH : ${lib.makeBinPath [rclone]}

      installShellCompletion --cmd rustic \
        --bash <($out/bin/rustic completions bash) \
        --fish <($out/bin/rustic completions fish) \
        --zsh <($out/bin/rustic completions zsh)
    '';

    meta = {
      description = "Fast, encrypted, deduplicated backups powered by Rust";
      homepage = "https://github.com/rustic-rs/rustic";
      license = with lib.licenses; [mit asl20];
      mainProgram = "rustic";
      platforms = lib.platforms.linux ++ lib.platforms.darwin;
    };
  }
