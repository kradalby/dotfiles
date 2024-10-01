{
  lib,
  config,
  ...
}: let
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
  };

  # Produces a CSV list of interface names.
  mkCSV = lib.concatMapStrings (ifi: "${ifi.name}, ");

  # WAN interfaces.
  all_wans = "wan0, wan1";

  # LAN interfaces, segmented into trusted and untrusted groups.
  trusted_lans = [
    {
      name = "lanbr0";
      ipv4 = "10.65.0.1";
    }
    {name = "tailscale0";}
    {name = "wg0";}
    {name = "podman*";}
  ];
  untrusted_lans = [
    {
      name = "iot0";
      ipv4 = "192.168.156.1";
    }
  ];

  # ICMP filtering.
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
  # TODO: Enable when miniupnpd supports nftables
  # https://github.com/NixOS/nixpkgs/pull/239028
  services.miniupnpd.enable = lib.mkForce false;

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
          meta nftrace set 1

          type filter hook input priority 0
          policy drop

          ct state {established, related} counter accept
          ct state invalid counter drop

          # Malicious subnets.
          ip saddr {
            49.64.0.0/11,
            218.92.0.0/16,
            222.184.0.0/13,
          } counter drop comment "malicious subnets"

          # ICMPv4/6.
          ${icmp_rules}

          # Allow all WANs to selectively communicate with the router.
          iifname {
            ${all_wans}
          } jump input_wan

          # Always allow router solicitation from any LAN.
          ip6 nexthdr icmpv6 icmpv6 type nd-router-solicit counter accept

          # Allow localhost and trusted LANs to communicate with router.
          iifname {
            lo,
            ${mkCSV trusted_lans}
          } counter accept comment "localhost and trusted LANs to router"

          # Limit the communication abilities of limited and untrusted LANs.
          iifname {
            ${mkCSV untrusted_lans}
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
            51820,
          } counter accept comment "router WAN UDP"

          # router DHCPv6 client
          # ip6 daddr fe80::/64 udp dport ${ports.dhcp6_client} udp sport ${ports.dhcp6_server} counter accept comment "router WAN DHCPv6"

          counter reject
        }

        chain input_limited_untrusted {
          # Handle some services early due to need for multicast/broadcast.
          udp dport ${ports.dhcp4_server} udp sport ${ports.dhcp4_client} counter accept comment "router untrusted DHCPv4"

          udp dport ${ports.mdns} udp sport ${ports.mdns} counter accept comment "router untrusted mDNS"

          # Drop traffic trying to cross VLANs or broadcast.
              ${
        lib.concatMapStrings (ifi: ''
          iifname ${ifi.name} ip daddr != ${ifi.ipv4} counter drop comment "${ifi.name} traffic leaving IPv4 VLAN"
        '')
        untrusted_lans
      }

          # Allow only necessary router-provided services.
          tcp dport {
            ${ports.dns},
          } counter accept comment "router untrusted TCP"

          udp dport {
            ${ports.dns},
          } counter accept comment "router untrusted UDP"

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
            ${mkCSV untrusted_lans}
          } oifname {
            ${mkCSV trusted_lans}
          } jump forward_limited_untrusted_lan_trusted_lan

          # We still want to allow limited/untrusted LANs to have working ICMP
          # to the internet as a whole, just not to any trusted LANs.
          ${icmp_rules}

          # Forwarding between different interface groups.

          # Trusted source LANs.
          iifname {
            ${mkCSV trusted_lans}
          } oifname {
            ${all_wans}
          } counter accept comment "Allow trusted LANs to all WANs";

          iifname {
            ${mkCSV trusted_lans}
          } oifname {
            ${mkCSV trusted_lans},
            ${mkCSV untrusted_lans},
          } counter accept comment "Allow trusted LANs to reach all LANs";

          # Limited/guest LANs to WAN.
          iifname {
            ${mkCSV untrusted_lans}
          } oifname {
            ${all_wans}
          } counter accept comment "Allow limited LANs only to WANs";

          # All WANs to trusted LANs.
          iifname {
            ${all_wans}
          } oifname {
            ${mkCSV trusted_lans}
          } jump forward_wan_trusted_lan

          # All WANs to limited/untrusted LANs.
          iifname {
            ${all_wans}
          } oifname {
            ${mkCSV untrusted_lans}
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
            ${all_wans}
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
            ${all_wans}
          } masquerade
        }
      }
    '';
  };
}
