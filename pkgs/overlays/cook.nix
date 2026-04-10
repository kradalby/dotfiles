{
  lib,
  fetchFromGitHub,
  fetchNpmDeps,
  npmHooks,
  rustPlatform,
  pkg-config,
  openssl,
  nodejs,
}: let
  versions = import ../../metadata/versions.nix;
in
  rustPlatform.buildRustPackage (finalAttrs: {
    pname = "cook-cli";
    # NOTE: manual update required
    # https://github.com/cooklang/cookcli/releases
    version = versions.pkgs.overlays.cook;

    src = fetchFromGitHub {
      owner = "cooklang";
      repo = "cookcli";
      rev = "v${finalAttrs.version}";
      hash = "sha256-gC/6GMqCaafVeDEU3VAVu3jOw/+Gkb9sDVHmGvlg36o=";
    };

    cargoHash = "sha256-Aslo7zOqLwloH8UuMXIdk6p7rPksiW03Wqz4eFaDha8=";

    # Build without the self-updating feature
    buildNoDefaultFeatures = true;

    nativeBuildInputs = [
      pkg-config
      openssl
      nodejs
      npmHooks.npmConfigHook
    ];

    buildInputs = [openssl];

    env.OPENSSL_NO_VENDOR = 1;

    npmDeps = fetchNpmDeps {
      inherit (finalAttrs) src;
      hash = "sha256-tBOBa2plgJ0dG5eDD9Yc9YS+Dh6rhBdqU6JiZUjTUY4=";
    };

    preBuild = ''
      npm run build-css
    '';

    meta = {
      changelog = "https://github.com/cooklang/cookcli/releases/tag/v${finalAttrs.version}";
      description = "Suite of tools to create shopping lists and maintain recipes";
      homepage = "https://cooklang.org/";
      license = lib.licenses.mit;
      mainProgram = "cook";
      platforms = lib.platforms.linux ++ lib.platforms.darwin;
    };
  })
