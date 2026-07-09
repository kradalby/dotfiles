{
  pkgs,
  self,
  ...
}: let
  # The exact rules core.oracldn deploys: inline rule groups from its config,
  # plus the sloth burn-rate rules recompiled from the same spec (sloth
  # generate is pure, so this matches the aarch64 build bit-for-bit).
  inlineRules =
    pkgs.writeText "rules.json"
    (builtins.head self.nixosConfigurations.core-oracldn.config.services.prometheus.rules);

  yaml = pkgs.formats.yaml {};
  sloSpec = yaml.generate "homelab-slos.yaml" (import ../../machines/core.oracldn/slo-spec.nix);
  slothRules = pkgs.runCommand "sloth-rules.yaml" {nativeBuildInputs = [pkgs.sloth];} ''
    sloth generate -i ${sloSpec} -o $out
  '';
in
  pkgs.runCommand "prometheus-rule-tests" {nativeBuildInputs = [pkgs.prometheus.cli];} ''
    substitute ${./tests.yaml} tests.yaml \
      --subst-var-by rules ${inlineRules} \
      --subst-var-by sloth ${slothRules}
    promtool check rules ${inlineRules} ${slothRules}
    promtool test rules tests.yaml
    touch $out
  ''
