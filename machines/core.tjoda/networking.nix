{lib, ...}: let
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
  networking = {
    hostName = "core";
    domain = "tjoda.fap.no";
    hostId = "14889c5c";

    # Use systemd-networkd for configuration. Forcibly disable legacy DHCP
    # client.
    useNetworkd = true;
    useDHCP = false;

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

  # Manage network configuration with networkd.
  systemd.network = {
    enable = true;

    config.networkConfig.SpeedMeter = "yes";

    # Loopback.
    networks."5-lo" = {
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

    # Wired WAN: Spectrum 1GbE.
    links."10-wan0" = ethLink "wan0" "00:26:55:e3:5d:82";
    networks."10-wan0" = {
      matchConfig.Name = "wan0";
      networkConfig.DHCP = "yes";
      # Never accept ISP DNS or search domains for any DHCP/RA family.
      dhcpV4Config = {
        UseDNS = false;
        UseDomains = false;

        # Don't release IPv4 address on restart/reboots to avoid churn.
        SendRelease = false;

        # Prioritise Altibox IPv4.
        RouteMetric = 100;
      };
      dhcpV6Config = {
        # TODO Fix altibox ipv6
        # Spectrum gives a /56.
        PrefixDelegationHint = "::/56";

        UseDNS = false;
      };
      ipv6AcceptRAConfig = {
        UseDNS = false;
        UseDomains = false;
      };
    };

    # Physical LAN. For physical LANs, we have to make sure to match
    # on both Type and MACAddress since VLANs would share the same MAC.
    links."15-lan0" = ethLink "lan0" "00:26:55:e3:5d:83";
    networks."15-lan0" = {
      matchConfig.Name = "lan0";

      address = ["fd9e:1a04:f01d::1/64" "fe80::1/64" "10.62.0.1/24"];

      # VLANs associated with this physical interface.
      vlan = ["selskap0"];

      networkConfig = {
        DHCPPrefixDelegation = true;
        DHCPServer = false;
        IPv6AcceptRA = false;
      };
    };

    # Unused Ethernet and SFP+ links.
    links."15-eth2" = ethLink "eth2" "30:85:a9:40:0f:0b";

    # Selskap VLAN.
    netdevs."25-selskap0" = vlanNetdev "selskap0" 324;
    networks."25-selskap0" = {
      matchConfig.Name = "selskap0";
      address = [
        "fd9e:1a04:f01d:200::1/64"
        "fe80::1/64"
        "192.168.200.1/24"
      ];
      networkConfig = {
        DHCPPrefixDelegation = true;
        DHCPServer = false;
        IPv6AcceptRA = false;
      };
    };
  };

  # Tailscale readiness and DNS tweaks.
  systemd.network.wait-online.ignoredInterfaces = ["tailscale0"];
  systemd.services.tailscaled.after = ["network-online.target" "systemd-resolved.service"];
}
