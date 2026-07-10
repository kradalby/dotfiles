{
  config,
  lib,
  ...
}: let
  # Fail closed: every sanoid-managed dataset on the pool is backed up to
  # Jottacloud unless explicitly excluded here. A new dataset that is added
  # to zfs.nix joins the offsite backup by default.
  excluded = [
    "storage/dropbox" # mirrored by its cloud origin
    "storage/timemachine" # laptop backups; not worth a second offsite copy
  ];

  datasetPaths =
    map (name: "/${name}")
    (lib.filter (name: !(lib.elem name excluded))
      (lib.attrNames config.services.sanoid.datasets));
in {
  # Mint the Jotta rclone remote from a login token in age (replaces the
  # hand-run `rclone config` wizard). Only mints when logged out.
  services.rclone-jotta = {
    enable = true;
    secret = "rclone-jotta-storage-ldn-token";
  };

  services.restic.jobs.jotta = {
    enable = true;
    repository = "rclone:Jotta:ZW1QYWNrYWdlcyA9IFsKICAgIHBrZ3MuZG";
    secret = "restic-storage-ldn-token";
    paths = ["/etc/nixos"] ++ datasetPaths;
    # rclone to Jottacloud: reading pack data costs egress and takes forever;
    # verify metadata only, monthly. The tjoda/ldn REST repos get the
    # read-data checks.
    check = {
      args = [];
      interval = "monthly";
    };
  };
}
