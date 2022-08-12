{ lib, config, pkgs, ... }:
with lib;
let
  commonJob = { name, repository, secret, paths, owner ? "root" }:
    mkMerge [
      {
        age.secrets."${secret}" = {
          file = ../../secrets + "/${secret}.age";
          inherit owner;
        };
      }
      {
        services.restic.backups."${name}" = {
          inherit repository;
          inherit paths;

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
        services.restic.backups."${name}" = {
          logPath = "/Users/kradalby/Library/Logs";
          calendarInterval = {
            Minute = 30;
          };

        };
      })

      (mkIf pkgs.stdenv.isLinux {
        services.restic.backups."${name}".timerConfig = {
          OnCalendar = "hourly";
        };
      })

      # (mkIf pkgs.stdenv.isLinux {
      #   systemd.services."restic-backups-${site}".onFailure = [ "notify-discord@%n.service" ];
      # })
    ];

  backupJob = { name ? config.networking.fqdn, site, secret, paths, owner ? "root" }: (commonJob {
    inherit secret;
    inherit paths;
    inherit owner;
    name = site;
    repository = "rest:https://restic.core.${site}.fap.no/${name}";
  });
in
{
  inherit backupJob;
  inherit commonJob;
}
