{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
{
  options = {
    monitoring.smartctl.devices = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of disks to monitor";
    };
  };

  config = mkIf (builtins.length config.monitoring.smartctl.devices > 0) {
    environment.systemPackages = [ pkgs.smartmontools ];

    services.prometheus.exporters.smartctl = {
      enable = true;

      user = "smartctl-exporter";
      group = "disk";
      devices = config.monitoring.smartctl.devices;
    };

    # Tailnet-only scrape: tailscale0-scoped, not a global open (services.md).
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      config.services.prometheus.exporters.smartctl.port
    ];
  };
}
