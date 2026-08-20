{
  config,
  lib,
  ...
}:
{
  imports = [
    ../../common/zfs.nix
    ../../common/sanoid-exporter.nix
  ];

  services.zfs.trim.enable = true;
  services.zfs.autoScrub.enable = true;

  services.sanoid = {
    enable = true;
    templates = {
      # A wipe of the snapshotted restic repo discovered days later must
      # still be recoverable, so keep a week of dailies.
      "normal" = {
        "frequently" = 0;
        "hourly" = 1;
        "daily" = 7;
        "weekly" = 4;
        "monthly" = 4;
        "yearly" = 0;
        "autosnap" = true;
        "autoprune" = true;
      };
      # For the restic/garage repo datasets: weekly prune repacks would pin
      # months of churned packs under `normal`'s monthlies on a pool already
      # at ~80%. Two weeks is ample wipe-recovery (alerts fire within hours).
      "repo" = {
        "frequently" = 0;
        "hourly" = 0;
        "daily" = 7;
        "weekly" = 2;
        "monthly" = 0;
        "yearly" = 0;
        "autosnap" = true;
        "autoprune" = true;
      };
    };
    datasets = builtins.listToAttrs (
      builtins.map
        (item: {
          name = item;
          value = {
            # Repo-style datasets (restic store, garage blocks) get the lean
            # template — their weekly repack churn must not pin months of
            # snapshots; user data keeps the full retention.
            useTemplate = [
              (if item == "storage/restic" || item == "storage/garage" then "repo" else "normal")
            ];
          };
        })
        [
          "storage/backup"
          # garage's datadir dataset (created at deploy; see garage.nix)
          "storage/garage"
          "storage/libraries"
          "storage/pictures"
          # The restic repo backing rest-server: snapshot it so a client that
          # forgets/prunes another host's data (--no-auth, shared store) can be
          # rolled back instead of losing every copy.
          "storage/restic"
          "storage/software"
          "storage/sync"
        ]
    );
  };
}
