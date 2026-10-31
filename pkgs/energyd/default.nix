{
  lib,
  buildGoModule,
  runCommand,
}:
buildGoModule (finalAttrs: {
  pname = "energyd";
  version = "0.1.0";

  src = ./.;

  vendorHash = "sha256-y7UjHjv1ePztikhPcSHfvmt0gbAOZmSVU1JG5W6L60k=";

  env.CGO_ENABLED = 0;

  # Build() validates the model, so a broken dashboard fails this derivation
  # rather than shipping.
  passthru.grafanaDashboards = runCommand "energyd-grafana-dashboards" { } ''
    mkdir -p $out
    ${finalAttrs.finalPackage}/bin/dashboard > $out/leiden.json
  '';

  meta = {
    description = "Ledger of what energy costs this home, from NextEnergy, day-ahead prices and the P1 meter";
    license = lib.licenses.mit;
    mainProgram = "energyd";
  };
})
