{ config, lib, ... }:
let
  resticBackup = site: secret: directories: {
    sops.secrets."${secret}" = { };
    services.restic.backups."${site}" = {
      repository = "rest:https://restic.core.${site}.fap.no/${config.networking.fqdn}";
      paths = directories;
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 5"
        "--keep-monthly 12"
        "--keep-yearly 75"
      ];
      initialize = true;
      passwordFile = config.sops.secrets."${secret}".path;
      timerConfig = {
        OnCalendar = "hourly";
      };
    };

    systemd.timers."restic-backups-${site}".onFailure = [ "notify-email@%n.service" ];
    systemd.services."restic-backups-${site}".onFailure = [ "notify-email@%n.service" ];

  };

  directories = [
    "/etc/nixos"
    "/var/lib/zigbee2mqtt"
    "/var/lib/homebridge"
    "/var/lib/unifi/data/backup"
  ];
in

(resticBackup "tjoda" "restic-ldn-home-token" directories)
  //
(resticBackup "terra" "restic-ldn-home-token" directories)
