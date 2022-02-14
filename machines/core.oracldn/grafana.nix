{ pkgs, lib, config, ... }:
let
  domain = "grafana.${config.networking.domain}";
in
{
  age.secrets.grafana-admin = {
    file = ../../secrets/grafana-admin.age;
    mode = "0400";
    owner = "grafana";
  };


  services.grafana = {
    enable = true;
    domain = domain;
    rootUrl = "https://${domain}";

    analytics.reporting.enable = false;

    extraOptions = {
      SERVER_ENFORCE_DOMAIN = "true";

      AUTH_ANONYMOUS_ENABLED = "true";
      AUTH_ANONYMOUS_ORG_NAME = "Main Org.";
      AUTH_ANONYMOUS_ORG_ROLE = "Viewer";
      SERVER_ENABLE_GZIP = "true";
    };

    smtp = {
      enable = true;
      host = "smtp.fap.no:25";
      fromAddress = "grafana@${config.networking.domain}";
    };

    security.adminPasswordFile = config.age.secrets.grafana-admin.path;

    provision = {
      enable = true;
      datasources = [
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

  security.acme.certs."${domain}".domain = domain;

  services.nginx = {
    virtualHosts."${domain}" = {
      useACMEHost = domain;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://${toString config.services.grafana.addr}:${toString config.services.grafana.port}";

        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-Server $host;
        '';
      };
    };
  };
}
