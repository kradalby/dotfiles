{...}: let
  basePaths = [
    "$HOME/git"
  ];

  # With Full Disk Access granted to RusticBackup.app,
  # TCC-protected directories can be backed up.
  fdaPaths = [
    "$HOME/Desktop"
    "$HOME/Documents"
    "$HOME/Downloads"
  ];

  jottaPaths =
    basePaths
    ++ fdaPaths
    ++ [
      "$HOME/Pictures"
    ];
in {
  services.rustic.backups = {
    jotta = {
      repository = "rclone:Jotta:5ac5edab2737c974f87e0146690b74b0";
      passwordCommand = ''op read "op://Private/restic - krair/password"'';
      paths = jottaPaths;
      pruneOpts = {
        keep-daily = 7;
        keep-weekly = 5;
        keep-monthly = 12;
        keep-yearly = 75;
      };
      # Only prune on AC power to save battery
      pruneOnACOnly = true;
      # FDA wrapper for accessing Desktop/Documents/Downloads
      enableFDA = true;
      extraConfig = {
        backup = {
          exclude-if-present = [".nobackup" "CACHEDIR.TAG"];
          git-ignore = true;
        };
      };
    };
  };
}
