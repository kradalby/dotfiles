{
  config,
  pkgs,
  lib,
  ...
}:
let
  port = 63470;
in
{
  # PICNIC_USERNAME= / PICNIC_PASSWORD= lines.
  age.secrets.picnic-mcp-env.file = ../../secrets/picnic-mcp-env.age;

  # 2FA is done once from any MCP client (picnic_generate_2fa_code →
  # picnic_verify_2fa_code); the session it yields lives in StateDirectory,
  # so restarts and redeploys stay logged in.
  systemd.services.picnic-mcp = {
    description = "Picnic MCP server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    environment = {
      ENABLE_HTTP_SERVER = "true";
      HTTP_HOST = "127.0.0.1";
      HTTP_PORT = toString port;
      PICNIC_COUNTRY_CODE = "NL";
      PICNIC_SESSION_FILE = "/var/lib/picnic-mcp/session.json";
      PICNIC_DEVICE_FILE = "/var/lib/picnic-mcp/device.json";
    };
    serviceConfig = {
      ExecStart = lib.getExe pkgs.mcp-picnic;
      DynamicUser = true;
      StateDirectory = "picnic-mcp";
      EnvironmentFile = config.age.secrets.picnic-mcp-env.path;
      Restart = "always";
      # It exits on a rejected login; a fast retry loop risks Picnic locking
      # the account.
      RestartSec = "5min";
    };
  };

  services.tailscale.services.picnic-mcp = {
    endpoints = {
      "tcp:80" = "http://127.0.0.1:${toString port}";
      # tcp:443 has no TLS termination — Tailscale VIP bug (tailscale/tailscale#19724, #18381); consumers use http. TODO(kradalby): revert when fixed.
      "tcp:443" = "http://127.0.0.1:${toString port}";
    };
  };
}
