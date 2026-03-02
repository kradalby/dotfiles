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
      repository = "rclone:Jotta:4e8bb5107054b95e58d809060cb72911";

      # 1Password item: "restic - kratail" in the Private vault.
      passwordCommand = ''op read "op://Private/restic - kratail/password"'';

      paths = jottaPaths;
      pruneOpts = {
        keep-daily = 7;
        keep-weekly = 5;
        keep-monthly = 12;
        keep-yearly = 75;
      };
      pruneOnACOnly = true;
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
