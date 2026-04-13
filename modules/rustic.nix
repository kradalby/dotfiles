# Rustic backup module for macOS (nix-darwin).
#
# Manages periodic rustic backups via launchd user agents. Rustic is a
# Rust rewrite of restic, compatible with existing restic repositories,
# and notably lock-free (no unlock command needed).
#
# Key design decisions and gotchas:
#
# TOML profiles:
#   Rustic loads profiles with `-P <name>` from these search paths on
#   macOS: ~/Library/Application Support/rustic/, /etc/rustic/, ./
#   (NOT ~/.config/rustic/). We use environment.etc to place configs
#   in /etc/rustic/<name>.toml which is the most reliable path with
#   nix-darwin (home-manager's ~/Library/Application Support path had
#   issues).
#
# Full Disk Access (FDA):
#   macOS TCC protects ~/Desktop, ~/Documents, ~/Downloads, and others.
#   To back up these directories, the "responsible process" that
#   launchd spawns must have FDA granted.
#
#   TCC determines the responsible process by the actual Mach-O binary
#   that is running, NOT by the script path. Shell scripts (#!/bin/bash)
#   inside a .app are resolved to /bin/bash by TCC, so the .app's FDA
#   grant is never checked. This is why the .app entry point MUST be a
#   compiled binary — we use a small Go program (rustic-wrapper) that
#   handles wait-for-nix-store and flock, then fork+exec's bash with
#   the backup script. The Go binary stays alive as the parent process,
#   so TCC sees it (and the .app containing it) as the responsible
#   process. Child processes (bash, rustic, rclone) inherit the .app's
#   FDA grant through the TCC attribution chain — same mechanism that
#   makes Terminal.app work.
#
#   nix-darwin's `command` option always wraps in `/bin/sh -c ...`,
#   which would make /bin/sh the responsible process. FDA-enabled jobs
#   set serviceConfig.ProgramArguments directly to bypass this. The
#   ssh-agent-mux module demonstrates the same pattern.
#
#   We build a RusticBackup.app bundle with a stable bundle ID
#   (com.kradalby.rustic-backup) and copy it to ~/Applications/ via
#   an activation script. The stable path ensures the FDA grant
#   survives darwin-rebuild (Nix store paths change every rebuild).
#
# FDA setup (one-time, manual):
#   1. Run `darwin-rebuild switch --flake .#<hostname>`
#   2. Open System Settings > Privacy & Security > Full Disk Access
#   3. Click "+", navigate to ~/Applications/RusticBackup.app, add it
#   4. Verify with:
#        sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
#          "SELECT client, auth_value FROM access
#           WHERE service='kTCCServiceSystemPolicyAllFiles'
#             AND client='com.kradalby.rustic-backup'"
#      auth_value=2 means allowed, 0 means denied.
#
# .app bundle structure:
#   RusticBackup.app/
#     Contents/
#       Info.plist              — bundle ID: com.kradalby.rustic-backup
#       MacOS/
#         rustic-wrapper        — compiled Go binary (launchd entry point)
#
#   The bundle intentionally contains ONLY the Info.plist and the Go
#   wrapper binary. Per-job backup scripts live outside the bundle as
#   regular Nix store paths (see mkJobScript) and are passed to the
#   wrapper via launchd's ProgramArguments. Keeping scripts out of the
#   bundle means editing a backup config doesn't rewrite the bundle,
#   doesn't change its code signature, and doesn't invalidate the FDA
#   grant — only changes to rustic-wrapper itself do.
#
#   The Go wrapper (rustic-wrapper) is the launchd entry point. It:
#     1. Waits for /nix/store to appear (firmlink may be slow at boot)
#     2. Acquires an exclusive flock to prevent concurrent runs
#     3. fork+exec's /bin/bash with the backup script (/nix/store path)
#     4. Waits for the child, propagates exit code
#   The wrapper stays alive as the parent so TCC attributes all child
#   file access to the .app bundle. See pkgs/rustic-wrapper/main.go.
#
# Agents (per backup job):
#   rustic-backups-<name>   Incremental backup (hourly at :30 by default)
#   rustic-maint-<name>     forget+prune + metadata check (daily 03:00)
#   rustic-verify-<name>    check --read-data-subset (weekly Sunday 04:00)
#   rustic-check-<name>     Stale snapshot watchdog (daily 09:00, notifications)
#
# Useful commands:
#   # Trigger a backup manually:
#   launchctl kickstart gui/$(id -u)/org.nixos.rustic-backups-<name>
#
#   # Trigger maintenance manually:
#   launchctl kickstart gui/$(id -u)/org.nixos.rustic-maint-<name>
#
#   # Trigger deep verify manually:
#   launchctl kickstart gui/$(id -u)/org.nixos.rustic-verify-<name>
#
#   # Trigger watchdog check manually:
#   launchctl kickstart gui/$(id -u)/org.nixos.rustic-check-<name>
#
#   # Force restart (kills running instance first):
#   launchctl kickstart -k gui/$(id -u)/org.nixos.rustic-backups-<name>
#
#   # Check agent status (exit code in column 1):
#   launchctl list | grep rustic
#
#   # View logs:
#   tail -f ~/Library/Logs/rustic-<name>.log
#   tail -f ~/Library/Logs/rustic-maint-<name>.log
#   tail -f ~/Library/Logs/rustic-verify-<name>.log
#   tail -f ~/Library/Logs/rustic-check-<name>.log
#
#   # Check FDA grant status:
#   sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
#     "SELECT client, auth_value FROM access
#      WHERE service='kTCCServiceSystemPolicyAllFiles'
#        AND client='com.kradalby.rustic-backup'"
#
# Notifications (enableNotifications = true, default):
#   Failure: An ERR trap in backup/maintenance/verify scripts sends a
#     macOS notification via terminal-notifier when the script fails.
#     The notification uses the Basso sound and ignores Do Not Disturb.
#   Watchdog: A separate launchd agent (rustic-check-<name>) runs daily
#     at 09:00, queries the latest snapshot via `rustic snapshots --json`,
#     and sends escalating notifications based on snapshot age:
#       >= 1 day:   info (no sound)
#       >= 5 days:  warning (Basso sound)
#       >= 10 days: critical (Sosumi sound, ignores DnD)
#     The watchdog doesn't need FDA (only queries the repo metadata).
#
# Paths (all must be absolute — rustic's TOML parser does NOT expand $HOME):
#   Config:          /etc/rustic/<name>.toml
#   App:             ~/Applications/RusticBackup.app
#   Logs (backup):   ~/Library/Logs/rustic-<name>.log
#   Logs (maint):    ~/Library/Logs/rustic-maint-<name>.log
#   Logs (verify):   ~/Library/Logs/rustic-verify-<name>.log
#   Logs (watchdog): ~/Library/Logs/rustic-check-<name>.log
#   Lock (backup):   /tmp/rustic_<name>.lockfile
#   Lock (maint):    /tmp/rustic_maint_<name>.lockfile
#   Lock (verify):   /tmp/rustic_verify_<name>.lockfile
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.rustic;

  # Generate a rustic TOML profile for a backup job.
  # Placed in /etc/rustic/<name>.toml via environment.etc and loaded
  # by rustic with `-P <name>`.
  mkProfile = name: backup: let
    # Build the repository section
    repositorySection =
      {
        repository = backup.repository;
      }
      // optionalAttrs (backup.passwordCommand != null) {
        password-command = backup.passwordCommand;
      }
      // optionalAttrs (backup.passwordFile != null) {
        password-file = backup.passwordFile;
      };

    # Build the forget section from pruneOpts
    forgetSection =
      backup.pruneOpts
      // {
        prune = true;
      };

    # Build the full config (recursiveUpdate so extraConfig
    # can add keys to backup/forget without overwriting them)
    profileConfig =
      recursiveUpdate
      {
        repository = repositorySection;
        backup = {
          init = backup.initialize;
          snapshots = [
            {
              sources = backup.paths;
            }
          ];
        };
        forget = forgetSection;
      }
      backup.extraConfig;
  in
    (pkgs.formats.toml {}).generate "rustic-${name}.toml" profileConfig;

  # Stable .app bundle path for Full Disk Access.
  # Must live outside the Nix store at a fixed path so the macOS FDA
  # grant (tied to bundle ID + path) survives darwin-rebuild. The
  # activation script copies the built .app here on every switch.
  fdaAppPath = "${cfg.fdaAppDir}/RusticBackup.app";

  # ERR trap snippet for scripts. Sends a macOS notification
  # via terminal-notifier when the script exits due to an error.
  # Only included when enableNotifications is true.
  # `label` controls the notification title (e.g. "Backup", "Maintenance", "Verify").
  mkErrTrap = name: label:
    optionalString cfg.enableNotifications ''
      trap '${pkgs.terminal-notifier}/bin/terminal-notifier \
        -title "${label} Failed" \
        -message "rustic ${toLower label} ${name} failed at $(date)" \
        -sound Basso \
        -group "rustic-${name}-${toLower label}" \
        -ignoreDnD' ERR
    '';

  # Common preamble shared by backup, maintenance, and verify scripts.
  # Sets strict mode, ERR trap, 1Password token, and PATH.
  mkScriptPreamble = name: label: ''
    set -euo pipefail
    ${mkErrTrap name label}

    ${optionalString (cfg.opServiceAccountTokenFile != null) ''
      export OP_SERVICE_ACCOUNT_TOKEN="$(cat ${cfg.opServiceAccountTokenFile})"
    ''}
    export PATH="${lib.makeBinPath [pkgs.rclone pkgs._1password-cli]}:$PATH"
  '';

  # AC power guard — exits 0 (not an error) when on battery so the
  # ERR trap doesn't fire and no failure notification is sent.
  mkACGuard = label: ''
    if ! pmset -g ps | grep -q "AC Power"; then
      echo "On battery, skipping ${toLower label}"
      exit 0
    fi
  '';

  # Generate the per-job backup script as a standalone writeBash
  # derivation in the Nix store. Referenced directly by launchd via
  # ProgramArguments (FDA path) or wrapped in a flock runner (non-FDA
  # fallback). The script does NOT live inside the FDA .app bundle,
  # so editing a backup config doesn't rewrite the bundle and doesn't
  # invalidate the Full Disk Access grant.
  #
  # The compiled Go wrapper (rustic-wrapper) inside the bundle receives
  # this path as argv[1] and exec's /bin/bash on it. TCC attribution
  # flows from the wrapper (the .app's main executable) to the child
  # bash/rustic/rclone processes regardless of where the script lives
  # on disk.
  mkJobScript = name: _backup: let
    rusticBin = "${pkgs.rustic}/bin/rustic";
  in
    pkgs.writers.writeBash "rustic-backup-${name}" ''
      ${mkScriptPreamble name "Backup"}

      echo "=== rustic backup ${name} started at $(date) ==="
      ${rusticBin} -P ${name} backup
      echo "=== rustic backup ${name} finished at $(date) ==="
    '';

  # Daily maintenance script: forget+prune and metadata check.
  # Runs on its own schedule, separate from the backup agent.
  mkMaintenanceScript = name: backup: let
    rusticBin = "${pkgs.rustic}/bin/rustic";
  in
    pkgs.writers.writeBash "rustic-maint-${name}" ''
      ${mkScriptPreamble name "Maintenance"}

      echo "=== rustic maintenance ${name} started at $(date) ==="
      ${optionalString backup.maintenanceOnACOnly (mkACGuard "maintenance")}

      ${rusticBin} -P ${name} forget
      ${rusticBin} -P ${name} check

      echo "=== rustic maintenance ${name} finished at $(date) ==="
    '';

  # Weekly deep verification script: check --read-data-subset.
  # Verifies actual data integrity over time.
  mkVerifyScript = name: backup: let
    rusticBin = "${pkgs.rustic}/bin/rustic";
  in
    pkgs.writers.writeBash "rustic-verify-${name}" ''
      ${mkScriptPreamble name "Verify"}

      echo "=== rustic verify ${name} started at $(date) ==="
      ${optionalString backup.maintenanceOnACOnly (mkACGuard "verify")}

      ${rusticBin} -P ${name} check --read-data-subset ${backup.deepCheckSubset}

      echo "=== rustic verify ${name} finished at $(date) ==="
    '';

  # Generate a stale backup watchdog script for a backup job.
  # Queries the latest snapshot via `rustic snapshots --json`, computes
  # the age in days, and sends escalating notifications:
  #   >= 1 day:  info (no sound)
  #   >= 5 days: warning (Basso sound)
  #   >= 10 days: critical (Sosumi sound, ignores Do Not Disturb)
  mkWatchdogScript = name: _backup: let
    rusticBin = "${pkgs.rustic}/bin/rustic";
    notifier = "${pkgs.terminal-notifier}/bin/terminal-notifier";
    jq = "${pkgs.jq}/bin/jq";
  in
    pkgs.writers.writeBash "rustic-check-${name}" ''
      set -euo pipefail

      ${optionalString (cfg.opServiceAccountTokenFile != null) ''
        export OP_SERVICE_ACCOUNT_TOKEN="$(cat ${cfg.opServiceAccountTokenFile})"
      ''}
      export PATH="${lib.makeBinPath [pkgs.rclone pkgs._1password-cli]}:$PATH"

      echo "=== rustic-check ${name} started at $(date) ==="

      # Get latest snapshot time from rustic JSON output.
      # rustic snapshots --json groups results: the top-level array
      # contains objects with {group_key, snapshots: [...]}, and each
      # nested snapshot has a "time" field in RFC3339 format. Flatten
      # across all groups and take the most recent.
      latest=$(${rusticBin} -P ${name} snapshots --json \
        | ${jq} -r '[.[].snapshots[].time] | sort | last // empty')

      if [ -z "$latest" ]; then
        ${notifier} \
          -title "Backup Missing" \
          -message "No snapshots found for rustic backup ${name}" \
          -sound Sosumi \
          -group "rustic-check-${name}" \
          -ignoreDnD
        echo "ERROR: no snapshots found"
        exit 1
      fi

      # Compute age in days. Use /bin/date explicitly so we get BSD
      # date with its -jf parser, not GNU date from nix coreutils
      # (which may be on PATH when the script is invoked manually).
      # Strip sub-second precision and timezone offset for compatibility.
      snapshot_epoch=$(/bin/date -jf "%Y-%m-%dT%H:%M:%S" "$(echo "$latest" | sed 's/\.[0-9]*[-+].*//')" +%s 2>/dev/null || /bin/date -jf "%Y-%m-%dT%H:%M:%SZ" "$(echo "$latest" | sed 's/\.[0-9]*//')" +%s)
      now_epoch=$(/bin/date +%s)
      age_days=$(( (now_epoch - snapshot_epoch) / 86400 ))

      echo "Latest snapshot: $latest (''${age_days}d ago)"

      if [ "$age_days" -ge 10 ]; then
        ${notifier} \
          -title "Backup Critical" \
          -message "rustic ${name}: last backup ''${age_days} days ago" \
          -sound Sosumi \
          -group "rustic-check-${name}" \
          -ignoreDnD
      elif [ "$age_days" -ge 5 ]; then
        ${notifier} \
          -title "Backup Warning" \
          -message "rustic ${name}: last backup ''${age_days} days ago" \
          -sound Basso \
          -group "rustic-check-${name}"
      elif [ "$age_days" -ge 1 ]; then
        ${notifier} \
          -title "Backup Stale" \
          -message "rustic ${name}: last backup ''${age_days} days ago" \
          -group "rustic-check-${name}"
      else
        echo "Backup is fresh (''${age_days}d old), no notification needed"
      fi

      echo "=== rustic-check ${name} finished at $(date) ==="
    '';

  # Build the .app bundle derivation. Contains only Info.plist (with
  # the stable bundle ID that FDA is granted to) and the compiled Go
  # wrapper binary. Backup scripts live outside the bundle in the Nix
  # store (see mkJobScript above) so editing a backup config doesn't
  # rewrite the bundle and doesn't invalidate the FDA grant.
  #
  # Built in the Nix store, then copied to ~/Applications/ by the
  # activation script so the path stays stable across rebuilds.
  #
  # LSUIElement=true hides the app from the Dock.
  # CFBundleExecutable points to the compiled Go binary, not a script,
  # so macOS TCC correctly attributes file access to the .app bundle.
  mkFdaApp = pkgs.stdenv.mkDerivation {
    name = "rustic-backup-app";
    buildCommand = ''
      mkdir -p $out/RusticBackup.app/Contents/MacOS

      cat > $out/RusticBackup.app/Contents/Info.plist <<'PLIST'
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleIdentifier</key>
        <string>com.kradalby.rustic-backup</string>
        <key>CFBundleName</key>
        <string>RusticBackup</string>
        <key>CFBundleExecutable</key>
        <string>rustic-wrapper</string>
        <key>CFBundleVersion</key>
        <string>1.0</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>LSUIElement</key>
        <true/>
      </dict>
      </plist>
      PLIST

      # Copy the compiled Go wrapper binary into the .app bundle.
      # This Mach-O binary is the launchd entry point — TCC sees it
      # as the responsible process for FDA checks.
      cp ${pkgs.rustic-wrapper}/bin/rustic-wrapper \
        $out/RusticBackup.app/Contents/MacOS/rustic-wrapper
      chmod +x $out/RusticBackup.app/Contents/MacOS/rustic-wrapper
    '';
  };

  # Interactive setup script for 1Password service account.
  # Guides the operator through creating a read-only service account,
  # saving the token, and verifying access. Added to PATH when
  # opServiceAccountTokenFile is configured.
  mkSetupScript = let
    itemInfo = concatStringsSep "\n" (mapAttrsToList (name: backup:
        optionalString (backup.passwordCommand != null)
        "echo ${escapeShellArg "  ${name}: ${backup.passwordCommand}"}")
      cfg.backups);

    verificationCommands = concatStringsSep "\n" (mapAttrsToList (name: backup:
        optionalString (backup.passwordCommand != null) ''
          echo "  Testing backup '${name}'..."
          if ${backup.passwordCommand} &>/dev/null; then
            echo "    OK"
          else
            echo "    FAILED"
            VERIFY_FAILED=1
          fi
        '')
      cfg.backups);
  in
    pkgs.writeShellApplication {
      name = "rustic-setup-op";
      runtimeInputs = [pkgs._1password-cli];
      text = ''
        VAULT_NAME=${escapeShellArg cfg.opVault}
        TOKEN_FILE=${escapeShellArg cfg.opServiceAccountTokenFile}
        EXPECTED_USER=${escapeShellArg cfg.user}
        HOSTNAME="$(hostname -s)"
        SA_NAME="rustic-backup-$HOSTNAME"

        echo "=== Rustic Backup — 1Password Service Account Setup ==="
        echo ""
        echo "  Vault:           $VAULT_NAME"
        echo "  Token file:      $TOKEN_FILE"
        echo "  Service account: $SA_NAME"
        echo ""

        # Check user
        CURRENT_USER="$(whoami)"
        if [ "$CURRENT_USER" != "$EXPECTED_USER" ]; then
          echo "ERROR: Must be run as $EXPECTED_USER (currently $CURRENT_USER)"
          exit 1
        fi
        echo "Running as $EXPECTED_USER."

        # Check op CLI signed in
        if ! op account list &>/dev/null; then
          echo "ERROR: Not signed in to 1Password CLI."
          echo "  Sign in first: eval \$(op signin)"
          exit 1
        fi
        echo "1Password CLI signed in."

        # Check vault exists
        if ! op vault get "$VAULT_NAME" &>/dev/null 2>&1; then
          echo "ERROR: Vault '$VAULT_NAME' does not exist."
          echo "  Create it in 1Password first, then re-run this script."
          exit 1
        fi
        echo "Vault '$VAULT_NAME' exists."
        echo ""

        # Show configured password commands
        echo "Configured password commands:"
        ${itemInfo}
        echo ""
        echo "Make sure the corresponding items exist in the"
        echo "'$VAULT_NAME' vault before continuing."
        echo ""
        read -rp "Press Enter to continue, or Ctrl-C to abort..."
        echo ""

        # Create service account
        echo "Creating service account '$SA_NAME' with"
        echo "read_items access to '$VAULT_NAME'..."
        echo ""
        read -rp "Continue? [y/N] "
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          TOKEN="$(op service-account create "$SA_NAME" \
            --vault "$VAULT_NAME:read_items" --raw)"
          echo ""
          echo "Service account created."
        else
          echo "Aborted."
          exit 1
        fi
        echo ""

        # Save token
        echo "Saving token to $TOKEN_FILE..."
        mkdir -p "$(dirname "$TOKEN_FILE")"
        printf '%s\n' "$TOKEN" > "$TOKEN_FILE"
        chmod 600 "$TOKEN_FILE"
        echo "Token saved (mode 600)."
        echo ""
        echo "IMPORTANT: Save this token in 1Password via the GUI now."
        echo "It cannot be retrieved again."
        echo ""
        read -rp "Press Enter after saving the token..."
        echo ""

        # Verify
        echo "Verifying service account access..."
        VERIFY_FAILED=0
        export OP_SERVICE_ACCOUNT_TOKEN
        OP_SERVICE_ACCOUNT_TOKEN="$(cat "$TOKEN_FILE")"

        ${verificationCommands}

        if [ "$VERIFY_FAILED" -eq 1 ]; then
          echo ""
          echo "Some verifications failed. Check vault and item names."
          exit 1
        fi

        echo ""
        echo "=== Setup complete ==="
        echo ""
        echo "Next steps:"
        echo "  1. darwin-rebuild switch --flake .#$HOSTNAME"
        echo "  2. Test: launchctl kickstart gui/\$(id -u)/org.nixos.rustic-backups-jotta"
        echo "  3. Logs: tail -f ~/Library/Logs/rustic-jotta.log"
      '';
    };
