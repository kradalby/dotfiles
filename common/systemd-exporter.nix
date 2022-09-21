{
  config,
  lib,
  ...
}: let
  consul = import ./funcs/consul.nix {inherit lib;};
in {
  services.prometheus.exporters.systemd = {
    enable = true;
    openFirewall = true;
  };

  systemd.services."prometheus-systemd-exporter".onFailure = ["notify-discord@%n.service"];

  my.consulServices.systemd_exporter = consul.prometheusExporter "systemd" config.services.prometheus.exporters.systemd.port;
}
