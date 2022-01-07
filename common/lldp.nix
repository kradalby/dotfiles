{ config, lib, ... }: {
  config = lib.mkIf (!config.boot.isContainer) {
    services.lldpd.enable = true;

    systemd.services.lldpd.onFailure = [ "notify-email@%n.service" ];
  };
}
