{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
let
  domain = "grafana.${config.networking.domain}";
  # File provisioning does not resolve import inputs. Use the dashboard's
  # existing datasource variable, whose value is the selected datasource uid.
  slothDashboard = pkgs.runCommand "sloth.json" { } ''
    sed 's|''${DS_PROMETHEUS}|''${Datasource}|g' ${inputs.grafana-sloth} > $out
  '';

  dashboardDir = pkgs.runCommand "grafana-dashboards" { passthru = { inherit slothDashboard; }; } ''
    mkdir -p $out
    cp ${inputs.grafana-node-exporter-full} $out/node-exporter-full.json
    cp ${inputs.grafana-incus} $out/incus.json

    cp ${slothDashboard} $out/sloth.json

    # tsnixcache dashboard, generated from Go (Foundation SDK) in the tsnixcache
    # repo and shipped as a flake package, so it tracks the metrics it charts.
    cp ${
      inputs.tsnixcache.packages.${pkgs.stdenv.hostPlatform.system}.grafanaDashboards
    }/tsnixcache.json $out/tsnixcache.json

    # ghdl dashboards, likewise generated from Go and shipped as a flake package:
    # ghdl.json (downloads, via the Infinity datasource) and ghdl-service.json
    # (scrape health, via Prometheus).
    cp ${
      inputs.ghdl.packages.${pkgs.stdenv.hostPlatform.system}.grafanaDashboards
    }/ghdl.json $out/ghdl.json
    cp ${
      inputs.ghdl.packages.${pkgs.stdenv.hostPlatform.system}.grafanaDashboards
    }/ghdl-service.json $out/ghdl-service.json

    # asparges dashboard, likewise generated from Go in the asparges repo.
    cp ${
      inputs.asparges.packages.${pkgs.stdenv.hostPlatform.system}.grafanaDashboards
    }/asparges.json $out/asparges.json

    # Dashboards that chart several fleet services side by side, generated from Go.
    cp ${pkgs.dashboards.grafanaDashboards}/*.json $out/
  '';
in
{
  age.secrets.grafana-admin = {
    file = ../../secrets/grafana-admin.age;
    mode = "0400";
    owner = "grafana";
  };

  age.secrets.grafana-secret-key = {
    file = ../../secrets/grafana-secret-key.age;
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

    # The Infinity datasource (below) reads ghdl's JSON API. declarativePlugins
    # pins the plugin set, so any future plugin must be added here too.
    declarativePlugins = [ pkgs.grafanaPlugins.yesoreyeram-infinity-datasource ];

    settings = {
      # WAL mode: litestream replicates this db (litestream.nix) and requires
      # a WAL-journaled sqlite.
      database.wal = true;

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

      security = {
        admin_password = "$__file{${config.age.secrets.grafana-admin.path}}";
        # Rotated off the published upstream default. Rotation is safe: the DB
        # holds nothing encrypted worth keeping (single passwordless local
        # datasource); new writes encrypt with this key.
        secret_key = "$__file{${config.age.secrets.grafana-secret-key.path}}";
      };

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
          {
            # ghdl's JSON API, served on the tailnet node "ghdl" (:80). The data
            # dashboard queries /api/timeseries through this.
            name = "ghdl";
            type = "yesoreyeram-infinity-datasource";
            access = "proxy";
            url = "http://ghdl";
            jsonData = { };
          }
          {
            # energyd's JSON API, on localhost beside Grafana.
            name = "energyd";
            type = "yesoreyeram-infinity-datasource";
            access = "proxy";
            url = "http://${config.services.energyd.listenAddr}";
            jsonData = { };
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
