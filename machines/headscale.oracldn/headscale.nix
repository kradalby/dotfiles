{ pkgs, lib, config, ... }:
let
  s = import ../../metadata/sites.nix { inherit lib config; };
  consul = import ../../common/funcs/consul.nix { inherit lib; };
  domain = "headscale.kradalby.no";
in
{
  age.secrets.headscale-private-key = {
    owner = "headscale";
    file = ../../secrets/headscale-private-key.age;
  };
  age.secrets.headscale-oidc-secret = {
    owner = "headscale";
    file = ../../secrets/headscale-oidc-secret.age;
  };

  environment.systemPackages = [ pkgs.headscale pkgs.sqlite-interactive pkgs.sqlite-web ];

  services.headscale = {
    enable = true;

    serverUrl = "https://${domain}";

    privateKeyFile = config.age.secrets.headscale-private-key.path;

    openIdConnect = {
      issuer = "https://id.kradalby.no/dex";
      clientId = "headscale";
      clientSecretFile = config.age.secrets.headscale-oidc-secret.path;

      domainMap = {
        ".*" = "fap";
      };
    };

    settings = {
      grpc_listen_addr = "127.0.0.1:50443";
      grpc_allow_insecure = true;

      ip_prefixes = [
        "fd7a:115c:a1e0::/48"
        "100.64.0.0/10"
      ];

      derp = {
        server = {
          enabled = true;
          region_id = 999;
          region_code = "fap";
          region_name = "headscale.oracldn.fap.no";

          stun = {
            enabled = true;
            listen_addr = "0.0.0.0:3478";
          };
        };
      };

      restricted_nameservers = {
        consul = s.nameservers;
      } // builtins.mapAttrs (site: server: [ server ]) s.consul;
    };
  };

  # Allow UDP for STUN
  networking.firewall.allowedUDPPorts = [ 3478 ];

  systemd.services.headscale.onFailure = [ "notify-discord@%n.service" ];

  systemd.services.headscale.environment = {
    # HEADSCALE_LOG_LEVEL = "trace";
    # GRPC_GO_LOG_VERBOSITY_LEVEL = "2";
    # GRPC_GO_LOG_SEVERITY_LEVEL = "info";
  };

  my.consulServices.headscale = consul.prometheusExporter "headscale" 9090;

  security.acme.certs."${domain}".domain = domain;

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    useACMEHost = domain;
    locations = {
      "/headscale." = {
        extraConfig = ''
          grpc_pass grpc://${config.services.headscale.settings.grpc_listen_addr};
        '';
        priority = 1;
      };
      "/metrics" = {
        proxyPass = "http://127.0.0.1:${toString config.services.headscale.port}";
        extraConfig = ''
          allow 10.0.0.0/8;
          allow 100.64.0.0/16;
          deny all;
        '';
        priority = 2;
      };
      "/" = {
        proxyPass = "http://127.0.0.1:${toString config.services.headscale.port}";
        proxyWebsockets = true;
        extraConfig = ''
          keepalive_requests          100000;
          keepalive_timeout           160s;
          proxy_buffering             off;
          proxy_connect_timeout       75;
          proxy_ignore_client_abort   on;
          proxy_read_timeout          900s;
          proxy_send_timeout          600;
          send_timeout                600;
        '';
        priority = 99;
      };
    };
    extraConfig = ''
      access_log /var/log/nginx/${domain}.access.log;
    '';
  };
}
