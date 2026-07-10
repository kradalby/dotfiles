{config, ...}: let
  paths = [
    "/root"
    "/etc/nixos"
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
  # Mint the Jotta rclone remote from a login token in age (replaces the
  # hand-run `rclone config` wizard). Only mints when logged out.
  services.rclone-jotta = {
    enable = true;
    secret = "rclone-jotta-core-tjoda-token";
  };

  services.restic.jobs.jotta = {
    enable = true;
    repository = "rclone:Jotta:1d444f272fa766893d9a06cc4d392cd5";
    secret = "restic-core-tjoda-token";
    inherit paths;
    # rclone to Jottacloud: reading pack data costs egress and takes forever;
    # verify metadata only, monthly. The local REST repo gets the read-data check.
    check = {
      args = [];
      interval = "monthly";
    };
  };
}
