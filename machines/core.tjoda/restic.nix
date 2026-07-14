{ config, ... }:
let
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
in
{
  # Same repo the old direct rclone:Jotta: job wrote (the proxy serves the
  # Jotta root), now via the local proxy — its state dir holds this host's
  # only Jotta login (./restic-jotta.nix). localhost, not the VIP: local
  # backups shouldn't depend on the tailnet.
  services.restic.jobs.jotta = {
    enable = true;
    repository = "rest:http://127.0.0.1:56900/1d444f272fa766893d9a06cc4d392cd5";
    secret = "restic-core-tjoda-token";
    inherit paths;
    # rclone to Jottacloud: reading pack data costs egress and takes forever;
    # verify metadata only, monthly. The local REST repo gets the read-data check.
    check = {
      args = [ ];
      interval = "monthly";
    };
  };

  # The backup dials the proxy on this host; order after it so the
  # boot-time Persistent timer run doesn't fail and page ServiceFailed.
  systemd.services.restic-backups-jotta = {
    after = [ "rclone-jotta.service" ];
    wants = [ "rclone-jotta.service" ];
  };
}
