{ config, ... }:
let
  storageDatasets = [
    "backup"
    "books"
    "dropbox"
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
  # Disk preparation (single 5 TB disk, created by hand on first deploy; nix
  # only imports it via boot.zfs.extraPools below). Stable by-id path:
  #   zpool create -f \
  #     -O canmount=on \
  #     -O mountpoint=/storage \
  #     -O compression=zstd \
  #     -O atime=off \
  #     -O xattr=sa \
  #     -O acltype=posixacl \
  #     -O utf8only=on \
  #     -O normalization=formD \
  #     storage /dev/disk/by-id/ata-ST5000LM000-2U8170_WCJC5JSY
  #   for fs in backup books dropbox hugin libraries pictures software sync timemachine; do
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
      "normal" = {
        frequently = 0;
        hourly = 1;
        daily = 1;
        monthly = 4;
        yearly = 0;
        autosnap = true;
        autoprune = true;
      };
    };
    datasets = builtins.listToAttrs (
      map (item: {
        name = "storage/${item}";
        value = {
          useTemplate = [ "normal" ];
        };
      }) storageDatasets
    );
  };
}
