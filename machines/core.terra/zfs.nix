{
  config,
  lib,
  ...
}: {
  services.zfs.trim.enable = true;
  # services.zfs.autoScrub.enable = true;
  # services.zfs.autoSnapshot.enable = true;

  services.sanoid = {
    # TODO: set up
    enable = false;
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
