{
  config,
  pkgs,
  lib,
  ...
}:
let
  port = 63471;
in
{
  # Viewer service-account token for the local Grafana API; clients need no token.
  age.secrets.grafana-mcp-env.file = ../../secrets/grafana-mcp-env.age;

  systemd.services.grafana-mcp = {
    description = "Grafana MCP server";
    wantedBy = [ "multi-user.target" ];
    after = [ "grafana.service" ];
    wants = [ "grafana.service" ];
    environment.GRAFANA_URL = "http://127.0.0.1:${toString config.services.grafana.settings.server.http_port}";
    serviceConfig = {
      ExecStart = "${lib.getExe pkgs.mcp-grafana} -t streamable-http --address 127.0.0.1:${toString port} --endpoint-path /mcp --enabled-tools search,datasource,prometheus,dashboard,folder,annotations,navigation,alerting --disable-write --metrics";
      DynamicUser = true;
      EnvironmentFile = config.age.secrets.grafana-mcp-env.path;
      Restart = "always";
      RestartSec = "15s";
      KillMode = "mixed";
      TimeoutStopSec = "30s";
    };
  };

  services.tailscale.services.grafana-mcp.endpoints = {
    "tcp:80" = "http://127.0.0.1:${toString port}";
    # tcp:443 has no TLS termination — same VIP workaround as picnic-mcp.
    "tcp:443" = "http://127.0.0.1:${toString port}";
  };
}
