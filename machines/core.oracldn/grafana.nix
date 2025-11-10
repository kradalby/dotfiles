{
  pkgs,
  lib,
  config,
  ...
}: let
  nginx = import ../../common/funcs/nginx.nix {inherit config lib;};
  domain = "grafana.${config.networking.domain}";
in
  lib.mkMerge [
    {
      age.secrets.grafana-admin = {
        file = ../../secrets/grafana-admin.age;
        mode = "0400";
        owner = "grafana";
      };

      services.tailscale.services."svc:grafana" = {
        endpoints."tcp:443" = "http://localhost:${toString config.services.grafana.settings.server.http_port}";
      };

      services.grafana = {
        enable = true;

        settings = {
          server = {
            inherit domain;
            root_url = "https://${domain}";
            enforce_domain = false;
            enable_gzip = true;
            http_addr = "127.0.0.1";
          };

          analytics.reporting_enabled = false;

          auth = {
            anonymous_enabled = true;
            anonymous_org_name = "Main Org.";
            anonymous_org_role = "Viewer";
          };

          "auth.proxy" = {
            enabled = true;
            header_name = "X-WEBAUTH-USER";
            header_property = "username";
            auto_sign_up = true;
            whitelist = "127.0.0.1";
            headers = "Name:X-WEBAUTH-NAME";
            enable_login_token = true;
          };

          security.admin_password = "$__file{${config.age.secrets.grafana-admin.path}}";

          smtp = {
            enable = true;
            host = "smtp.fap.no:25";
            fromAddress = "grafana@${config.networking.domain}";
          };
        };

        provision = {
          enable = true;
          datasources = {
            settings.datasources = [
              {
                url = "https://prometheus.${config.networking.domain}";
                name = "Prometheus";
                isDefault = true;
                type = "prometheus";
              }
              {
                url = "https://loki.${config.networking.domain}";
                name = "Loki";
                type = "loki";
              }
            ];
          };
        };
      };
    }

    (nginx.internalVhost
      {
        inherit domain;
        proxyPass = "http://${toString config.services.grafana.settings.server.http_addr}:${toString config.services.grafana.settings.server.http_port}";

        locationExtraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-Server $host;
        '';
      })
  ]
