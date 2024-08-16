{
  config,
  lib,
  ...
}: {
  services.zfs.trim.enable = true;

  services.sanoid = {
    enable = true;
    templates = {
      "normal" = {
        "frequently" = 0;
        "hourly" = 0;
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
        "fast/win10"
        "storage/backup"
        "storage/libraries"
        "storage/pictures"
        "storage/software"
        "storage/sync"
      ]);
  };
}
