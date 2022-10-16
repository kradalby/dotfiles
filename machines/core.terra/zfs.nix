{
  config,
  lib,
  ...
}: {
  services.zfs.trim.enable = true;
  # services.zfs.autoScrub.enable = true;
  # services.zfs.autoSnapshot.enable = true;

  # Storage
  # zpool create -f -O canmount=on -O mountpoint=/storage -O compression=zstd -O atime=off -O xattr=sa -O acltype=posixacl storage raidz scsi-3600508b1001c5da9b55104a2d92a60d3 scsi-3600508b1001c812ed7e944d9346e7e8a scsi-3600508b1001cce05aaf1d2ac5de70f87 cache scsi-3600508b1001cbfde22b0e4eeb7da54e
  # for i in backup libraries pictures restic software sync timemachine
  #   zfs create -o canmount=on -o mountpoint=/storage/$i storage/$i
  # end

  # fast
  # zpool create -f -O canmount=on -O mountpoint=/fast -O compression=zstd -O atime=off -O xattr=sa -O acltype=posixacl fast raidz scsi-3600508b1001cb9558ac72b1dbaf42c37 scsi-3600508b1001ca4115b64d914e7902b78 scsi-3600508b1001c665745b4207ccb315b39

  services.sanoid = {
    enable = true;
    templates = {
      "normal" = {
        "frequently" = 0;
        "hourly" = 1;
        "daily" = 1;
        "monthly" = 4;
        "yearly" = 0;
        "autosnap" = true;
        "autoprune" = true;
      };
    };
    datasets = builtins.listToAttrs (builtins.map
      (item: {
        name = item;
        value = {useTemplate = ["normal"];};
      }) [
        "storage/backup"
        "storage/libraries"
        "storage/pictures"
        "storage/software"
        "storage/sync"
      ]);
  };
}
