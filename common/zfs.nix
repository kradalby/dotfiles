{
  config,
  lib,
  ...
}:
{
  # Keep force-import (26.11 flips the default to false): these are remote boxes,
  # so a root pool that won't import after an unclean shutdown means an unbootable
  # machine needing console recovery — worse here than the data-loss risk.
  boot.zfs.forceImportRoot = true;

  # Enable ZFS exporter
  services.prometheus.exporters.zfs = {
    enable = true;
  };

  # Open firewall for ZFS exporter on LAN interface
  networking.firewall.interfaces."${config.my.lan}".allowedTCPPorts = [
    config.services.prometheus.exporters.zfs.port
  ];
}
