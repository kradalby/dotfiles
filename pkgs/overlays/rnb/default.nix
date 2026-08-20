{ buildGoModule }:
buildGoModule {
  pname = "rnb";
  version = "unstable";

  src = ./.;
  vendorHash = "sha256-yqtj+zCo7u2UwaQ12bHCHPNucgQNkvkN7nfkLynB67Y=";

  env.CGO_ENABLED = 0;

  meta = {
    description = "Select on-demand nix remote builders by short name (NIX_CONFIG injector)";
    mainProgram = "rnb";
  };
}
