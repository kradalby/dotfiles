{
  config,
  lib,
  ...
}: {
  services.prometheus.exporters.smokeping = {
    enable = true;

    hosts = [
      "core.terra.fap.no"
      "core.oracldn.fap.no"
      "dev.ldn.fap.no"
      "core.tjoda.fap.no"
      # "core.ntnu.fap.no"
      "vg.no"
      "1.1.1.1"
      "8.8.8.8"
    ];
  };

  systemd.services."prometheus-smokeping-exporter" = {
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];
  };

}
