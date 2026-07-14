{ pkgs, ... }:
let
  # SLO/burn-rate alerting via sloth (v0.16.0): the spec in ./slo-spec.nix is
  # compiled to multi-window multi-burn-rate recording+alerting rules at BUILD
  # time and promtool-checked by the prometheus module. page → critical,
  # ticket → warning: both slot into the existing Discord routes. Alert
  # windows top out at 3d — no 30d of history needed before this works; only
  # the error-budget metadata rules take the full window to converge.
  yaml = pkgs.formats.yaml { };

  sloSpec = yaml.generate "homelab-slos.yaml" (import ./slo-spec.nix);

  slothRules = pkgs.runCommand "sloth-rules.yaml" { nativeBuildInputs = [ pkgs.sloth ]; } ''
    sloth generate -i ${sloSpec} -o $out
  '';
in
{
  services.prometheus.ruleFiles = [ slothRules ];
}
