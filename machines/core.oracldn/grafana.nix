{
  pkgs,
  lib,
  config,
  ...
}: let
  domain = "grafana.${config.networking.domain}";
  versions = import ../../metadata/versions.nix;

  fetchDashboard = {
    id,
    rev,
    hash,
    name,
  }:
    pkgs.fetchurl {
      url = "https://grafana.com/api/dashboards/${toString id}/revisions/${rev}/download";
      inherit hash;
      inherit name;
    };

  # Community dashboards from grafana.com, post-processed to replace
  # datasource template variables with our provisioned datasource name.
  dashboardDir = pkgs.runCommand "grafana-dashboards" {} ''
    mkdir -p $out
    sed 's|''${DS_PROMETHEUS}|Prometheus|g' ${pkgs.fetchurl {
      url = "https://grafana.com/api/dashboards/1860/revisions/37/download";
      hash = "sha256-1DE1aaanRHHeCOMWDGdOS1wBXxOF84UXAjJzT5Ek6mM=";
    }} > $out/node-exporter-full.json
    cp ${fetchDashboard {
      id = 19727;
      rev = versions.grafanaDashboards.incus.rev;
      hash = versions.grafanaDashboards.incus.hash;
      name = "incus.json";
    }} $out/incus.json
  '';
in {
  age.secrets.grafana-admin = {
    file = ../../secrets/grafana-admin.age;
    mode = "0400";
    owner = "grafana";
  };

  # Use proxy-to-grafana instead of tailscale.services (Tailscale Serve)
  # because it injects X-WEBAUTH-USER and X-WEBAUTH-NAME headers that
  # Grafana's auth.proxy requires for Tailscale user authentication.
  services.tailscale-proxies.grafana = {
    enable = true;
    tailscaleKeyPath = config.age.secrets.tailscale-preauthkey.path;

    hostname = "grafana";
    backendPort = config.services.grafana.settings.server.http_port;
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
            name = "Prometheus";
            type = "prometheus";
            isDefault = true;
            access = "proxy";
            url = "http://localhost:${toString config.services.prometheus.port}";
            jsonData = {
              timeInterval = "60s";
            };
          }
        ];
      };
      dashboards = {
        settings.providers = [
          {
            name = "community";
            options.path = dashboardDir;
            disableDeletion = true;
          }
        ];
      };
    };
  };
}
