{ pkgs, self }:
let
  command =
    self.nixosConfigurations.garnix.config.systemd.services.opensearch-log-retention.serviceConfig.ExecStart;
  policy = pkgs.lib.last (pkgs.lib.splitString " " command);
in
pkgs.runCommand "opensearch-log-retention-test" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  python3 ${./test.py} ${../../machines/garnix/log-retention.py} ${policy}
  touch $out
''
