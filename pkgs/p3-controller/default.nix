{
  lib,
  buildGoModule,
}:
buildGoModule {
  pname = "p3-controller";
  version = "0.1.0";

  src = ./.;

  vendorHash = "sha256-Rm4TC4GauVPH2dz0oz69n8v5IWWry3vs5jcsAtY/kN4=";

  env.CGO_ENABLED = 0;

  meta = {
    description = "HTTP controller for OwnTone radio playback with schedule-based speaker selection";
    license = lib.licenses.mit;
    mainProgram = "p3-controller";
  };
}
