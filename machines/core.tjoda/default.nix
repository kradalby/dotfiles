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
    ../../common/syncthing-storage.nix
    ../../common/tailscale.nix

    ./hardware-configuration.nix
    ./zfs.nix
    ./rest-server.nix
    ./samba.nix
    ./hugin.nix
    ./avahi.nix
    ./restic.nix
    ./restic-jotta.nix
    ./garage.nix
    ./sfiber-check.nix
  ];

  my = {
    lan = "lan0";

    users.storage = true;
    users.timemachine = true;

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
    # No nameservers override: 10.62.0.1 is plain-53 and refuses DoT, so the
    # forced strict DNSOverTLS made DNS work only via tailscaled. Fall back to
    # the Cloudflare DoT default in common/resolved.nix.

    firewall.trustedInterfaces = [
      config.my.lan
      "tailscale0"
    ];
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
  # Disk list lives in metadata/smartctl.nix so the SmartctlDiskMissing alert
  # count on core.oracldn stays in lockstep with what the exporter watches.
  monitoring.smartctl.devices = (import ../../metadata/smartctl.nix).core-tjoda;

  system.stateVersion = "24.11";
}
