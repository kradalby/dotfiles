{
  lib,
  buildGoModule,
  runCommand,
}:
buildGoModule (finalAttrs: {
  pname = "dashboards";
  version = "0.1.0";

  src = ./.;

  vendorHash = "sha256-9gf2D29shTMPwyNhG4uDr7OHx0HidkGxKBdPInm+Ezo=";

  env.CGO_ENABLED = 0;

  # Tests check panels against the metrics and fields of the services they chart,
  # because a rename there leaves a panel silently empty here.
  env.ENERGYD_SRC = "${../energyd}";

  # Build() validates each model, so a broken dashboard fails this derivation
  # rather than shipping.
  passthru.grafanaDashboards = runCommand "fleet-grafana-dashboards" { } ''
    mkdir -p $out
    ${finalAttrs.finalPackage}/bin/dashboards -out $out
  '';

  meta = {
    description = "Grafana dashboards that chart several fleet services side by side";
    license = lib.licenses.mit;
    mainProgram = "dashboards";
  };
})
