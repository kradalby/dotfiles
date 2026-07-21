{
  config,
  lib,
  ...
}:
let
  sshKeys = import ../../metadata/ssh.nix;
in
{
  imports = [
    ../../common/base.nix
    ../../profiles/server.nix

    ../../common/tailscale.nix

    ./hardware-configuration.nix
    ./zfs.nix
    ./syncthing.nix # imports common/syncthing-storage.nix + receiveencrypted overrides
    ./restic.nix
  ];

  networking = {
    hostName = "storage";
    domain = "bassan.fap.no";
    hostId = "e13701b2"; # zfs requires a stable hostId
    # DHCP works on the ldn switch now and at bassan later, no reconfig.
    useDHCP = lib.mkForce true;
  };

  my.lan = "enp0s31f6";
  my.users.storage = true; # syncthing runs as the storage user

  # Bare-metal host: no tag:server baseline from incus-vm-ldn.nix, set it here.
  services.tailscale.tags = [
    "tag:server"
    "tag:storage"
    "tag:backup-client"
  ];

  # SMART on the real disks; enables the smartctl exporter from profiles/server.
  monitoring.smartctl.devices = [
    "/dev/sda"
    "/dev/nvme0n1"
  ];

  # First-class tailnet node scraped by core.oracldn as storage-bassan:<port>.
  # node-exporter binds only my.lan and this box won't be on a routed LAN at
  # bassan's, so open each metrics port on tailscale0 explicitly rather than lean
  # on tailscaled's fragile implicit accept rule (same as garnix/ts1p.ldn).
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    config.services.prometheus.exporters.node.port
    config.services.prometheus.exporters.systemd.port
    config.services.prometheus.exporters.zfs.port
    config.services.prometheus.exporters.smartctl.port
  ];

  users.users.root.openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby ++ sshKeys.work;
  users.users.kradalby.openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby ++ sshKeys.work;

  system.stateVersion = "24.05";
}
