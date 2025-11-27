{ config, ... }: let
  paths = [
    "/root"
    "/etc/nixos"
    "/storage/backup"
    "/storage/libraries"
    "/storage/pictures"
    "/storage/software"
    "/storage/sync"
    "/fast/files"
    # "/storage/restic"
    config.services.postgresqlBackup.location
  ];

in {
  services.restic.jobs.jotta = {
    enable = true;
    repository = "rclone:Jotta:3cee607f10a34c3fd67e4b292fda606f";
    secret = "restic-core-terra-token";
    inherit paths;
  };
}
