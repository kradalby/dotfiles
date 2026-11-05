{
  lib,
  buildGoModule,
  testers,
}:
buildGoModule {
  pname = "p3-controller";
  version = "0.1.0";

  src = ./.;

  vendorHash = "sha256-I7UPYMYWq5U351p9COODCI05MZoPGNd4eMRVJy6uyw0=";

  env.CGO_ENABLED = 0;

  passthru.tests.owntone-restart = testers.runNixOSTest (import ./owntone-restart-test.nix);

  meta = {
    description = "HTTP controller for OwnTone radio playback with schedule-based speaker selection";
    license = lib.licenses.mit;
    mainProgram = "p3-controller";
  };
}
