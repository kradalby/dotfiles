{ pkgs, ... }:
{
  services.prometheus.ruleFiles = [
    (pkgs.writeText "sqlite-backup.rules.json" (builtins.toJSON { groups = [ (import ./rules.nix) ]; }))
  ];
}
