{
  src,
  version,
  lib,
  importNpmLock,
  rustPlatform,
  pkg-config,
  openssl,
  nodejs,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "cook-cli";
  inherit src version;

  # Deps from the pinned Cargo.lock: a version bump needs no hash.
  cargoLock.lockFile = "${src}/Cargo.lock";

  # Build without the self-updating feature. Dropping the defaults wholesale
  # also drops `server`, which upstream feature-gated after 0.22.0 — that
  # silently removed `cook server` in the 0.33.1 bump. Re-list the rest.
  buildNoDefaultFeatures = true;
  # modules/cook-server.nix is the only consumer and only runs `cook server`,
  # so sync/import/lsp stay off.
  buildFeatures = [ "server" ];

  nativeBuildInputs = [
    pkg-config
    openssl
    nodejs
    importNpmLock.npmConfigHook
  ];

  buildInputs = [ openssl ];

  env.OPENSSL_NO_VENDOR = 1;

  npmDeps = importNpmLock { npmRoot = src; };

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
