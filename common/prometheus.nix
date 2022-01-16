{ config, lib, ... }:
{
  services.prometheus.exporters.node = lib.mkIf (!config.boot.isContainer) {
    enable = true;
    enabledCollectors = [ "systemd" ];
  };

  networking.firewall.interfaces."${config.my.lan}".allowedTCPPorts = [ config.services.prometheus.exporters.node.port ];

  systemd.services."prometheus-node-exporter".onFailure = [ "notify-discord@%n.service" ];

  my.consulServices.node_exporter = {
    name = "node-exporter";
    tags = [ "node_exporter" "prometheus" ];
    port = 9100;
    check = {
      name = "node_exporter health check";
      http = "http://localhost:9100/metrics";
      interval = "60s";
      timeout = "1s";
    };
  };
}
