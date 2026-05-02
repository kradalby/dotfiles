{
  lib,
  buildGoModule,
}:
buildGoModule {
  pname = "p3-controller";
  version = "0.1.0";

  src = ./.;

  vendorHash = "sha256-IqLiZ/LgwOch1W/VPKtnuEHNfVsyI6IkJR9RyJHwCn0=";

  env.CGO_ENABLED = 0;

  meta = {
    description = "HTTP controller for OwnTone radio playback with schedule-based speaker selection";
    license = lib.licenses.mit;
    mainProgram = "p3-controller";
  };
}
