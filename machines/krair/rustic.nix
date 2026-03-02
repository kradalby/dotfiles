# Rustic backup to Jottacloud for krair (personal Mac).
#
# Backs up to an existing restic-compatible repository on Jottacloud
# via rclone. The repository was originally created by restic; rustic
# is a drop-in compatible replacement.
#
# Repository password is fetched from 1Password via `op read` in the
# rustic TOML profile's password-command field. The 1Password CLI
# must be signed in (GUI app handles this automatically).
#
# FDA setup (one-time):
#   The backup includes TCC-protected directories (Desktop, Documents,
#   Downloads). After the first `darwin-rebuild switch`, grant FDA to:
#     ~/Applications/RusticBackup.app
#   in System Settings > Privacy & Security > Full Disk Access.
#
# Useful commands:
#   # Manual backup trigger:
#   launchctl kickstart gui/$(id -u)/org.nixos.rustic-backups-jotta
#
#   # Force restart (kills running instance):
#   launchctl kickstart -k gui/$(id -u)/org.nixos.rustic-backups-jotta
#
#   # View logs:
#   tail -f ~/Library/Logs/rustic-jotta.log
#   tail -f ~/Library/Logs/rustic-jotta-error.log
#
#   # Check FDA status:
#   sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
#     "SELECT client, auth_value FROM access \
#      WHERE service='kTCCServiceSystemPolicyAllFiles' \
#        AND client='com.kradalby.rustic-backup'"
#
#   # Browse snapshots:
#   rustic -P jotta snapshots
#
#   # Restore a file:
#   rustic -P jotta restore <snapshot-id> <target-dir>
{...}: let
  home = "/Users/kradalby";

  basePaths = [
    "${home}/git"
  ];

  # TCC-protected directories — require Full Disk Access granted to
  # ~/Applications/RusticBackup.app (see module header comment).
  fdaPaths = [
    "${home}/Desktop"
    "${home}/Documents"
    "${home}/Downloads"
  ];

  jottaPaths =
    basePaths
    ++ fdaPaths
    ++ [
      "${home}/Pictures"
    ];
in {
  services.rustic.backups = {
    jotta = {
      # Jottacloud bucket ID for this host's restic repository.
      # Found via: rclone lsd Jotta: (or from the old tmuxinator config).
      repository = "rclone:Jotta:5ac5edab2737c974f87e0146690b74b0";

      # 1Password item: "restic - krair" in the Private vault.
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
          # Skip directories containing these marker files
          exclude-if-present = [".nobackup" "CACHEDIR.TAG"];
          git-ignore = true;
        };
      };
    };
  };
}
