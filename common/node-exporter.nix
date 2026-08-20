{
  config,
  lib,
  ...
}:
{
  # Note: systemd metrics are collected by the dedicated systemd_exporter
  # (common/systemd-exporter.nix) which provides richer timer/start-time data.
  services.prometheus.exporters.node = lib.mkIf (!config.boot.isContainer) {
    enable = true;
    # Read textfile metrics written by out-of-band collectors (e.g.
    # common/sanoid-exporter.nix, common/litestream.nix).
    enabledCollectors = [ "textfile" ];
    extraFlags = [ "--collector.textfile.directory=/var/lib/prometheus-node-exporter-textfile" ];
  };

  # Own the textfile directory here, next to the flag that reads it, so every
  # collector-enabled host has it — not only the ones that also run a writer
  # module. Without it node_exporter logs a scrape error on every poll
  # (node_textfile_scrape_error == 1) and any writer's metrics go dark.
  systemd.tmpfiles.rules = lib.mkIf (!config.boot.isContainer) [
    "d /var/lib/prometheus-node-exporter-textfile 0755 root root -"
  ];

  # Scrapes come over the tailnet, so open on tailscale0 explicitly instead of
  # riding tailscaled's implicit accept (one netfilter-mode change from dark)
  # — the services.md tier-3 pattern. Interface-scoped, so it also survives a
  # host's mkForce'd global firewall list.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    config.services.prometheus.exporters.node.port
  ];
}
