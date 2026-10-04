{
  lib,
  buildGoModule,
  testers,
}:
buildGoModule {
  pname = "p3-controller";
  version = "0.1.0";

  src = ./.;

  vendorHash = "sha256-9iNhI+1rVLXMg03hmSDK77MCw4DvtdjXirEnIHris7o=";

  env.CGO_ENABLED = 0;

  passthru.tests.owntone-restart = testers.runNixOSTest (import ./owntone-restart-test.nix);

  meta = {
    description = "HTTP controller for OwnTone radio playback with schedule-based speaker selection";
    license = lib.licenses.mit;
    mainProgram = "p3-controller";
  };
}
