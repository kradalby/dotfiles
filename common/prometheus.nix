{ config, lib, ... }:
{
  services.prometheus.exporters.node = lib.mkIf (!config.boot.isContainer) {
    enable = true;
    enabledCollectors = [ "systemd" ];
    openFirewall = true;
  };

  systemd.services."prometheus-node-exporter".onFailure = [ "notify-email@%n.service" ];
}
