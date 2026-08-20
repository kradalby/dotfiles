{ config, ... }:
let
  storageDatasets = [
    "backup"
    "books"
    "dropbox"
    # photo masters from krair (was on core.terra, offline since 2025-11).
    # Needs a one-time `zfs create -o canmount=on -o mountpoint=/storage/hugin storage/hugin` on deploy.
    "hugin"
    "libraries"
    "pictures"
    "software"
    "sync"
    "timemachine"
  ];
in
{
  imports = [
    ../../common/zfs.nix
    ../../common/sanoid-exporter.nix
  ];
  # Disk preparation (single 5 TB disk at /dev/sdb)
  # The disk is stably exposed as /dev/sdb inside the VM.
  # Example:
  #   zpool create -f \
  #     -O canmount=on \
  #     -O mountpoint=/storage \
  #     -O compression=zstd \
  #     -O atime=off \
  #     -O xattr=sa \
  #     -O acltype=posixacl \
  #     -O utf8only=on \
  #     -O normalization=formD \
  #     storage /dev/sdb
  #   for fs in backup books dropbox libraries pictures software sync timemachine; do
  #     zfs create -o canmount=on -o mountpoint=/storage/$fs storage/$fs
  #   done

  boot.supportedFilesystems = [ "zfs" ];
  # Don't block boot if the ZFS pool is missing (e.g., on clean machine deployment)
  boot.zfs.forceImportAll = false;
  boot.zfs.extraPools = [ "storage" ];

  services.zfs = {
    trim.enable = true;
    autoScrub.enable = true;
  };

  services.sanoid = {
    enable = true;
    templates = {
      # A wipe discovered days later must still be recoverable, so keep a
      # week of dailies.
      "normal" = {
        frequently = 0;
        hourly = 1;
        daily = 7;
        weekly = 4;
        monthly = 4;
        yearly = 0;
        autosnap = true;
        autoprune = true;
      };
      # The parent dataset holds only the restic repo dir (children are their
      # own datasets): lean retention so weekly prune repacks don't pin months
      # of churned packs. Two weeks is ample wipe-recovery.
      repo = {
        frequently = 0;
        hourly = 0;
        daily = 7;
        weekly = 2;
        monthly = 0;
        yearly = 0;
        autosnap = true;
        autoprune = true;
      };
    };
    datasets =
      builtins.listToAttrs (
        map (item: {
          name = "storage/${item}";
          value = {
            useTemplate = [ "normal" ];
          };
        }) storageDatasets
      )
      // {
        # The restic repo lives at /storage/restic, a directory on the parent
        # `storage` dataset (not its own dataset), so snapshot the parent to make
        # it recoverable after a client wipes it (rest-server is --no-auth).
        # Lean template: the parent holds only the repo dir, whose weekly
        # repacks would pin churn under longer retention.
        "storage" = {
          useTemplate = [ "repo" ];
        };
      };
  };
}
