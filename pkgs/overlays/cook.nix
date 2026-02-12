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
      hash = "sha256-zDpyhdXQ1ZlaN2hAi+OrZ4cJR5CsoYd+AcSOQEUXFwQ=";
    };

    cargoHash = "sha256-pe0GU1y6unRozG6XwpWeD8E+fmpWukIIoFCV1hp6VKI=";

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
      hash = "sha256-KnVtLFD//Nq7ilu6bY6zrlLpyrHVmwxxojOzlu7DdLQ=";
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
