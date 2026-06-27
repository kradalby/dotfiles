{
  buildGoModule,
  go_1_26,
}:
(buildGoModule.override {go = go_1_26;}) {
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
