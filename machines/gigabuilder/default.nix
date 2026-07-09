{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../../common/base.nix
    ../../profiles/server.nix
    ../../common/tailscale.nix
    ../../common/zfs.nix # zfs exporter + forceImportRoot (scrub/ARC tuned inline below)

    ./hardware-configuration.nix
    ./networking.nix # wan0 + static public IP + base firewall
    ./incus.nix # VM host
    ./cache.nix # tsnixcache binary cache
    ./web.nix # nginx TLS terminator + ACME
    ./builder.nix # remote nix builder for the garnix VM
  ];

  networking.hostName = "gigabuilder";
  networking.domain = "fap.no";

  # hostId is mandatory for ZFS and must stay stable. The pools use ZFS 2.4
  # feature flags, so pinning nixpkgs below 26.05 makes the root pool unimportable
  # and the box unbootable (recover via installer + `zpool import -f rpool`).
  networking.hostId = "8425e349";
  boot.supportedFilesystems = ["zfs"];
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  services.zfs.autoScrub.enable = true;
  # Cap ZFS ARC (default 50% RAM is too greedy on a VM host). Evictable read
  # cache, so a ceiling not a reservation — tune if VMs get squeezed.
  boot.kernelParams = ["zfs.zfs_arc_max=8589934592"]; # 8 GiB

  # Third tailnet on top of common/tailscale.nix: the sfiber headscale
  # (userspace, no TUN conflict). cache.nix's sfiber tsnet reuses this secret.
  age.secrets.headscale-sfiber-client-preauthkey.file =
    ../../secrets/headscale-sfiber-client-preauthkey.age;
  services.tailscales.sfiber = {
    enable = true;
    authKeyFile = config.age.secrets.headscale-sfiber-client-preauthkey.path;
    extraUpFlags = ["--login-server=https://headscale.sandefjordfiber.no"];
    extraSetFlags = ["--hostname=gigabuilder"];
  };

  services.tailscale = {
    advertiseRoutes = ["10.68.0.0/16"]; # the VM subnet
    tags = ["tag:server" "tag:builder" "tag:incus"];
  };

  # Trust the VM bridge; open 41641 so tailscale connects directly, not via DERP.
  networking.firewall = {
    trustedInterfaces = ["incusbr0"];
    allowedUDPPorts = [41641];
  };

  monitoring.smartctl.devices = ["/dev/nvme0n1" "/dev/nvme1n1"];

  system.stateVersion = "25.11";
}