in {
  options.services.rustic = {
    backups = mkOption {
      description = ''
        Periodic backups to create with rustic.

        Each backup job creates a launchd user agent that runs on the
        configured schedule. To trigger a job manually:

          launchctl kickstart gui/$(id -u)/org.nixos.rustic-backups-<name>

        Logs are written to the configured logPath (default ~/Library/Logs).
      '';
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          repository = mkOption {
            type = types.str;
            description = ''
              Repository to backup to. Supports rclone remotes
              (e.g. rclone:Jotta:bucket), REST servers, local paths,
              and OpenDAL backends.
            '';
            example = "rclone:Jotta:my-backup-bucket";
          };

          passwordCommand = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Command to retrieve the repository password.
              Useful for 1Password CLI integration.
            '';
            example = ''op read "op://Rustic/myhost/password"'';
          };

          passwordFile = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Read the repository password from a file.
              Used with agenix/ragenix secrets.
            '';
            example = "/run/agenix/restic-password";
          };

          paths = mkOption {
            type = types.listOf types.str;
            description = ''
              Directories to back up.
            '';
            example = ["/Users/kradalby/git" "/Users/kradalby/Pictures"];
          };

          pruneOpts = mkOption {
            type = types.attrsOf types.int;
            default = {
              keep-daily = 7;
              keep-weekly = 5;
              keep-monthly = 12;
              keep-yearly = 75;
            };
            description = ''
              Retention policy for rustic forget --prune.
            '';
          };

          initialize = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Automatically initialize the repository on first backup.
            '';
          };

          calendarInterval = mkOption {
            type = types.attrsOf types.int;
            default = {Minute = 30;};
            description = ''
              When to run the backup. Maps to launchd StartCalendarInterval.
              An empty attrset means every minute. Omitted fields are wildcards.
            '';
            example = {
              Hour = 2;
              Minute = 0;
            };
          };

          logPath = mkOption {
            type = types.str;
            default = "/Users/kradalby/Library/Logs";
            description = ''
              Directory for backup log files.
            '';
          };

          maintenanceOnACOnly = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Only run maintenance (forget+prune, check) and deep
              verification when on AC power. Saves battery on laptops.
            '';
          };

          maintenanceCalendarInterval = mkOption {
            type = types.attrsOf types.int;
            default = {
              Hour = 3;
              Minute = 0;
            };
            description = ''
              When to run maintenance (forget+prune, metadata check).
              Maps to launchd StartCalendarInterval. Default: daily at 03:00.
            '';
          };

          verifyCalendarInterval = mkOption {
            type = types.attrsOf types.int;
            default = {
              Weekday = 0;
              Hour = 4;
              Minute = 0;
            };
            description = ''
              When to run deep data verification (check --read-data-subset).
              Maps to launchd StartCalendarInterval. Default: Sunday at 04:00.
            '';
          };

          deepCheckSubset = mkOption {
            type = types.str;
            default = "1/7";
            description = ''
              Subset specification for `rustic check --read-data-subset`.
              Format: N/M means check 1/M-th of data each run. With
              weekly runs and "1/7", full coverage every 7 weeks.
            '';
          };

          enableFDA = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Route the backup through a wrapper .app bundle so
              it can be granted Full Disk Access in System Settings.
              The .app is the direct launchd entry point so macOS
              sees it as the responsible process for TCC checks.
              After the first darwin-rebuild switch, manually add
              the .app to System Settings > Privacy & Security >
              Full Disk Access.
            '';
          };

          extraConfig = mkOption {
            type = types.attrs;
            default = {};
            description = ''
              Extra attributes merged into the generated rustic TOML
              profile. Use this for advanced options like hooks,
              excludes, tags, or backend-specific settings.
            '';
            example = {
              backup = {
                exclude-if-present = [".nobackup" "CACHEDIR.TAG"];
                git-ignore = true;
              };
            };
          };
        };
      }));
      default = {};
    };

    enableNotifications = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable failure notifications and stale backup watchdog.
        When true, backup scripts get an ERR trap that sends a
        macOS notification via terminal-notifier on failure, and
        a separate watchdog launchd agent checks snapshot freshness
        daily and sends escalating notifications for stale backups.
      '';
    };

    fdaAppDir = mkOption {
      type = types.str;
      default = "/Users/kradalby/Applications";
      description = ''
        Directory where the RusticBackup.app wrapper is installed.
        This .app must be granted Full Disk Access in System Settings
        to allow rustic to read TCC-protected directories.
      '';
    };

    opServiceAccountTokenFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Path to a file containing a 1Password service account token.
        When set, OP_SERVICE_ACCOUNT_TOKEN is exported in all backup
        and watchdog scripts, enabling non-interactive `op` CLI access
        without requiring the 1Password GUI app to be signed in.

        Create a service account with read-only access to a dedicated
        vault containing only the backup repository passwords:
          op service-account create <name> --vault <vault>:read_items --raw

        Note: service accounts cannot access the built-in Personal,
        Private, or Employee vaults — use a dedicated vault.
      '';
      example = "/Users/kradalby/.config/op/service-account-token";
    };

    opVault = mkOption {
      type = types.str;
      default = "Rustic";
      description = ''
        Name of the 1Password vault containing backup repository
        passwords. Used by the rustic-setup-op setup script and
        should match the vault referenced in each backup's
        passwordCommand.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "kradalby";
      description = ''
        The user account that runs the backup agents. The setup
        script verifies it is run as this user.
      '';
    };
  };

  config = mkIf (cfg.backups != {}) {
    # Ensure rustic and rclone are available system-wide.
    # The FDA wrapper resolves rustic via /run/current-system/sw/bin/rustic.
    environment.systemPackages =
      [
        pkgs.rustic
        pkgs.rclone
      ]
      ++ optional (cfg.opServiceAccountTokenFile != null) mkSetupScript;

    # Install the FDA wrapper .app via activation script so it
    # persists across rebuilds at a stable path.
    system.activationScripts.postActivation.text = let
      anyFDA = any (b: b.enableFDA) (attrValues cfg.backups);
      sourceApp = "${mkFdaApp}/RusticBackup.app";
      # Marker file lives next to the bundle, not inside it. If it
      # were inside, codesign would either hash it (breaking the
      # "bit-identical re-signature" property) or complain about an
      # untracked file during codesign --verify.
      sourceMarker = "${fdaAppPath}.nix-source";
    in
      optionalString anyFDA ''
        # Only reinstall when the source .app in the Nix store has
        # actually changed. The source store path is effectively a
        # content hash; if it matches the marker, nothing has changed
        # and we skip the copy + codesign entirely. Re-signing on
        # every switch churns the code identity and makes macOS
        # re-prompt for Full Disk Access, which is what we want to
        # avoid.
        if [ -d "${fdaAppPath}" ] \
           && [ "$(cat ${sourceMarker} 2>/dev/null)" = "${sourceApp}" ]; then
          echo "RusticBackup.app up to date (${sourceApp}), skipping reinstall"
        else
          echo "installing RusticBackup.app FDA wrapper..."
          mkdir -p "${cfg.fdaAppDir}"
          rm -rf "${fdaAppPath}"
          cp -R "${sourceApp}" "${fdaAppPath}"
          chmod -R u+w "${fdaAppPath}"
          chown -R kradalby:staff "${fdaAppPath}"

          # Code sign the .app with a stable identifier matching the
          # bundle ID. Without this, TCC's csreq (code signing requirement)
          # check fails because the ad-hoc signature from the Nix store
          # build doesn't produce a consistent identity after copying.
          # The --identifier flag ensures the code identity is always
          # com.kradalby.rustic-backup, so the FDA grant's csreq matches
          # across rebuilds even when the underlying binary changes.
          /usr/bin/codesign --force --deep --sign - \
            --identifier com.kradalby.rustic-backup \
            "${fdaAppPath}"

          # Record the source store path so the next activation can
          # short-circuit when nothing has changed.
          printf '%s\n' "${sourceApp}" > "${sourceMarker}"
        fi

        # Check if FDA is granted (informational only)
        if ! sqlite3 \
          "/Library/Application Support/com.apple.TCC/TCC.db" \
          "SELECT client FROM access WHERE service='kTCCServiceSystemPolicyAllFiles' AND client='com.kradalby.rustic-backup'" 2>/dev/null \
          | grep -q rustic; then
          echo ""
          echo "NOTE: Grant Full Disk Access to RusticBackup.app in"
          echo "  System Settings > Privacy & Security > Full Disk Access"
          echo "  Path: ${fdaAppPath}"
          echo ""
        fi
      '';

    # Helper to build a launchd agent for a given script. Handles
    # the FDA vs non-FDA split in one place instead of duplicating it
    # for each agent type (backup, maintenance, verify).
    launchd.user.agents = let
      mkAgent = {
        agentName,
        script,
        lockFile,
        calendarInterval,
        logPrefix,
        backup,
        runAtLoad ? false,
      }: let
        wrapperBin = "${fdaAppPath}/Contents/MacOS/rustic-wrapper";
        fallbackRunScript = pkgs.writers.writeBash "run-${agentName}" ''
          ${pkgs.flock}/bin/flock -n ${lockFile} ${script}
        '';
        commonConfig =
          {
            Disabled = false;
            StartCalendarInterval = [calendarInterval];
            ProcessType = "Background";
            LowPriorityIO = true;
            StandardOutPath = "${backup.logPath}/${logPrefix}.log";
            StandardErrorPath = "${backup.logPath}/${logPrefix}-error.log";
          }
          // optionalAttrs runAtLoad {RunAtLoad = true;};
      in
        nameValuePair agentName (
          if backup.enableFDA
          then {
            serviceConfig =
              commonConfig
              // {
                ProgramArguments = [wrapperBin script lockFile];
              };
          }
          else {
            command = "${fallbackRunScript}";
            serviceConfig = commonConfig;
          }
        );
    in
      # Backup agents — one per backup job, runs on calendarInterval.
      (mapAttrs'
        (name: backup:
          mkAgent {
            agentName = "rustic-backups-${name}";
            script = "${mkJobScript name backup}";
            lockFile = "/tmp/rustic_${name}.lockfile";
            calendarInterval = backup.calendarInterval;
            logPrefix = "rustic-${name}";
            inherit backup;
            runAtLoad = true;
          })
        cfg.backups)
      # Maintenance agents — daily forget+prune and metadata check.
      // (mapAttrs'
        (name: backup:
          mkAgent {
            agentName = "rustic-maint-${name}";
            script = "${mkMaintenanceScript name backup}";
            lockFile = "/tmp/rustic_maint_${name}.lockfile";
            calendarInterval = backup.maintenanceCalendarInterval;
            logPrefix = "rustic-maint-${name}";
            inherit backup;
          })
        cfg.backups)
      # Verify agents — weekly deep data integrity check.
      // (mapAttrs'
        (name: backup:
          mkAgent {
            agentName = "rustic-verify-${name}";
            script = "${mkVerifyScript name backup}";
            lockFile = "/tmp/rustic_verify_${name}.lockfile";
            calendarInterval = backup.verifyCalendarInterval;
            logPrefix = "rustic-verify-${name}";
            inherit backup;
          })
        cfg.backups)
      # Stale backup watchdog agents — one per backup job.
      # Runs daily at 09:00, checks latest snapshot age, and sends
      # escalating notifications via terminal-notifier.
      // (optionalAttrs cfg.enableNotifications
        (mapAttrs'
          (name: backup:
            nameValuePair "rustic-check-${name}" {
              command = "${mkWatchdogScript name backup}";
              serviceConfig = {
                Disabled = false;
                StartCalendarInterval = [
                  {
                    Hour = 9;
                    Minute = 0;
                  }
                ];
                ProcessType = "Background";
                StandardOutPath = "${backup.logPath}/rustic-check-${name}.log";
                StandardErrorPath = "${backup.logPath}/rustic-check-${name}-error.log";
              };
            })
          cfg.backups));

    # TOML profiles in /etc/rustic/ (one of rustic's default search
    # paths) plus newsyslog rotation configs, merged into one etc block.
    environment.etc =
      (mapAttrs'
        (name: backup:
          nameValuePair "rustic/${name}.toml" {
            source = mkProfile name backup;
          })
        cfg.backups)
      // (mapAttrs'
        (name: backup:
          nameValuePair "newsyslog.d/rustic-${name}.conf" {
            text = ''
              # logfilename                                [owner:group]   mode   count   size   when  flags
              ${backup.logPath}/rustic-${name}.log         kradalby:staff      750    10      10240  *     NJ
              ${backup.logPath}/rustic-${name}-error.log   kradalby:staff      750    10      10240  *     NJ

            '';
          })
        cfg.backups)
      // (mapAttrs'
        (name: backup:
          nameValuePair "newsyslog.d/rustic-maint-${name}.conf" {
            text = ''
              # logfilename                                      [owner:group]   mode   count   size   when  flags
              ${backup.logPath}/rustic-maint-${name}.log         kradalby:staff      750    10      10240  *     NJ
              ${backup.logPath}/rustic-maint-${name}-error.log   kradalby:staff      750    10      10240  *     NJ

            '';
          })
        cfg.backups)
      // (mapAttrs'
        (name: backup:
          nameValuePair "newsyslog.d/rustic-verify-${name}.conf" {
            text = ''
              # logfilename                                       [owner:group]   mode   count   size   when  flags
              ${backup.logPath}/rustic-verify-${name}.log         kradalby:staff      750    10      10240  *     NJ
              ${backup.logPath}/rustic-verify-${name}-error.log   kradalby:staff      750    10      10240  *     NJ

            '';
          })
        cfg.backups)
      // (optionalAttrs cfg.enableNotifications
        (mapAttrs'
          (name: backup:
            nameValuePair "newsyslog.d/rustic-check-${name}.conf" {
              text = ''
                # logfilename                                     [owner:group]   mode   count   size   when  flags
                ${backup.logPath}/rustic-check-${name}.log        kradalby:staff      750    10      10240  *     NJ
                ${backup.logPath}/rustic-check-${name}-error.log  kradalby:staff      750    10      10240  *     NJ

              '';
            })
          cfg.backups));
  };
}
