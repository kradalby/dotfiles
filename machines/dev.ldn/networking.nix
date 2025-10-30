{
  lib,
  config,
  ...
}: let
  ethLink = name: (mac: {
    matchConfig = {
      Type = "ether";
      MACAddress = mac;
    };
    linkConfig = {
      Name = name;

      # Hardware tuning. Note that wan0/wan1/mgmt0 all happen to support a max
      # of 4096 since the NixOS option won't allow "max".
      RxBufferSize = 4096;
      TxBufferSize = 4096;
    };
  });

  vlanNetdev = name: (id: {
    netdevConfig = {
      Name = name;
      Kind = "vlan";
    };
    vlanConfig.Id = id;
  });
in {
  age.secrets.kphone15-wifi = {
    file = ../../secrets/kphone15-wifi.age;
  };

  networking = {
    hostId = "58808be0";
    hostName = "dev";
    domain = "ldn.fap.no";

    # Use systemd-networkd for configuration. Forcibly disable legacy DHCP
    # client.
    useNetworkd = true;
    useDHCP = false;

    # Disabled - no longer acting as router with WAN interfaces
    # wireless = {
    #   enable = true;
    #   secretsFile = config.age.secrets.kphone15-wifi.path;
    #   interfaces = ["wan1"];
    #   networks = {
    #     kPhone15.pskRaw = "ext:kphone15";
    #   };
    # };

    # Standard firewall enabled (faptables disabled)
    # NAT for MicroVM network (192.168.130.0/24) through LAN IP
    nat = {
      enable = true;
      externalInterface = "lanbr0";
      internalInterfaces = ["microvm-br0"];
    };
    firewall.enable = true;
  };

  # Use resolved for DNS lookups, querying through gateway
  services.resolved = {
    enable = true;
    domains = ["dalby.ts.net"];
    extraConfig = ''
      DNS=10.65.0.1
      DNSStubListener=no
    '';
  };

  systemd = {
    # Manage network configuration with networkd.
    network = {
      enable = true;

      config.networkConfig.SpeedMeter = "yes";

      links = {
        # Physical LAN. For physical LANs, we have to make sure to match
        # on both Type and MACAddress since VLANs would share the same MAC.
        "10-lan0" = ethLink "lan0" "48:21:0b:52:0b:9f";
        "10-lan1" = ethLink "lan1" "48:21:0b:52:0b:a0";

        # "14-wan0" = ethLink "wan0" "48:21:0b:52:0b:a0";
        "15-wan1" = {
          matchConfig = {
            Type = "wlan";
            MACAddress = "28:6b:35:88:11:93";
          };
          linkConfig = {
            Name = "wan1";
          };
        };
      };

      netdevs = {
        # Disabled - no longer acting as router
        # "15-wan0" = vlanNetdev "wan0" 3;
        # "25-iot0" = vlanNetdev "iot0" 156;

        # Bridge for VMs and physical LAN
        "20-lanbr0" = {
          netdevConfig = {
            Kind = "bridge";
            Name = "lanbr0";
          };
        };
      };

      networks = {
        # Loopback.
        "5-lo" = {
          matchConfig.Name = "lo";
          routes = [
            {
              # We own the ULA /48, create a blanket unreachable route which will be
              # superseded by more specific /64s.
              Destination = "fd9e:1a04:f01d::/48";
              Type = "unreachable";
            }
          ];
        };

        "10-lan0" = {
          matchConfig.Name = "lan0";

          # No VLANs, just bridge for VMs
          # vlan = [];

          linkConfig.RequiredForOnline = "enslaved";
          networkConfig.Bridge = "lanbr0";
        };

        "10-lan1" = {
          matchConfig.Name = "lan1";

          linkConfig.RequiredForOnline = "enslaved";
          networkConfig.Bridge = "lanbr0";
        };

        "11-lanbr0" = {
          matchConfig.Name = "lanbr0";

          address = [
            "10.65.0.24/24"
            "192.168.1.24/24"
          ];

          bridgeConfig = {};
          networkConfig = {
            DHCP = "no";
            DHCPServer = false;
            IPv6AcceptRA = false;
          };

          routes = [
            {
              Gateway = "10.65.0.1";
              GatewayOnLink = true;
            }
          ];

          linkConfig = {
            RequiredForOnline = "routable";
          };
        };

        # Disabled - no longer acting as router
        # "15-wan0" = {
        #   matchConfig.Name = "wan0";
        #   networkConfig.DHCP = "no";
        #   networkConfig.Address = "192.168.2.2/24";
        #   routes = [
        #     {
        #       Gateway = "192.168.2.254";
        #       Metric = 300;
        #     }
        #   ];
        # };

        # "15-wan1" = {
        #   matchConfig.Name = "wan1";
        #   networkConfig.DHCP = "yes";
        #   dhcpV4Config = {
        #     UseDNS = false;
        #     UseDomains = false;
        #     SendRelease = false;
        #     RouteMetric = 100;
        #   };
        # };

        # "25-iot0" = {
        #   matchConfig.Name = "iot0";
        #   address = [
        #     "fd9e:1a04:f01d:156::1/64"
        #     "fe80::1/64"
        #     "192.168.156.1/24"
        #   ];
        #   networkConfig = {
        #     DHCPPrefixDelegation = true;
        #     DHCPServer = false;
        #     IPv6AcceptRA = false;
        #   };
        # };
      };
    };

    # Tailscale readiness and DNS tweaks.
    # Ignore microvm-br0 as it's a virtual bridge that may not have immediate connectivity
    network.wait-online.ignoredInterfaces = ["tailscale0" "wg0" "microvm-br0"];
    services.tailscaled.after = ["network-online.target" "systemd-resolved.service"];
    services.tailscaled.wants = ["network-online.target"];
  };
}
