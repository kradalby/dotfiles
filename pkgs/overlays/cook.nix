{
  lib,
  fetchFromGitHub,
  fetchNpmDeps,
  npmHooks,
  rustPlatform,
  pkg-config,
  openssl,
  nodejs,
}:
let
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
    hash = "sha256-nqPOdJgQhTWLTfQvMAz31xk9DVUzmmXcBbfDFKepKvk=";
  };

  cargoHash = "sha256-xeIwdU1JU8ByYUKpSPW1GKGEX8mqfg+4TgsLS3xVc5U=";

  # Build without the self-updating feature
  buildNoDefaultFeatures = true;

  nativeBuildInputs = [
    pkg-config
    openssl
    nodejs
    npmHooks.npmConfigHook
  ];

  buildInputs = [ openssl ];

  env.OPENSSL_NO_VENDOR = 1;

  npmDeps = fetchNpmDeps {
    inherit (finalAttrs) src;
    hash = "sha256-HbuCSCgEz9FZsb5DJ37twFdxsuin0k4osqb8BP6XEI0=";
  };

  # Neither generated asset is checked in, and the crate's build script fails
  # without both.
  preBuild = ''
    npm run build-css
    npm run build-js
  '';

  # cargo-auditable panics on cookcli's edge_cases_test under the
  # current rustc; skip the test build until upstream is fixed.
  doCheck = false;

  meta = {
    changelog = "https://github.com/cooklang/cookcli/releases/tag/v${finalAttrs.version}";
    description = "Suite of tools to create shopping lists and maintain recipes";
    homepage = "https://cooklang.org/";
    license = lib.licenses.mit;
    mainProgram = "cook";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
