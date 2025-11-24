{
  pkgs,
  lib,
  config,
  ...
}: let
  domain = "grafana.${config.networking.domain}";
in {
  age.secrets.grafana-admin = {
    file = ../../secrets/grafana-admin.age;
    mode = "0400";
    owner = "grafana";
  };

  services.tailscale.services."svc:grafana" = {
    endpoints = {
      "tcp:80" = "http://localhost:${toString config.services.grafana.settings.server.http_port}";
      "tcp:443" = "http://localhost:${toString config.services.grafana.settings.server.http_port}";
    };
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
