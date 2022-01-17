{ config, lib, ... }:
with lib;
let
  consul = import ./funcs/consul.nix { inherit lib; };
in
{
  options = {
    monitoring.smartctl.devices = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of disks to monitor";
    };
  };

  config = mkIf (builtins.length config.monitoring.smartctl.devices > 0) {
    services.prometheus.exporters.smartctl = {
      enable = true;
      openFirewall = true;

      user = "smartctl-exporter";
      group = "disk";
      devices = config.monitoring.smartctl.devices;

    };

    systemd.services."prometheus-smartctl-exporter".onFailure = [ "notify-discord@%n.service" ];

    my.consulServices.smartctl_exporter = consul.prometheusExporter "smartctl" config.services.prometheus.exporters.smartctl.port;
  };
}
