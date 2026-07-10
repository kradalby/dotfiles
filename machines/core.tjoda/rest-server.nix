{
  pkgs,
  lib,
  config,
  ...
}: let
  port = 56899;
in {
  services.restic.server = {
    enable = true;
    dataDir = "/storage/restic";
    prometheus = true;
    listenAddress = "127.0.0.1:${toString port}";
    extraFlags = ["--no-auth"];
  };

  services.tailscale.services.restic-tjoda = {
    endpoints = {
      "tcp:80" = "http://127.0.0.1:${toString port}";
      # tcp:443 has no TLS termination — Tailscale VIP bug (tailscale/tailscale#19724, #18381); consumers use http. TODO(kradalby): revert when fixed.
      "tcp:443" = "http://127.0.0.1:${toString port}";
    };
  };

  services.tailscale-proxies.restic-sfiber = {
    enable = true;
    tailscaleKeyPath = config.age.secrets.headscale-sfiber-authkey.path;
    loginServer = "https://headscale.sandefjordfiber.no";
    hostname = "restic-tjoda";
    backendPort = port;
  };
}
