{ config, ... }:
{
  # Stable name keyed on the MAC, so config never depends on kernel probe order.
  my.wan = "wan0";

  systemd.network.links."10-wan0" = {
    matchConfig = {
      Type = "ether";
      # TODO(install): the cabled port's MAC.
      MACAddress = "00:00:00:00:00:00";
    };
    linkConfig.Name = "wan0";
  };

  networking = {
    useNetworkd = true;
    nftables.enable = true;

    # Public IP: keep SSH off the open internet. tailscale (--ssh) reaches us
    # over tailscale0; only these three sources get port 22 on the WAN.
    #   217.120.73.18 isc, 77.164.248.136 ldn, 51.174.163.104 core.tjoda (ddns)
    firewall = {
      enable = true;
      trustedInterfaces = [ "tailscale0" ];
      extraInputRules = ''
        ip saddr { 217.120.73.18, 77.164.248.136, 51.174.163.104 } tcp dport 22 accept
      '';
    };

    # Gigahost also assigned 185.243.216.96/24 and
    # 2a03:94e0:ffff:185:243:216::96/118 (same gateways). Unused; kept here
    # for a service that needs its own address.
    interfaces.${config.my.wan} = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "185.243.216.95";
          prefixLength = 24;
        }
      ];
    };

    defaultGateway = {
      address = "185.243.216.1";
      interface = config.my.wan;
    };
    defaultGateway6 = {
      address = "2a03:94e0:ffff:185:243:216::1";
      interface = config.my.wan;
    };

    # Provider gave no nameserver.
    nameservers = [
      "1.1.1.1"
      "2606:4700:4700::1111"
    ];
  };

  # Everything we source or publish comes from the routed 2a03:94e0:200d::/48.
  # The shared ffff:: transit address may carry other tenants' reputation, so
  # it is deprecated: next hop and inbound only.
  systemd.network.networks."40-${config.my.wan}".addresses = [
    { Address = "2a03:94e0:200d::1/128"; }
    {
      Address = "2a03:94e0:ffff:185:243:216::95/118";
      PreferredLifetime = "0";
    }
  ];
}
