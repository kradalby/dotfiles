{ buildGoModule }:
buildGoModule {
  pname = "rnb";
  version = "unstable";

  src = ./.;
  vendorHash = "sha256-qpdleQNbcjU1ZJoEAdRcMjXGXSVjMtsk7i/CyS/VVAg=";

  env.CGO_ENABLED = 0;

  meta = {
    description = "Select on-demand nix remote builders by short name (NIX_CONFIG injector)";
    mainProgram = "rnb";
  };
}
