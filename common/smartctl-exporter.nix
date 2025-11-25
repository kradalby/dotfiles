{
  config,
  lib,
  ...
}:
with lib; {
  options = {
    monitoring.smartctl.devices = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of disks to monitor";
    };
  };

  config = mkIf (builtins.length config.monitoring.smartctl.devices > 0) {
    services.prometheus.exporters.smartctl = {
      enable = true;

      user = "smartctl-exporter";
      group = "disk";
      devices = config.monitoring.smartctl.devices;
    };

    networking.firewall.allowedTCPPorts =
      lib.mkIf config.networking.firewall.enable
      [config.services.prometheus.exporters.smartctl.port];
  };
}
