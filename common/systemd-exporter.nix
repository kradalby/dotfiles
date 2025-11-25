{
  config,
  lib,
  ...
}: {
  services.prometheus.exporters.systemd = {
    enable = true;
  };

  networking.firewall.allowedTCPPorts =
    lib.mkIf config.networking.firewall.enable
    [config.services.prometheus.exporters.systemd.port];
}
