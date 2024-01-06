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
    hostName = "core";
    domain = "ldn.fap.no";

    # Use systemd-networkd for configuration. Forcibly disable legacy DHCP
    # client.
    useNetworkd = true;
    useDHCP = false;

    wireless = {
      enable = true;
      environmentFile = config.age.secrets.kphone15-wifi.path;
      interfaces = ["wan1"];
      networks = {
        kPhone15.psk = "@PSK_KPHONE15@";
      };
    };

    # Use nftables instead.
    nat.enable = false;
    firewall.enable = lib.mkForce false;
  };

  # Use resolved for local DNS lookups, querying through CoreDNS.
  services.resolved = {
    enable = true;
    # TODO: ts domain
    domains = ["bee-velociraptor.ts.net"];
    extraConfig = ''
      DNS=::1 127.0.0.1
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
        "10-lan0" = ethLink "lan0" "dc:a6:32:a8:e6:6b";

        "15-wan1" = {
          matchConfig = {
            Type = "wlan";
            MACAddress = "00:c0:ca:32:98:7f";
          };
          linkConfig = {
            Name = "wan1";
          };
        };
      };

      netdevs = {
        "15-wan0" = vlanNetdev "wan0" 3;
        "25-iot0" = vlanNetdev "iot0" 156;
      };

      networks = {
        # Loopback.
        "5-lo" = {
          matchConfig.Name = "lo";
          routes = [
            {
              # We own the ULA /48, create a blanket unreachable route which will be
              # superseded by more specific /64s.
              routeConfig = {
                Destination = "fd9e:1a04:f01d::/48";
                Type = "unreachable";
              };
            }
          ];
        };

        "10-lan0" = {
          matchConfig.Name = "lan0";

          address = ["10.65.0.1/24"];

          # VLANs associated with this physical interface.
          vlan = ["wan0" "iot0"];

          networkConfig = {
            DHCPPrefixDelegation = true;
            DHCPServer = false;
            IPv6AcceptRA = false;
          };
        };

        "15-wan0" = {
          matchConfig.Name = "wan0";
          networkConfig.DHCP = "no";
          networkConfig.Address = "192.168.2.2/24";

          routes = [
            {
              routeConfig = {
                Gateway = "192.168.2.254";

                Metric = 300;
              };
            }
          ];
        };

        "15-wan1" = {
          matchConfig.Name = "wan1";
          networkConfig.DHCP = "yes";

          dhcpV4Config = {
            UseDNS = false;
            UseDomains = false;

            # Don't release IPv4 address on restart/reboots to avoid churn.
            SendRelease = false;

            # Prioritise WLAN (kPhone) when available IPv4.
            RouteMetric = 100;
          };
        };

        "25-iot0" = {
          matchConfig.Name = "iot0";
          address = [
            "fd9e:1a04:f01d:156::1/64"
            "fe80::1/64"
            "192.168.156.1/24"
          ];
          networkConfig = {
            DHCPPrefixDelegation = true;
            DHCPServer = false;
            IPv6AcceptRA = false;
          };
        };
      };
    };

    # Tailscale readiness and DNS tweaks.
    network.wait-online.ignoredInterfaces = ["tailscale0"];
    services.tailscaled.after = ["network-online.target" "systemd-resolved.service"];
  };
}
