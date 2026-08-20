{
  config,
  lib,
  ...
}:
{
  services.prometheus.exporters.systemd = {
    enable = true;
    # systemd_service_restart_total: state sampling at the 1m scrape interval
    # misses fast restart loops; the counter is what the ServiceRestartLoop
    # alert on core.oracldn consumes.
    extraFlags = [ "--systemd.collector.enable-restart-count" ];
  };

  # Tailnet-only scrape: tailscale0-scoped, not a global open (services.md).
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    config.services.prometheus.exporters.systemd.port
  ];
}
