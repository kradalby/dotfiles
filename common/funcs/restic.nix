{ config, ... }:

let
  backupJob = site: secret: directories: {
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

    systemd.timers."restic-backups-${site}".onFailure = [ "notify-discord@%n.service" ];
    systemd.services."restic-backups-${site}".onFailure = [ "notify-discord@%n.service" ];

  };

in
{ inherit backupJob; }
