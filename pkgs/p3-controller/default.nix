{
  lib,
  buildGoModule,
}:
buildGoModule {
  pname = "p3-controller";
  version = "0.1.0";

  src = ./.;

  vendorHash = "sha256-/94jv21OSuIsys3bxAElUil25UNYF6NDFzVHdDkZApw=";

  env.CGO_ENABLED = 0;

  meta = {
    description = "HTTP controller for OwnTone radio playback with schedule-based speaker selection";
    license = lib.licenses.mit;
    mainProgram = "p3-controller";
  };
}
