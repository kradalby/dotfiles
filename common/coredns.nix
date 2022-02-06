{ config, lib, ... }:
with lib;
let
  consul = import ./funcs/consul.nix { inherit lib; };

  site = builtins.replaceStrings [ ".fap.no" ] [ "" ] config.networking.domain;
in
{
  imports = [
    ../modules/blocklist.nix
  ];
  services.blocklist-downloader.enable = true;

  services.coredns = {
    enable = true;
    config =
      let
        sites = import ../metadata/consul.nix;
        currentSite = builtins.replaceStrings [ ".fap.no" ] [ "" ] config.networking.domain;

        s = import ../metadata/sites.nix { inherit lib config; };
        peers = s.consulPeers;

        peer = name: ip: ''
          ${name} {
            forward . ${ip} {
              health_check 5s
            }
          }
        '';
      in
      ''
        consul {
          forward . 127.0.0.1:8600 {
            health_check 5s
          }
        }

        # Internal zones.
        ${currentSite} {
          hosts {
            ${lib.concatMapStrings (host: ''
                ${host.ipAddress} ${host.hostName}.${currentSite}
              '') config.services.dhcpd4.machines
            }
          }
        }

        ${concatStringsSep "\n" (attrValues (mapAttrs peer peers))}

        (cloudflare) {
          forward . tls://1.1.1.1 tls://1.0.0.1 tls://2606:4700:4700::1111 tls://2606:4700:4700::1001 {
            tls_servername cloudflare-dns.com
            health_check 5s
          }
        }

        (blacklist) {
          hosts ${config.services.blocklist-downloader.dataDir}/${config.services.blocklist-downloader.fileName} {
            reload 3600s
            no_reverse
            fallthrough
          }
        }

        . {
          cache 3600 {
            success 8192
            denial 4096
          }
          prometheus :9153
          import blacklist
          import cloudflare
        }
      '';
  };

  systemd.services.coredns = {
    onFailure = [ "notify-discord@%n.service" ];

    # Set up a private tmp between the blocklist and coredns so we can share the blocklist.
    serviceConfig = {
      PrivateTmp = true;
    };
  };

  # networking.firewall.interfaces."${config.my.lan}".allowedTCPPorts = [ 53 9153 ];
  # networking.firewall.interfaces."${config.my.lan}".allowedUDPPorts = [ 53 ];
  networking.firewall.allowedTCPPorts = [ 53 9153 ];
  networking.firewall.allowedUDPPorts = [ 53 ];

  my.consulServices.coredns_exporter = consul.prometheusExporter "coredns" 9153;
}
