{
  lib,
  buildGoModule,
}:
buildGoModule {
  pname = "nix-push";
  version = "0.1.0";

  src = ./.;

  vendorHash = null;

  env.CGO_ENABLED = 0;

  meta = {
    description = "Push nix store paths to a remote cache";
    license = lib.licenses.mit;
    mainProgram = "nix-push";
  };
}
