{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  site = builtins.replaceStrings [".fap.no"] [""] config.networking.domain;
  nextdnsProfile = "842cee";
  nextdnsUpstreams = [
    "tls://2a07:a8c0::ae:9cfd"
    "tls://2a07:a8c1::ae:9cfd"
    "tls://45.90.28.178"
    "tls://45.90.30.178"
  ];
  cloudflareTlsHost = "cloudflare-dns.com";
  cloudflareUpstreams = [
    "tls://1.1.1.1"
    "tls://1.0.0.1"
    "tls://[2606:4700:4700::1111]"
    "tls://[2606:4700:4700::1001]"
  ];

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

    services.coredns = {
      enable = true;
      config = let
        currentSite = builtins.replaceStrings [".fap.no"] [""] config.networking.domain;
      in ''
        (b) {
        ${
          if (builtins.length config.my.coredns.bind > 0)
          then ''bind ${lib.concatStringsSep " " config.my.coredns.bind}''
          else ""
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

        (nextdns) {
          forward . ${concatStringsSep " " nextdnsUpstreams} {
            tls_servername ${nextdnsProfile}.dns.nextdns.io
            policy sequential
            health_check 5s
          }
        }

        (cloudflare) {
          forward . ${concatStringsSep " " cloudflareUpstreams} {
            tls_servername ${cloudflareTlsHost}
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

  };
}
