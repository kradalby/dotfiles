{
  pkgs,
  lib,
  config,
  ...
}: let
  location = lib.elemAt (lib.splitString "." config.networking.domain) 0;
  serviceName = "minio-${location}";
  consoleAddress = "127.0.0.1:49005";
in {
  age.secrets.minio-oracldn = {
    file = ../secrets/minio-oracldn.age;
  };

  services.minio = {
    enable = true;
    inherit consoleAddress;
    rootCredentialsFile = config.age.secrets.minio-oracldn.path;
  };

  # Metrics are JWT-gated by default; these serve only the tailnet/LAN and
  # hold nothing secret. Scraped by core.oracldn at
  # /minio/v2/metrics/cluster (NOT /metrics).
  systemd.services.minio.environment.MINIO_PROMETHEUS_AUTH_TYPE = "public";

  services.tailscale.services.${serviceName} = {
    endpoints = {
      "tcp:80" = "http://${consoleAddress}";
      # tcp:443 has no TLS termination — Tailscale VIP bug (tailscale/tailscale#19724, #18381); consumers use http. TODO(tailscale-vip-tls): revert when fixed.
      "tcp:443" = "http://${consoleAddress}";
      # S3 API for cross-site consumers (litestream replicas, backups);
      # reachable via the svc:minio-* grants in the tailnet policy.
      "tcp:9000" = "http://127.0.0.1:9000";
    };
  };
}
