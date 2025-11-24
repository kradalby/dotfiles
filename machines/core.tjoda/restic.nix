{ config, ... }: let
  paths = [
    "/root"
    "/etc/nixos"
    "/var/lib/unifi/data/backup"
    "/storage/backup"
    "/storage/libraries"
    "/storage/pictures"
    "/storage/software"
    "/storage/sync"
    # "/storage/restic"

    # Covered by /storage/backup
    # config.services.minio.configDir
  ];

in {
  services.restic.jobs.jotta = {
    repository = "rclone:Jotta:1d444f272fa766893d9a06cc4d392cd5";
    secret = "restic-core-tjoda-token";
    inherit paths;
  };
}
