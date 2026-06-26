{config, ...}: {
  # eth2 is the primary 10Gbps uplink (the only cabled port). Rename it to a
  # stable name keyed on its MAC so config never depends on kernel probe order.
  my.wan = "wan0";

  # No physical LAN. my.lan stays unset; metrics/internal services are reached
  # over tailscale0 (a trusted interface, see firewall below).

  systemd.network.links."10-wan0" = {
    matchConfig = {
      Type = "ether";
      MACAddress = "f8:f2:1e:9d:3b:bc";
    };
    linkConfig.Name = "wan0";
  };

  networking = {
    # systemd-networkd + nftables from first boot — no iptables, no legacy
    # dhcpcd to migrate off later.
    useNetworkd = true;
    nftables.enable = true;

    # Public IP: keep SSH off the open internet. tailscale (--ssh) reaches us
    # over tailscale0; only these three sources get port 22 on the WAN.
    #   217.120.73.18 isc, 77.164.248.136 ldn, 51.174.163.104 core.tjoda (ddns)
    firewall = {
      enable = true;
      trustedInterfaces = ["tailscale0"];
      extraInputRules = ''
        ip saddr { 217.120.73.18, 77.164.248.136, 51.174.163.104 } tcp dport 22 accept
      '';
    };

    interfaces.${config.my.wan} = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "194.32.107.146";
          prefixLength = 24;
        }
      ];
      ipv6.addresses = [
        {
          address = "2a03:94e0:ffff:194:32:107::146";
          prefixLength = 118;
        }
      ];
    };

    defaultGateway = {
      address = "194.32.107.1";
      interface = config.my.wan;
    };
    defaultGateway6 = {
      address = "2a03:94e0:ffff:194:32:107::1";
      interface = config.my.wan;
    };

    # ponytail: provider gave no nameserver; Cloudflare is the safe default.
    # Swap if they hand you a resolver.
    nameservers = ["1.1.1.1" "2606:4700:4700::1111"];
  };
}
