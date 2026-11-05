{ buildGoModule }:
buildGoModule {
  pname = "rnb";
  version = "unstable";

  src = ./.;
  vendorHash = "sha256-fnPK59vQ7sGXyVzkf08l5dCDBh17q6uAKNeAhXaeGsU=";

  env.CGO_ENABLED = 0;

  meta = {
    description = "Select on-demand nix remote builders by short name (NIX_CONFIG injector)";
    mainProgram = "rnb";
  };
}
