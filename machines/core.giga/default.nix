{ ... }:
{
  imports = [
    ../../common/base.nix
    ../../profiles/server.nix
    ../../common/tailscale.nix
    ../../common/zfs.nix

    ./hardware-configuration.nix
    ./disko.nix
    ./networking.nix
  ];

  networking.hostName = "core";
  networking.domain = "giga.fap.no";

  # hostId is mandatory for ZFS and must stay stable.
  networking.hostId = "0a92bad1";
  boot.supportedFilesystems = [ "zfs" ];
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  services.zfs.autoScrub.enable = true;

  services.tailscale.tags = [
    # services.restic.jobs.jotta needs svc:restic-jotta, which tag:server is
    # explicitly denied; only tag:backup-client is granted it.
    "tag:backup-client"
    "tag:server"
  ];

  # Open 41641 so tailscale connects directly, not via DERP.
  networking.firewall.allowedUDPPorts = [ 41641 ];

  # TODO(install): add the disks to metadata/smartctl.nix and set
  # monitoring.smartctl.devices from it.

  system.stateVersion = "26.05";
}
