{ buildGoModule }:
buildGoModule {
  pname = "rnb";
  version = "unstable";

  src = ./.;
  vendorHash = null; # stdlib only, no external deps

  env.CGO_ENABLED = 0;

  meta = {
    description = "Select on-demand nix remote builders by short name (NIX_CONFIG injector)";
    mainProgram = "rnb";
  };
}
