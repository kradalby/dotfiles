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

  # Only open on the LAN if there is one; LAN-less hosts (public boxes reached
  # over tailscale) leave my.lan unset and an empty iifname is an invalid rule.
  networking.firewall.interfaces = lib.mkIf (config.my.lan != "") {
    "${config.my.lan}".allowedTCPPorts = [config.services.prometheus.exporters.node.port];
  };
}
