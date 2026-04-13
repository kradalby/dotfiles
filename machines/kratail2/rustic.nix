# Rustic backup to Jottacloud for kratail2 (work Mac at Tailscale).
#
# Same setup as krair but with a different Jottacloud bucket and
# 1Password entry. See machines/krair/rustic.nix for detailed docs.
#
# FDA setup (one-time):
#   Grant FDA to ~/Applications/RusticBackup.app in
#   System Settings > Privacy & Security > Full Disk Access.
#
# Useful commands:
#   launchctl kickstart gui/$(id -u)/org.nixos.rustic-backups-jotta
#   launchctl kickstart -k gui/$(id -u)/org.nixos.rustic-backups-jotta
#   tail -f ~/Library/Logs/rustic-jotta.log
#   rustic -P jotta snapshots
{...}: let
  home = "/Users/kradalby";

  basePaths = [
    "${home}/git"
    "${home}/.ssh"
  ];

  # TCC-protected directories — require Full Disk Access granted to
  # ~/Applications/RusticBackup.app (see module header comment).
  fdaPaths = [
    "${home}/Desktop"
    "${home}/Documents"
    "${home}/Downloads"
  ];

  # ~/Library paths containing irreplaceable user data. All require
  # FDA since ~/Library is TCC-protected. Grouped by category.
  # See machines/krair/rustic.nix for detailed per-path comments.
  libraryPaths = [
    # Messaging
    "${home}/Library/Messages"
    "${home}/Library/Application Support/Signal"

    # Mail and accounts
    "${home}/Library/Mail"
    "${home}/Library/Accounts"

    # PIM — synced via iCloud but local backup is cheap insurance
    "${home}/Library/Group Containers/group.com.apple.notes"
    "${home}/Library/Group Containers/group.com.apple.calendar"
    "${home}/Library/Group Containers/group.com.apple.reminders"
    "${home}/Library/Application Support/AddressBook"

    # Security
    "${home}/Library/Keychains"

    # Browser
    "${home}/Library/Safari"

    # Automations
    "${home}/Library/Shortcuts"
  ];

  jottaPaths =
    basePaths
    ++ fdaPaths
    ++ libraryPaths
    ++ [
      "${home}/Pictures"
    ];
in {
  services.rustic.opServiceAccountTokenFile = "/Users/kradalby/.config/op/service-account-token";

  services.rustic.backups = {
    jotta = {
      # Jottacloud bucket ID for this host's restic repository.
      repository = "rclone:Jotta:4e8bb5107054b95e58d809060cb72911";

      # 1Password item "kratail2" in the dedicated Rustic vault.
      # Accessed via a read-only service account (see module docs).
      passwordCommand = ''op read "op://Rustic/kratail2/password"'';

      paths = jottaPaths;
      pruneOpts = {
        keep-daily = 7;
        keep-weekly = 5;
        keep-monthly = 12;
        keep-yearly = 75;
      };
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
