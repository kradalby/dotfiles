{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  consul = import ./funcs/consul.nix {inherit lib;};

  site = builtins.replaceStrings [".fap.no"] [""] config.networking.domain;

  nextdns-config = pkgs.writeTextFile {
    name = "nextdns-config";
    text = ''
      listen :53535
      setup-router no
      report-client-info yes

      profile 842cee
    '';
  };
in {
  imports = [
    ../modules/blocklist.nix
  ];

  options = {
    my.coredns.bind = mkOption {
      type = types.listOf types.str;
      default = [];
    };
  };

  config = {
    services.blocklist-downloader.enable = false;

    services.nextdns = {
      enable = true;
      arguments = [
        "-config-file=${nextdns-config}"
      ];
    };

    services.coredns = {
      enable = true;
      config = let
        sites = import ../metadata/consul.nix;
        currentSite = builtins.replaceStrings [".fap.no"] [""] config.networking.domain;

        s = import ../metadata/ipam.nix {inherit lib config;};
        peers = s.consulPeers;

        peer = name: ip: ''
          ${name} {
            import b
            forward . ${ip} {
              health_check 5s
            }
          }
        '';
      in ''
        (b) {
        ${
          if (builtins.length config.my.coredns.bind > 0)
          then ''bind ${lib.concatStringsSep " " config.my.coredns.bind}''
          else ""
        }
        }

        consul {
          import b
          forward . 127.0.0.1:8600 {
            health_check 5s
          }
        }

        dalby.ts.net {
          import b
          forward . 100.100.100.100:53 {
            health_check 5s
          }
        }

        # Internal zones.
        ${currentSite} {
          import b
          hosts {
        ${
          lib.concatMapStrings (host: ''
            ${host.ipAddress} ${host.hostname}.${currentSite}
          '')
          config.my.machines
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

        (nextdns) {
          forward . dns://127.0.0.1:53535 {
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
        ${
          if config.services.blocklist-downloader.enable
          then "import blacklist"
          else ""
        }
          import b
          import nextdns
        }
      '';
    };

    systemd.services.coredns = {
      # Set up a private tmp between the blocklist and coredns so we can share the blocklist.
      serviceConfig = {
        PrivateTmp = true;
      };
    };

    # networking.firewall.interfaces."${config.my.lan}".allowedTCPPorts = [ 53 9153 ];
    # networking.firewall.interfaces."${config.my.lan}".allowedUDPPorts = [ 53 ];
    networking.firewall.allowedTCPPorts = [53 9153];
    networking.firewall.allowedUDPPorts = [53];

    my.consulServices.coredns_exporter = consul.prometheusExporter "coredns" 9153;
  };
}
