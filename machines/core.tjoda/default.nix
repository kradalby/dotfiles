{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../../common

    ../../common/consul-server.nix
    ../../common/ddns.nix
    ../../common/smokeping-exporter.nix
    ../../common/syncthing-storage.nix
    ../../common/tailscale.nix
    ../../modules/microvm-host.nix

    ./microvm.nix
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
    lan = "lan0";

    users.storage = true;
    users.timemachine = true;
  };

  networking = {
    hostName = "core";
    domain = "tjoda.fap.no";
    hostId = "14889c5c";
  };

  systemd.network = {
    enable = true;

    # Ignore virtual interfaces that are not required for system to be online
    wait-online.ignoredInterfaces = ["tailscale0" "wg0" "microvm-br0"];

    links = {
      "10-lan0" = {
        matchConfig = {
          Type = "ether";
          MACAddress = "30:85:a9:40:0f:0b";
        };
        linkConfig.Name = "lan0";
      };
    };

    networks = {
      "10-lan0" = {
        matchConfig.Name = "lan0";
        address = [ "10.62.0.2/24" ];
        gateway = [ "10.62.0.1" ];
        dns = [ "10.62.0.1" ];
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
    wireguardHosts = import ../../metadata/wireguard.nix {inherit lib config;};
    wireguardConfig = wireguardHosts.servers.tjoda;
  in {
    advertiseRoutes = wireguardConfig.additional_networks;
    tags = ["tag:tjoda" "tag:gateway" "tag:server"];
  };

  monitoring.smartctl.devices = ["/dev/sda"];

  # MicroVM networking configuration for core.tjoda
  # Uses systemd-networkd DHCP server (configured in microvm-host.nix)
  # so need standard firewall rules and NAT for internet access
  networking.firewall.allowedUDPPorts = [ 67 ];  # DHCP server
  networking.nat = {
    enable = true;
    enableIPv6 = true;
    internalInterfaces = [ "microvm-br0" ];  # NAT for MicroVM bridge
  };

  system.stateVersion = "24.11";
}
