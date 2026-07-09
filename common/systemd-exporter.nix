{
  config,
  lib,
  ...
}: {
  services.prometheus.exporters.systemd = {
    enable = true;
    # systemd_service_restart_total: state sampling at the 1m scrape interval
    # misses fast restart loops; the counter is what the ServiceRestartLoop
    # alert on core.oracldn consumes.
    extraFlags = ["--systemd.collector.enable-restart-count"];
  };

  networking.firewall.allowedTCPPorts =
    lib.mkIf config.networking.firewall.enable
    [config.services.prometheus.exporters.systemd.port];
}
