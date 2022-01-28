{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.headscale;

  dataDir = "/var/lib/headscale";
  runDir = "/run/headscale";

  settingsFormat = pkgs.formats.yaml { };
  configFile = settingsFormat.generate "headscale.yaml" cfg.extraSettings;
in
{
  options = {
    services.headscale = {
      enable = mkEnableOption "headscale, Open Source coordination server for Tailscale";

      # package = mkPackageOption pkgs "headscale";

      user = mkOption {
        default = "headscale";
        type = types.str;
        description = ''
          User the headscale server should execute under.
        '';
      };

      group = mkOption {
        default = "headscale";
        type = types.str;
        description = ''
          If the default user "headscale" is configured then this is the primary
          group of that user.
        '';
      };

      serverUrl = mkOption {
        type = types.str;
        default = "http://127.0.0.1:8080";
        description = ''
          The url clients will connect to.
        '';
        example = "https://myheadscale.example.com:443";
      };

      address = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = ''
          Listening address of headscale.
        '';
        example = "0.0.0.0";
      };

      port = mkOption {
        type = types.int;
        default = 8080;
        description = ''
          Listening port of headscale.
        '';
        example = "443";
      };

      privateKeyFile = mkOption {
        type = types.path;
        description = ''
          Path to private key file, generated automatically if it does not exist.
        '';
      };

      derp = {
        urls = mkOption {
          type = types.listOf types.str;
          default = [ "https://controlplane.tailscale.com/derpmap/default" ];
          description = ''
            List of urls containing DERP maps.

            <link xlink:href="https://tailscale.com/blog/how-tailscale-works/"><literal>How Tailscale works</link>
          '';
        };

        paths = mkOption {
          type = types.listOf types.path;
          default = [ ];
          description = ''
            List of file paths containing DERP maps.

            <link xlink:href="https://tailscale.com/blog/how-tailscale-works/"><literal>How Tailscale works</link>
          '';
        };


        autoUpdate = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Whether to automatically update DERP maps on a set frequency.
          '';
          example = false;
        };

        updateFrequency = mkOption {
          type = types.str;
          default = "24h";
          description = ''
            Frequency to update DERP maps.
          '';
          example = "5m";
        };

      };

      ephemeralNodeInactivityTimeout = mkOption {
        type = types.str;
        default = "30m";
        description = ''
          Time before an inactive ephemeral node is deleted.
        '';
        example = "5m";
      };

      database = {
        type = mkOption {
          type = types.enum [ "sqlite3" "postgres" ];
          example = "postgres";
          default = "sqlite3";
          description = "Database engine to use.";
        };

        host = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "127.0.0.1";
          description = "Database host address.";
        };

        port = mkOption {
          type = types.nullOr types.int;
          default = null;
          example = 3306;
          description = "Database host port.";
        };

        name = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "headscale";
          description = "Database name.";
        };

        user = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "headscale";
          description = "Database user.";
        };

        passwordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          example = "/run/keys/headscale-dbpassword";
          description = ''
            A file containing the password corresponding to
            <option>database.user</option>.
          '';
        };

        path = mkOption {
          type = types.nullOr types.str;
          default = "${dataDir}/db.sqlite";
          description = "Path to the sqlite3 database file.";
        };
      };

      logLevel = mkOption {
        type = types.str;
        default = "info";
        description = ''
          headscale log level.
        '';
        example = "debug";
      };

      dns = {
        nameservers = mkOption {
          type = types.listOf types.str;
          default = [ "1.1.1.1" ];
          description = ''
            List of nameservers to pass to Tailscale clients.
          '';
        };

        domains = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            Search domains to inject to Tailscale clients.
          '';
          example = [ "mydomain.internal" ];
        };

        magicDns = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Whether to use [MagicDNS](https://tailscale.com/kb/1081/magicdns/).
            Only works if there is at least a nameserver defined.
          '';
          example = false;
        };

        baseDomain = mkOption {
          type = types.str;
          default = "";
          description = ''
            Defines the base domain to create the hostnames for MagicDNS.
            <option>baseDomain</option> must be a FQDNs, without the trailing dot.
            The FQDN of the hosts will be
            <literal>hostname.namespace.base_domain</literal> (e.g., _myhost.mynamespace.example.com_).
          '';
        };
      };

      openIdConnect = {
        issuer = mkOption {
          type = types.str;
          default = "";
          description = ''
            URL to OpenID issuer.
          '';
          example = "https://openid.example.com";
        };

        clientId = mkOption {
          type = types.str;
          default = "";
          description = ''
            OpenID Connect client ID.
          '';
        };

        clientSecretFile = mkOption {
          type = types.path;
          default = "";
          description = ''
            Path to OpenID Connect client secret file.
          '';
        };

        domainMap = mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = ''
            Domain map is used to map incomming users (by their email) to
            a namespace. The key can be a string, or regex.
          '';
          example = {
            ".*" = "default-namespace";
          };
        };

      };

      tls = {
        letsencrypt = {
          hostname = mkOption {
            type = types.nullOr types.str;
            default = "";
            description = ''
              Domain name to request a TLS certificate for.
            '';
          };
          challengeType = mkOption {
            type = types.enum [ "TLS_ALPN-01" "HTTP-01" ];
            default = "HTTP-01";
            description = ''
              Type of ACME challenge to use, currently supported types:
              <literal>HTTP-01</literal> or <literal>TLS_ALPN-01</literal>.
            '';
          };
          httpListen = mkOption {
            type = types.nullOr types.str;
            default = ":http";
            description = ''
              When HTTP-01 challenge is chosen, letsencrypt must set up a
              verification endpoint, and it will be listening on:
              <literal>:http = port 80</literal>.
            '';
          };
        };

        certFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = ''
            Path to already created certificate.
          '';
        };

        keyFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = ''
            Path to key for already created certificate.
          '';
        };
      };

      aclPolicyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to a file containg ACL policies.
        '';
      };

      extraSettings = mkOption {
        type = settingsFormat.type;
        default = { };
        description = ''
          Overrides to <filename>config.yaml</filename> as a Nix attribute set.
          This option is ideal for overriding settings not exposed as Nix options.
          Check the <link xlink:href="https://github.com/juanfont/headscale/blob/main/config-example.yaml">example config</link>
          for possible options.
        '';
      };


    };

  };
  config = mkIf cfg.enable {

    services.headscale.extraSettings = {
      server_url = cfg.serverUrl;
      listen_addr = "${cfg.address}:${toString cfg.port}";

      private_key_path = cfg.privateKeyFile;

      derp = {
        urls = cfg.derp.urls;
        paths = cfg.derp.paths;
        auto_update_enable = cfg.derp.autoUpdate;
        update_frequency = cfg.derp.updateFrequency;
      };

      # Turn off update checks since the origin of our package
      # is nixpkgs and not Github.
      disable_check_updates = true;

      ephemeral_node_inactivity_timeout = cfg.ephemeralNodeInactivityTimeout;

      db_type = cfg.database.type;
      db_path = cfg.database.path;

      log_level = cfg.logLevel;

      dns_config = {
        nameservers = cfg.dns.nameservers;
        domains = cfg.dns.domains;
        magic_dns = cfg.dns.magicDns;
        base_domain = cfg.dns.baseDomain;
      };

      unix_socket = "${runDir}/headscale.sock";

      # OpenID Connect
      oidc = {
        issuer = cfg.openIdConnect.issuer;
        client_id = cfg.openIdConnect.clientId;
        domain_map = cfg.openIdConnect.domainMap;
      };

      tls_letsencrypt_cache_dir = "${dataDir}/.cache";

      acl_policy_path = cfg.aclPolicyFile;
    } // optionalAttrs (cfg.database.host != null) {
      db_host = cfg.database.host;
    } // optionalAttrs (cfg.database.port != null) {
      db_port = cfg.database.port;
    } // optionalAttrs (cfg.database.name != null) {
      db_name = cfg.database.name;
    } // optionalAttrs (cfg.database.user != null) {
      db_user = cfg.database.user;
    } // optionalAttrs (cfg.tls.letsencrypt.hostname != null) {
      tls_letsencrypt_hostname = cfg.tls.letsencrypt.hostname;
    } // optionalAttrs (cfg.tls.letsencrypt.challengeType != null) {
      tls_letsencrypt_challenge_type = cfg.tls.letsencrypt.challengeType;
    } // optionalAttrs (cfg.tls.letsencrypt.httpListen != null) {
      tls_letsencrypt_listen = cfg.tls.letsencrypt.httpListen;
    } // optionalAttrs (cfg.tls.certFile != null) {
      tls_cert_path = cfg.tls.certFile;
    } // optionalAttrs (cfg.tls.keyFile != null) {
      tls_key_path = cfg.tls.keyFile;
    };

    # Setup the headscale configuration in a known path in /etc to
    # allow both the Server and the Client use it to find the socket
    # for communication.
    environment.etc."headscale/config.yaml".source = configFile;

    users.groups.headscale = mkIf (cfg.group == "headscale") { };

    users.users = optionalAttrs (cfg.user == "headscale") {
      headscale = {
        description = "headscale user";
        home = dataDir;
        group = cfg.group;
        isSystemUser = true;
      };
    };

    systemd.services.headscale = {
      description = "headscale coordination server for Tailscale";
      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ configFile ];

      script = ''
        ${optionalString (cfg.database.passwordFile != null) ''
          export HEADSCALE_DB_PASS="$(head -n1 ${cfg.database.passwordFile})"
        ''}

        export HEADSCALE_OIDC_CLIENT_SECRET="$(head -n1 ${escapeShellArg cfg.openIdConnect.clientSecretFile})"
        exec ${pkgs.headscale}/bin/headscale serve
      '';

      serviceConfig =
        let
          capabilityBoundingSet = [ "CAP_CHOWN" ] ++ optional (cfg.port < 1024) "CAP_NET_BIND_SERVICE";
        in
        {
          Restart = "always";
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;

          # Hardening options
          RuntimeDirectory = "headscale";
          # Allow headscale group access so users can be added and use the CLI.
          RuntimeDirectoryMode = "0770";

          StateDirectory = "headscale";
          StateDirectoryMode = "0755";

          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          PrivateMounts = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectHostname = true;
          ProtectClock = true;
          ProtectProc = "invisible";
          ProcSubset = "pid";
          RestrictNamespaces = true;
          RemoveIPC = true;
          UMask = "0077";

          CapabilityBoundingSet = capabilityBoundingSet;
          AmbientCapabilities = capabilityBoundingSet;
          NoNewPrivileges = true;
          LockPersonality = true;
          RestrictRealtime = true;
          SystemCallFilter = [ "@system-service" "~@priviledged" "@chown" ];
          SystemCallArchitectures = "native";
          RestrictAddressFamilies = "AF_INET AF_INET6 AF_UNIX";
        };
    };
  };

  # meta.maintainers = with maintainers; [ kradalby ];
}
