{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.networking.faptables;

  # Produces a CSV list of interface names.
  mkCSV = lib.concatMapStrings (ifi: "${ifi.name}, ");

  # Port definitions.
  ports = {
    dns = "53";
    dhcp4_server = "67";
    dhcp4_client = "68";
    dhcp6_client = "546";
    dhcp6_server = "547";
    http = "80";
    https = "443";
    mdns = "5353";
    ssh = "22";
    wireguard = "51820";
  };

  icmp_rules = ''
    ip6 nexthdr icmpv6 icmpv6 type {
      echo-request,
      echo-reply,
      destination-unreachable,
      packet-too-big,
      time-exceeded,
      parameter-problem,
      nd-neighbor-solicit,
      nd-neighbor-advert,
    } counter accept

    ip protocol icmp icmp type {
      echo-request,
      echo-reply,
      destination-unreachable,
      time-exceeded,
      parameter-problem,
    } counter accept
  '';
in {
  options.networking.faptables = {
    enable = mkEnableOption "fap tables is a service wrapper around nftables for my routers";

    trace = mkOption {
      type = types.bool;
      default = false;
      description = "Enable tracing in nftables";
    };

    maliciousSubnets = mkOption {
      type = types.listOf types.str;
      default = [
        "49.64.0.0/11"
        "218.92.0.0/16"
        "222.184.0.0/13"
      ];
      description = "Malicious subnets to block";
    };

    wans = mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.str);
      default = [];
      example = [{name = "wan0";}];
      description = "WAN / Internet facing interfaces";
    };

    lan = {
      trusted = mkOption {
        type = lib.types.listOf (lib.types.attrsOf lib.types.str);
        default = [];
        example = [
          {
            name = "lan0";
            ipv4 = "10.62.0.1";
          }
        ];
        description = "Trusted internal networks";
      };
      untrusted = mkOption {
        type = lib.types.listOf (lib.types.attrsOf lib.types.str);
        default = [];
        example = [
          {
            name = "selskap0";
            ipv4 = "192.168.200.1";
            prefix = "192.168.200.0/24";
          }
        ];
        description = "Untrusted internal networks";
      };
    };
  };

  config = mkIf cfg.enable {
    # TODO: drop ipv6 traffic between vlan
    # iifname ${ifi.name} ip6 daddr != {
    #   ${ifi.ipv6.lla},
    #   ${ifi.ipv6.ula},
    # } counter drop comment "${ifi.name} traffic leaving IPv6 VLAN"

    networking.nftables = {
      enable = true;
      ruleset = ''
        table inet filter {
          # Incoming connections to router itself.
          chain input {
            meta nftrace set ${
          if cfg.trace
          then "1"
          else "0"
        }

            type filter hook input priority 0
            policy drop

            ct state {established, related} counter accept
            ct state invalid counter drop

            # Malicious subnets.
            ip saddr {${builtins.concatStringsSep "," cfg.maliciousSubnets}} counter drop comment "malicious subnets"

            # ICMPv4/6.
            ${icmp_rules}

            # Allow all WANs to selectively communicate with the router.
            iifname {
              ${mkCSV cfg.wans}
            } jump input_wan

            # Always allow router solicitation from any LAN.
            ip6 nexthdr icmpv6 icmpv6 type nd-router-solicit counter accept

            # Allow localhost and trusted LANs to communicate with router.
            iifname {
              lo,
              ${mkCSV cfg.lan.trusted}
            } counter accept comment "localhost and trusted LANs to router"

            # Limit the communication abilities of limited and untrusted LANs.
            iifname {
              ${mkCSV cfg.lan.untrusted}
            } jump input_limited_untrusted

            counter reject
          }

          chain input_wan {
            # Default route via NDP.
            ip6 nexthdr icmpv6 icmpv6 type nd-router-advert counter accept

            # router TCP
            tcp dport {
              ${ports.http},
              ${ports.https},
              ${ports.ssh},
            } counter accept comment "router WAN TCP"

            # router UDP
            udp dport {
              ${ports.https},
              ${toString config.services.tailscale.port},
              ${ports.wireguard},
            } counter accept comment "router WAN UDP"

            # router DHCPv6 client
            # ip6 daddr fe80::/64 udp dport ${ports.dhcp6_client} udp sport ${ports.dhcp6_server} counter accept comment "router WAN DHCPv6"

            counter reject
          }

          chain input_limited_untrusted {
            # Handle some services early due to need for multicast/broadcast.
            udp dport ${ports.dhcp4_server} udp sport ${ports.dhcp4_client} counter accept comment "router untrusted DHCPv4"

            udp dport ${ports.mdns} udp sport ${ports.mdns} counter accept comment "router untrusted mDNS"

            # Allow only necessary router-provided services.
            tcp dport {
              ${ports.dns},
            } counter accept comment "router untrusted TCP"

            udp dport {
              ${ports.dns},
            } counter accept comment "router untrusted UDP"

            # Drop traffic trying to cross VLANs or broadcast.
            ${
          lib.concatMapStrings (ifi: ''
            # iifname ${ifi.name} ip daddr != ${ifi.prefix} counter drop comment "${ifi.name} traffic leaving IPv4 VLAN"
          '')
          cfg.lan.untrusted
        }


            counter drop
          }

          chain output {
            type filter hook output priority 0
            policy accept
            counter accept
          }

          chain forward {
            type filter hook forward priority 0
            policy drop

            # Untrusted/limited LANs to trusted LANs.
            iifname {
              ${mkCSV cfg.lan.untrusted}
            } oifname {
              ${mkCSV cfg.lan.trusted}
            } jump forward_limited_untrusted_lan_trusted_lan

            # We still want to allow limited/untrusted LANs to have working ICMP
            # to the internet as a whole, just not to any trusted LANs.
            ${icmp_rules}

            # Forwarding between different interface groups.

            # Trusted source LANs.
            iifname {
              ${mkCSV cfg.lan.trusted}
            } oifname {
              ${mkCSV cfg.wans}
            } counter accept comment "Allow trusted LANs to all WANs";

            iifname {
              ${mkCSV cfg.lan.trusted}
            } oifname {
              ${mkCSV cfg.lan.trusted},
              ${mkCSV cfg.lan.untrusted},
            } counter accept comment "Allow trusted LANs to reach all LANs";

            # Limited/guest LANs to WAN.
            iifname {
              ${mkCSV cfg.lan.untrusted}
            } oifname {
              ${mkCSV cfg.wans}
            } counter accept comment "Allow limited LANs only to WANs";

            # All WANs to trusted LANs.
            iifname {
              ${mkCSV cfg.wans}
            } oifname {
              ${mkCSV cfg.lan.trusted}
            } jump forward_wan_trusted_lan

            # All WANs to limited/untrusted LANs.
            iifname {
              ${mkCSV cfg.wans}
            } oifname {
              ${mkCSV cfg.lan.untrusted}
            } jump forward_wan_limited_untrusted_lan

            counter reject
          }

          chain forward_limited_untrusted_lan_trusted_lan {
            # Only allow established connections from trusted LANs.
            ct state {established, related} counter accept
            ct state invalid counter drop

            counter drop
          }

          chain forward_wan_trusted_lan {
            ct state {established, related} counter accept
            ct state invalid counter drop

            # TODO(kradalby): If needed, look at:
            # https://github.com/mdlayher/homelab/blob/main/nixos/routnerr-3/nftables.nix

            counter reject
          }

          chain forward_wan_limited_untrusted_lan {
            ct state {established, related} counter accept
            ct state invalid counter drop

            counter reject
          }
        }

        table ip nat {
          chain prerouting {
            type nat hook prerouting priority 0

            # NAT IPv4 to all WANs.
            iifname {
              ${mkCSV cfg.wans}
            } jump prerouting_wans
            accept
          }

          chain prerouting_wans {
            # TODO(kradalby): If needed, look at:
            # https://github.com/mdlayher/homelab/blob/main/nixos/routnerr-3/nftables.nix
            accept
          }

          chain postrouting {
            type nat hook postrouting priority 0
            # Masquerade IPv4 to all WANs.
            oifname {
              ${mkCSV cfg.wans}
            } masquerade
          }
        }
      '';
    };
  };
}
