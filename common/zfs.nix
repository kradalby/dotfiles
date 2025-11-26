{
  config,
  lib,
  ...
}: {
  # Enable ZFS exporter
  services.prometheus.exporters.zfs = {
    enable = true;
  };

  # Open firewall for ZFS exporter on LAN interface
  networking.firewall.interfaces."${config.my.lan}".allowedTCPPorts = [
    config.services.prometheus.exporters.zfs.port
  ];
}
