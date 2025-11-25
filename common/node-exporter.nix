{
  config,
  lib,
  ...
}: {
  services.prometheus.exporters.node = lib.mkIf (!config.boot.isContainer) {
    enable = true;
    enabledCollectors = ["systemd"];
  };

  networking.firewall.interfaces."${config.my.lan}".allowedTCPPorts = [config.services.prometheus.exporters.node.port];
}
