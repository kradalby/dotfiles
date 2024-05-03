{
  pkgs,
  lib,
  config,
  flakes,
  ...
}: let
  s = import ../../metadata/sites.nix {inherit lib config;};
  consul = import ../../common/funcs/consul.nix {inherit lib;};
  domain = "headscale.kradalby.no";
  aclConfig = {
    acls = [
      {
        action = "accept";
        src = ["*"];
        dst = ["*:*"];
      }
    ];

    ssh = [
      {
        action = "accept";
        src = ["kristoffer"];
        dst = ["*"];
        users = ["kradalby" "root"];
      }
    ];
  };
  aclPath = pkgs.writeTextFile {
    name = "acl.hujson";
    text = builtins.toJSON aclConfig;
  };

  cfg = config.services.headscale;
  settingsFormat = pkgs.formats.yaml {};
  configFile = settingsFormat.generate "headscale.yaml" cfg.settings;
in {
  # disabledModules = ["services/networking/headscale.nix"];
  #
  # imports = [
  #   "${flakes.nixpkgs-headscale-test}/nixos/modules/services/networking/headscale.nix"
  # ];

  age.secrets = {
    headscale-private-key = {
      owner = "headscale";
      file = ../../secrets/headscale-private-key.age;
    };
    headscale-noise-private-key = {
      owner = "headscale";
      file = ../../secrets/headscale-noise-private-key.age;
    };
    headscale-oidc-secret = {
      owner = "headscale";
      file = ../../secrets/headscale-oidc-secret.age;
    };
    headscale-envfile = {
      owner = "headscale";
      file = ../../secrets/headscale-envfile.age;
    };
  };

  environment.systemPackages = [pkgs.headscale pkgs.sqlite-interactive pkgs.sqlite-web];

  services.headscale = {
    enable = true;

    settings = {
      server_url = "https://${domain}";

      acl_policy_path = aclPath;

      # database.path = "file:/var/lib/headscale/db.sqlite?cache=shared&mode=rwc&_journal_mode=WAL&_busy_timeout=5000";
      # database.path = "file:/var/lib/headscale/db.sqlite?_journal_mode=WAL&_busy_timeout=5000";

      oidc = {
        # issuer = "https://id.kradalby.no/dex";
        # clientId = "headscale";
        issuer = "https://nextcloud.kradalby.no";
        client_id = "Pxc5EeJ8gYTcfESmsYysJoFEy2Usu2mDu51jULbzVIksR5WEXKOMwI0MNLM9E9md";
        client_secret_file = config.age.secrets.headscale-oidc-secret.path;

        domain_map = {
          ".*" = "fap";
        };
      };

      dns = {
        base_domain = "fap";
      };

      grpc_listen_addr = "127.0.0.1:50443";
      grpc_allow_insecure = true;

      noise = {
        private_key_path = config.age.secrets.headscale-noise-private-key.path;
      };

      prefixes = {
        ipv6 = "fd7a:115c:a1e0::/48";
        ipv4 = "100.64.0.0/10";
      };

      dns_config = {
        override_local_dns = true;
      };

      derp = {
        server = {
          enabled = true;
          region_id = 999;
          region_code = "ldn-fap";
          region_name = "headscale.oracldn.fap.no";
          stun_listen_addr = "0.0.0.0:3478";
          private_key_path = config.age.secrets.headscale-private-key.path;
        };
      };

      oidc = {
        only_start_if_oidc_is_available = false;
      };

      restricted_nameservers =
        {
          consul = s.nameservers;
        }
        // builtins.mapAttrs (site: server: [server]) s.consul;
    };
  };

  # Allow UDP for STUN
  networking.firewall.allowedUDPPorts = [3478];

  systemd.services.headscale = {
    serviceConfig = {
      EnvironmentFile = config.age.secrets.headscale-envfile.path;

      # Needs to be disabled for tsnet in tailsql to set up.
      RestrictAddressFamilies = lib.mkForce "";
    };
    environment = {
      HEADSCALE_LOG_LEVEL = "trace";
      # GRPC_GO_LOG_VERBOSITY_LEVEL = "2";
      # GRPC_GO_LOG_SEVERITY_LEVEL = "info";
      HEADSCALE_DEBUG_TAILSQL_STATE_DIR = "${config.users.users.headscale.home}/tailsql";
      HEADSCALE_DEBUG_TAILSQL_ENABLED = "1";

      # force the service to restart if the config has
      # changed.
      HEADSCALE_CONFIG_HASH = builtins.hashFile "md5" configFile;
    };
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
