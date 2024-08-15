{
  config,
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
    ../../common/rpi4-configuration.nix
    ../../common/miniupnp.nix

    ./wireguard.nix
    ./tailscale.nix
    ./tailscale-headscale.nix
    ./corerad.nix
    ./dnsmasq.nix
    ./avahi.nix
    ./openvpn.nix
    ./networking.nix
    ./nft.nix
  ];

  # my.wan = "wlan0";
  my.wan = "wan0";
  my.lan = "lan0";

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

  monitoring.smartctl.devices = ["/dev/sda"];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05";
}
