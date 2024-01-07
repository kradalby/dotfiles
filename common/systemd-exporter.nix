{
  config,
  lib,
  ...
}: let
  consul = import ./funcs/consul.nix {inherit lib;};
in {
  services.prometheus.exporters.systemd = {
    enable = true;
  };

  my.consulServices.systemd_exporter = consul.prometheusExporter "systemd" config.services.prometheus.exporters.systemd.port;
  networking.firewall.allowedTCPPorts =
    lib.mkIf config.networking.firewall.enable
    [config.services.prometheus.exporters.systemd.port];
}
