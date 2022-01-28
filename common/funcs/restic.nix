{ lib, config, pkgs, ... }:
with lib;
let
  backupJob = name: site: secret: directories:
    mkMerge [
      {
        age.secrets."${secret}".file = ../../secrets + "/${secret}.age";
      }
      {
        services.restic.backups."${site}" = {

          repository = "rest:https://restic.core.${site}.fap.no/${name}";

          paths = directories;
          pruneOpts = [
            "--keep-daily 7"
            "--keep-weekly 5"
            "--keep-monthly 12"
            "--keep-yearly 75"
          ];
          initialize = true;
          passwordFile = config.age.secrets."${secret}".path;

        };
      }

      (mkIf pkgs.stdenv.isDarwin {
        services.restic.backups."${site}" = {
          logPath = "/Users/kradalby/Library/Logs";
          calendarInterval = {
            Minute = 30;
          };

        };
      })

      (mkIf pkgs.stdenv.isLinux {
        services.restic.backups."${site}".timerConfig = {
          OnCalendar = "hourly";
        };
      })

      # (mkIf pkgs.stdenv.isLinux {
      #   systemd.services."restic-backups-${site}".onFailure = [ "notify-discord@%n.service" ];
      # })
    ];
in
{ inherit backupJob; }
