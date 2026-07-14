{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../../common/base.nix
    ../../profiles/server.nix
    ../../common/avahi.nix # enable; ./avahi.nix adds the Time Machine records

    ../../common/ddns.nix
    ../../common/smokeping-exporter.nix
    ../../common/coredns.nix
    ../../common/syncthing-storage.nix
    ../../common/tailscale.nix

    ./hardware-configuration.nix
    ./zfs.nix
    ./rest-server.nix
    ./samba.nix
    ./avahi.nix
    ./restic.nix
    ./restic-jotta.nix
    ./minio.nix # burn-in fallback; remove after garage has run clean for a week
    ./garage.nix
    ./sfiber-check.nix
  ];

  # TODO: Figure a way to allowlist some URLs
  services.blocklist-downloader.enable = lib.mkForce false;

  my = {
    lan = "lan0";

    users.storage = true;
    users.timemachine = true;

    coredns.bind = [ "10.62.0.2" ];
    ddns = {
      enable = true;
      domains = [ "tjoda.fap.no" ];
    };
  };

  networking = {
    hostName = "core";
    domain = "tjoda.fap.no";
    hostId = "14889c5c";

    interfaces.${config.my.lan} = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "10.62.0.2";
          prefixLength = 24;
        }
      ];
    };

    defaultGateway = {
      address = "10.62.0.1";
      interface = config.my.lan;
    };
    nameservers = [ "10.62.0.1" ];
  };

  systemd.network = {
    links = {
      "10-lan0" = {
        matchConfig = {
          Type = "ether";
          MACAddress = "30:85:a9:40:0f:0b";
        };
        linkConfig.Name = "lan0";
      };
    };
  };

  boot.kernel.sysctl = {
    # if you use ipv4, this is all you need
    "net.ipv4.conf.all.forwarding" = true;

    # If you want to use it for ipv6
    "net.ipv6.conf.all.forwarding" = true;
  };

  services.tailscale = {
    advertiseRoutes = [ "10.62.0.0/16" ];
    tags = [
      "tag:backup-client"
      "tag:gateway"
      "tag:server"
      "tag:storage"
    ];
  };

  age.secrets.headscale-sfiber-authkey = {
    file = ../../secrets/headscale-sfiber-client-preauthkey.age;
    owner = config.users.users.tailscale-proxy.name;
  };

  # Every physical disk, by stable ID (sdX naming reshuffles across boots;
  # /dev/sda alone left the restic-repo disks without SMART). Live-enumerated
  # 2026-07; the SmartctlDiskMissing alert on core.oracldn pins this count.
  monitoring.smartctl.devices = [
    "/dev/disk/by-id/ata-CT250MX500SSD1_1914E1F7A84D"
    "/dev/disk/by-id/ata-HGST_HUS728T8TALE6L4_VG0D0SZG"
    "/dev/disk/by-id/ata-KINGSTON_SA400S37480G_50026B7785A27E08"
    "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_500GB_S2RBNXAH342406T"
    "/dev/disk/by-id/ata-WDC_WDS200T2B0A-00SM50_23014N802795"
  ];

  system.stateVersion = "24.11";
}
