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

    ./hardware-configuration.nix
    ./zfs.nix
    ./wireguard.nix
    ./tailscale.nix
    # ./corerad.nix
    ./dhcp.nix
    # ./openvpn.nix
    ./syncthing.nix
    ./rest-server.nix
    ./samba.nix
    ./restic.nix
    # ./gh-runner.nix
    ./postfix.nix
    # ./libvirt.nix # TODO(kradalby): Figure out why it breaks coreDNS, binds 53
    ./hugin.nix
    ./postgres.nix
    ./immich.nix
    ./webpage.nix
    ./files.nix

    # ./polar
  ];

  my.wan = "enp4s0f0";
  my.lan = "lan0";

  my.enableSslh = false;

  my.users.storage = true;
  my.users.timemachine = true;

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
    domain = "terra.fap.no";
    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
    ];
    usePredictableInterfaceNames = lib.mkForce true;
    hostId = "0dbe8fc2";

    # TODO: IPv6
    # dhcpcd = {
    #   enable = true;
    #   # Do not remove interface configuration on shutdown.
    #   persistent = true;
    #   allowInterfaces = [config.my.wan];
    #   extraConfig = ''
    #     noipv6rs
    #     interface ${config.my.wan}
    #       ipv6rs
    #       # DHCPv6-PD.
    #       ia_na 0
    #       ia_pd 1/::/56 ${config.my.lan}/0/64 sg elskap/200/64
    #       # IPv4 DHCP ISP settings overrides.
    #       static domain_name_servers=10.65.0.1
    #       static domain_search=
    #       static domain_name=
    #   '';
    # };

    defaultGateway = "185.243.216.1";
    defaultGateway6 = "2a03:94e0:ffff:185:243:216::1";

    bridges = {
      lan0.interfaces = [];
    };

    interfaces = {
      enp4s0f1 = {
        useDHCP = true;
        tempAddress = "disabled";
      };

      enp4s0f0 = {
        ipv4.addresses = [
          {
            address = "185.243.216.95";
            prefixLength = 24;
          }
        ];
        ipv6.addresses = [
          {
            address = "2a03:94e0:ffff:185:243:216::95";
            prefixLength = 118;
          }
        ];

        tempAddress = "disabled";
      };

      ${config.my.lan} = {
        useDHCP = false;
        ipv4.addresses = [
          {
            address = "10.60.0.1";
            prefixLength = 24;
          }
        ];
        tempAddress = "disabled";
      };
    };

    nat = {
      enable = true;
      externalInterface = config.my.wan;
      internalIPs = ["10.0.0.0/8"];
      internalInterfaces = [config.my.lan];
      forwardPorts = [
        {
          sourcePort = 64322;
          destination = "10.60.0.1:22";
          proto = "tcp";
        }
        {
          sourcePort = 500;
          destination = "10.60.0.1:51820";
          proto = "udp";
        }
        {
          sourcePort = 4500;
          destination = "10.60.0.1:51820";
          proto = "udp";
        }
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

      trustedInterfaces = [config.my.lan];
    };
  };

  # TODO: Fix disk monitoring somehow
  # monitoring.smartctl.devices = ["/dev/sdc"];

  boot.cleanTmpDir = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11";
}
