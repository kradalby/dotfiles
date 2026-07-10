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
  # Jotta needs a one-off manual rclone login on this host (root). Get a
  # personal login token at https://www.jottacloud.com/web/secure (single-use,
  # expires in minutes), then run:
  #   rclone config create Jotta jottacloud config_type=standard config_login_token=<token>
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
