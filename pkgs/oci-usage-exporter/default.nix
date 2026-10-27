{
  lib,
  buildGoModule,
}:
buildGoModule {
  pname = "oci-usage-exporter";
  version = "0.1.0";

  src = ./.;

  vendorHash = "sha256-dXicTZrZTY8+jAfk2RdkB2ADeLSxH1Jzg42LyELCHak=";

  env.CGO_ENABLED = 0;

  meta = {
    description = "Prometheus exporter for current-month Oracle Cloud spend";
    license = lib.licenses.mit;
    mainProgram = "oci-usage-exporter";
  };
}
