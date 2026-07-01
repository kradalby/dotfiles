{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../../common/base.nix
    ../../profiles/server.nix
    ../../common/tailscale.nix # primary kradalby tailnet + headscale.kradalby.no

    ./hardware-configuration.nix
    ./networking.nix # wan0 + static public IP + base firewall (shared with the installer)
    ./incus.nix # VM host
    ./cache.nix # tsnixcache binary cache
    ./web.nix # nginx TLS terminator + ACME (local + VM services)
    ./builder.nix # remote nix builder for the garnix VM
  ];

  networking.hostName = "gigabuilder";
  networking.domain = "fap.no";

  # ZFS essentials (rpool root). hostId is mandatory for ZFS; this value is
  # arbitrary but must stay stable.
  boot.supportedFilesystems = ["zfs"];
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10; # cap generations in /boot
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostId = "8425e349";
  services.zfs.autoScrub.enable = true;

  # Cap ZFS ARC. Default is 50% RAM (32 GiB) — too greedy on a VM host. ARC is an
  # evictable read cache, so this is a tunable ceiling, not a reservation: raise
  # if cache read latency matters, lower if VMs get squeezed.
  boot.kernelParams = ["zfs.zfs_arc_max=8589934592"]; # 8 GiB

  # Same tailscale profiles as dev.ldn: common/tailscale.nix already provides the
  # primary kradalby tailnet + headscale.kradalby.no; add the third instance,
  # headscale.sandefjordfiber.no (userspace, no TUN conflict). The secret is
  # declared here and reused by cache.nix's sfiber tsnet.
  age.secrets.headscale-sfiber-client-preauthkey.file =
    ../../secrets/headscale-sfiber-client-preauthkey.age;
  services.tailscales.sfiber = {
    enable = true;
    authKeyFile = config.age.secrets.headscale-sfiber-client-preauthkey.path;
    extraUpFlags = ["--login-server=https://headscale.sandefjordfiber.no"];
    extraSetFlags = ["--hostname=gigabuilder"];
  };

  # Advertise the VM subnet onto the tailnet; tag the node.
  services.tailscale.advertiseRoutes = ["10.68.0.0/16"];
  services.tailscale.tags = ["tag:server" "tag:builder" "tag:incus"];

  # Host-only firewall additions (merged with networking.nix). The VM bridge is
  # the trusted "local network"; allow tailscale direct connections through the
  # public IP (otherwise traffic relays via DERP).
  networking.firewall.trustedInterfaces = ["incusbr0"];
  networking.firewall.allowedUDPPorts = [41641];

  monitoring.smartctl.devices = ["/dev/nvme0n1" "/dev/nvme1n1"];

  system.stateVersion = "25.11";
}
