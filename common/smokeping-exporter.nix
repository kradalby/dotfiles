{
  config,
  lib,
  ...
}:
{
  services.prometheus.exporters.smokeping = {
    enable = true;

    hosts = [
      "core-oracldn.dalby.ts.net"
      "dev-oracfurt.dalby.ts.net"
      "dev.ldn.fap.no"
      "core.tjoda.fap.no"
      "vg.no"
      "1.1.1.1"
      "8.8.8.8"
    ];
  };

  systemd.services."prometheus-smokeping-exporter" = {
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    # The hosts above include .dalby.ts.net names, which only resolve once
    # tailscaled has MagicDNS up — later than network-online.target. The prober
    # exits when a name fails to resolve, so at boot it burns the default
    # five-restart budget inside a second and stays down until someone notices.
    # Retry patiently instead: there is no ordering to declare against, because
    # DNS readiness is not a unit that can be waited on.
    startLimitIntervalSec = 0;
    serviceConfig.RestartSec = 10;
  };

}
