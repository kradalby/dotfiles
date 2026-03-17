{
  config,
  lib,
  ...
}: {
  # Note: systemd metrics are collected by the dedicated systemd_exporter
  # (common/systemd-exporter.nix) which provides richer timer/start-time data.
  services.prometheus.exporters.node = lib.mkIf (!config.boot.isContainer) {
    enable = true;
  };

  networking.firewall.interfaces."${config.my.lan}".allowedTCPPorts = [config.services.prometheus.exporters.node.port];
}
