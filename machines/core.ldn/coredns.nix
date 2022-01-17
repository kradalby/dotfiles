{ config, lib, ... }:
let
  consul = import ../../common/funcs/consul.nix { inherit lib; };
in
{
  services.coredns = {
    enable = true;
    config =
      let
        domain = "ldn";
      in
      ''
        . {
          cache 3600 {
            success 8192
            denial 4096
          }
          prometheus :9153
          forward . tls://1.1.1.1 tls://1.0.0.1 tls://2606:4700:4700::1111 tls://2606:4700:4700::1001 {
            tls_servername tls.cloudflare-dns.com
            health_check 5s
          }
        }

        consul {
          forward . 127.0.0.1:8600 {
            health_check 5s
          }
        }

        # Internal zone.
        ${domain} {
          hosts {
            ${lib.concatMapStrings (host: ''
                ${host.ipAddress} ${host.hostName}.${domain}
              '') config.services.dhcpd4.machines
            }
          }
        }
      '';
  };

  systemd.services.coredns.onFailure = [ "notify-discord@%n.service" ];

  # networking.firewall.interfaces."${config.my.lan}".allowedTCPPorts = [ 53 9153 ];
  # networking.firewall.interfaces."${config.my.lan}".allowedUDPPorts = [ 53 ];
  networking.firewall.interfaces.eth0.allowedTCPPorts = [ 53 9153 ];
  networking.firewall.interfaces.eth0.allowedUDPPorts = [ 53 ];

  my.consulServices.coredns_exporter = consul.prometheusExporter "coredns" 9153;
}
