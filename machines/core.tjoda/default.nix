{
  config,
  flakes,
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
    ./corerad.nix
    ./dnsmasq.nix
    ./nft.nix
    ./networking.nix
    ./unifi.nix
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

  boot.kernel.sysctl = {
    # if you use ipv4, this is all you need
    "net.ipv4.conf.all.forwarding" = true;

    # If you want to use it for ipv6
    "net.ipv6.conf.all.forwarding" = true;

    # source: https://github.com/mdlayher/homelab/blob/master/nixos/routnerr-2/configuration.nix#L52
    # By default, not automatically configure any IPv6 addresses.
    "net.ipv6.conf.all.accept_ra" = 0;
    "net.ipv6.conf.all.autoconf" = 0;
    "net.ipv6.conf.all.use_tempaddr" = 0;

    # On WAN, allow IPv6 autoconfiguration and tempory address use.
    "net.ipv6.conf.${config.my.wan}.accept_ra" = 2;
    "net.ipv6.conf.${config.my.wan}.autoconf" = 1;
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
