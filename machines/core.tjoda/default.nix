{
  config,
  pkgs,
  lib,
  ...
}: {
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
    ./minio.nix
    ./pictures.nix
  ];

  # TODO: Figure a way to allowlist some URLs
  services.blocklist-downloader.enable = lib.mkForce false;

  my = {
    lan = "lan0";

    users.storage = true;
    users.timemachine = true;

    coredns.bind = ["10.62.0.2"];
    ddns = {
      enable = true;
      domains = ["tjoda.fap.no"];
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
    nameservers = ["10.62.0.1"];
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
    advertiseRoutes = ["10.62.0.0/16"];
    tags = ["tag:tjoda" "tag:gateway" "tag:server"];
  };

  age.secrets.headscale-sfiber-authkey = {
    file = ../../secrets/headscale-sfiber-client-preauthkey.age;
    owner = config.users.users.tailscale-proxy.name;
  };

  monitoring.smartctl.devices = ["/dev/sda" "/dev/sdd" "/dev/sde"];

  system.stateVersion = "24.11";
}
