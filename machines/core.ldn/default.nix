{ config, flakes, pkgs, lib, ... }:
{
  imports = [
    ../../common

    ../../common/acme.nix
    ../../common/nginx.nix
    ../../common/consul-server.nix
    ../../common/ddns.nix
    ../../common/smokeping-exporter.nix
    ../../common/coredns.nix

    ./hardware-configuration.nix
    ./wireguard.nix
    ./tailscale.nix
    ./corerad.nix
    ./dhcp.nix
    ./avahi.nix
  ];

  my.wan = "wan";
  my.lan = "eth0";

  environment.systemPackages = with pkgs; [
  ];

  services.resolved.enable = false;

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
    domain = "ldn.fap.no";
    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
    ];
    usePredictableInterfaceNames = lib.mkForce true;

    dhcpcd = {
      enable = true;
      # Do not remove interface configuration on shutdown.
      persistent = true;
      allowInterfaces = [ config.my.wan ];
      extraConfig = ''
        noipv6rs
        interface ${config.my.wan}
          ipv6rs
          # DHCPv6-PD.
          ia_na 0
          ia_pd 1/::/48 ${config.my.lan}/0/64 iot/156/64
          # IPv4 DHCP ISP settings overrides.
          static domain_name_servers=10.65.0.1
          static domain_search=
          static domain_name=
      '';
    };

    vlans = {
      ${config.my.wan} = {
        interface = config.my.lan;
        id = 3;
      };

      iot = {
        interface = config.my.lan;
        id = 5;
      };
    };

    # bridges = {
    #   lan.interfaces = [ "eth0" "wlan0" ];
    # };

    interfaces = {
      ${config.my.wan} = {
        useDHCP = true;
        tempAddress = "disabled";
      };

      ${config.my.lan} = {
        # It looks like Community Fiber has whitelisted this
        # Mac address somehow, so keep it around incase we
        # need a new machine.
        macAddress = "dc:a6:32:08:d3:e8";

        useDHCP = false;
        ipv4.addresses = [
          { address = "10.65.0.1"; prefixLength = 24; }
        ];
        tempAddress = "disabled";
      };

      iot = {
        useDHCP = false;
        ipv4.addresses = [
          { address = "192.168.156.1"; prefixLength = 24; }
        ];
        tempAddress = "disabled";
      };

    };

    nat = {
      enable = true;
      externalInterface = config.my.wan;
      internalIPs = [ "10.0.0.0/8" "192.168.156.0/24" ];
      internalInterfaces = [ config.my.lan "iot" ];
      forwardPorts = [
        { sourcePort = 64322; destination = "10.65.0.1:22"; proto = "tcp"; }
        { sourcePort = 500; destination = "10.65.0.1:51820"; proto = "udp"; }
        { sourcePort = 4500; destination = "10.65.0.1:51820"; proto = "udp"; }
      ];
    };

    firewall = {
      # This is a special override for gateway machines as we
      # dont want to use "openFirewall" here since it makes
      # everything world available.
      allowedTCPPorts = lib.mkForce [
        80 # HTTP
        443 # HTTPS
      ];

      allowedUDPPorts = lib.mkForce [
        443 # HTTPS
        config.services.tailscale.port
        config.networking.wireguard.interfaces.wg0.listenPort
      ];

      interfaces.eth0.allowedTCPPorts = [
        22 # ssh
        53 # DNS

        # consul
        8300
        8301
        8302
        8600

        # Exporters
        9153 # CoreDNS exporter
        9430 # CoreRAD exporter
        config.services.prometheus.exporters.node.port
        config.services.prometheus.exporters.smartctl.port
        config.services.prometheus.exporters.wireguard.port
        config.services.prometheus.exporters.nginx.port
        config.services.prometheus.exporters.nginxlog.port
        config.services.prometheus.exporters.systemd.port
        config.services.prometheus.exporters.smokeping.port
      ];

      interfaces.eth0.allowedUDPPorts = [
        53 # DNS
        5353 # mDNS

        # consul
        8301
        8302
        8600
      ];

    };
  };

  monitoring.smartctl.devices = [ "/dev/sda" ];

  boot.cleanTmpDir = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11";
}
