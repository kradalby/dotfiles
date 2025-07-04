{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../../common

    ../../common/acme.nix
    ../../common/nginx.nix
    ../../common/consul-server.nix
    ../../common/ddns.nix
    ../../common/smokeping-exporter.nix
    ../../common/coredns.nix
    ../../common/miniupnp.nix
    ../../common/syncthing-storage.nix
    ../../common/tailscale.nix

    ./hardware-configuration.nix
    ./zfs.nix
    ./wireguard.nix
    ./tailscale-headscale.nix
    ./rest-server.nix
    ./samba.nix
    ./avahi.nix
    ./restic.nix
    ./minio.nix
    ./redlib.nix
  ];

  # TODO: Figure a way to allowlist some URLs
  services.blocklist-downloader.enable = lib.mkForce false;

  my = {
    wan = "wan0";
    lan = "lan0";

    users.storage = true;
    users.timemachine = true;
  };

  networking = {
    hostName = "core";
    domain = "tjoda.fap.no";
    hostId = "14889c5c";
    nameservers = [
      "10.62.0.1"
    ];
    defaultGateway = "10.62.0.1";
    defaultGateway6 = "";
    dhcpcd.enable = false;
    usePredictableInterfaceNames = lib.mkForce true;
    useDHCP = false;
    interfaces = {
      "eth0" = {
        useDHCP = true;
      };
      "eth2" = {
        useDHCP = false;
        ipv4 = {
          addresses = [
            {
              address = "10.62.0.2";
              prefixLength = 24;
            }
          ];
          routes = [
            {
              address = "10.62.0.1";
              prefixLength = 32;
            }
          ];
        };
      };
    };
  };

  boot.kernel.sysctl = {
    # if you use ipv4, this is all you need
    "net.ipv4.conf.all.forwarding" = true;

    # If you want to use it for ipv6
    "net.ipv6.conf.all.forwarding" = true;
  };

  services.tailscale = let
    wireguardHosts = import ../../metadata/wireguard.nix;
    wireguardConfig = wireguardHosts.servers.tjoda;
  in {
    advertiseRoutes = wireguardConfig.additional_networks;
    tags = ["tag:tjoda" "tag:gateway" "tag:server"];
  };

  monitoring.smartctl.devices = ["/dev/sda"];

  system.stateVersion = "24.11";
}
