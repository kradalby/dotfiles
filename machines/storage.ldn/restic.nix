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
  # Jotta needs a one-off manual rclone login on this host (root). Get a
  # personal login token at https://www.jottacloud.com/web/secure (single-use,
  # expires in minutes), then run:
  #   rclone config create Jotta jottacloud config_type=standard config_login_token=<token>
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
