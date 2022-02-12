{ config, lib, ... }:
let
  consul = import ./funcs/consul.nix { inherit lib; };
in
{
  services.prometheus.exporters.smokeping = {
    enable = true;
    openFirewall = true;

    hosts = [
      "core.terra.fap.no"
      "core.oracle-ldn.fap.no"
      "core.ntnu.fap.no"
      "core.ldn.fap.no"
      "core.tjoda.fap.no"
      "vg.no"
      "1.1.1.1"
      "8.8.8.8"
    ];
  };

  systemd.services."prometheus-smokeping-exporter" = {
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" "dns-ready.service" ];
    after = [ "dns-ready.service" ];
    onFailure = [ "notify-discord@%n.service" ];
  };

  my.consulServices.smokeping_exporter = consul.prometheusExporter "smokeping" config.services.prometheus.exporters.smokeping.port;
}
