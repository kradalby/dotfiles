{ config, flakes, pkgs, lib, ... }:
{
  imports = [
    ../../common

    ../../common/acme.nix
    ../../common/nginx.nix
    ../../common/consul-server.nix

    ./hardware-configuration.nix
    ./wireguard.nix
    ./tailscale.nix
  ];

  my.wan = "ens33";
  my.lan = "lan";

  environment.systemPackages = with pkgs; [
  ];

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

  networking = {
    hostName = "core";
    domain = "ntnu.fap.no";
    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
    ];
    defaultGateway = "129.241.210.1";
    defaultGateway6 = "2001:700:300:2000::1";
    dhcpcd.enable = false;
    usePredictableInterfaceNames = lib.mkForce true;

    bridges = {
      lan.interfaces = [ "ens34" ];
    };

    interfaces = {
      "${config.my.wan}" = {
        useDHCP = false;
        ipv4.addresses = [
          { address = "129.241.210.106"; prefixLength = 25; }
        ];
        ipv6.addresses = [
          { address = "2001:700:300:2000::106"; prefixLength = 64; }
        ];
      };
      lan = {
        useDHCP = false;
        ipv4.addresses = [
          { address = "10.61.0.1"; prefixLength = 24; }
        ];
      };

    };

    nat = {
      enable = true;
      externalInterface = "${config.my.wan}";
      internalIPs = [ "10.0.0.0/8" ];
      internalInterfaces = [ config.my.lan ];
      forwardPorts = [
        { sourcePort = 64322; destination = "10.61.0.1:22"; proto = "tcp"; }
        { sourcePort = 500; destination = "10.61.0.1:51820"; proto = "udp"; }
        { sourcePort = 4500; destination = "10.61.0.1:51820"; proto = "udp"; }
      ];
    };
  };

  services.dhcpd4 = {
    enable = true;
    interfaces = [ config.my.lan ];
    extraConfig = ''
      option domain-name-servers 1.0.0.1, 1.1.1.1;
      option subnet-mask 255.255.255.0;

      subnet 10.61.0.0 netmask 255.255.255.0 {
        option broadcast-address 10.61.0.255;
        option routers 10.61.0.1;
        interface ${config.my.lan};
        range 10.61.0.200 10.61.0.230;
      }
    '';
  };

  systemd.services.dhcpd4.onFailure = [ "notify-discord@%n.service" ];



  boot.cleanTmpDir = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11";
}
