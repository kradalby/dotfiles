{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
let
  domain = "grafana.${config.networking.domain}";
  versions = import ../../metadata/versions.nix;

  fetchDashboard =
    {
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
  dashboardDir = pkgs.runCommand "grafana-dashboards" { } ''
    mkdir -p $out
    sed 's|''${DS_PROMETHEUS}|Prometheus|g' ${
      pkgs.fetchurl {
        url = "https://grafana.com/api/dashboards/1860/revisions/37/download";
        hash = "sha256-1DE1aaanRHHeCOMWDGdOS1wBXxOF84UXAjJzT5Ek6mM=";
      }
    } > $out/node-exporter-full.json
    cp ${
      fetchDashboard {
        id = 19727;
        rev = versions.grafanaDashboards.incus.rev;
        hash = versions.grafanaDashboards.incus.hash;
        name = "incus.json";
      }
    } $out/incus.json

    # Sloth SLO dashboard. Panels reference the datasource by the unresolved
    # ''${DS_PROMETHEUS} input uid, which Grafana falls back to our default
    # (Prometheus) datasource for — same as incus above, so no sed needed.
    cp ${
      fetchDashboard {
        id = 14348;
        rev = versions.grafanaDashboards.sloth.rev;
        hash = versions.grafanaDashboards.sloth.hash;
        name = "sloth.json";
      }
    } $out/sloth.json

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
  '';
in
{
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

    # The Infinity datasource (below) reads ghdl's JSON API. declarativePlugins
    # pins the plugin set, so any future plugin must be added here too.
    declarativePlugins = [ pkgs.grafanaPlugins.yesoreyeram-infinity-datasource ];

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

      security = {
        admin_password = "$__file{${config.age.secrets.grafana-admin.path}}";
        # NixOS 26.05 requires an explicit secret_key; this is the old
        # upstream default the existing DB is encrypted with. Nothing
        # sensitive lives in it (single passwordless local datasource).
        secret_key = "SW2YcwTIb9zpOOhoPsMm";
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
