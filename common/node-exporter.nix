{
  config,
  lib,
  ...
}: let
  consul = import ./funcs/consul.nix {inherit lib;};
in {
  services.prometheus.exporters.node = lib.mkIf (!config.boot.isContainer) {
    enable = true;
    enabledCollectors = ["systemd"];
  };

  networking.firewall.interfaces."${config.my.lan}".allowedTCPPorts = [config.services.prometheus.exporters.node.port];

  systemd.services."prometheus-node-exporter".onFailure = ["notify-discord@%n.service"];

  my.consulServices.node_exporter = consul.prometheusExporter "node" config.services.prometheus.exporters.node.port;
}
