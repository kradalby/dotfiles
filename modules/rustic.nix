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
#   To back up these directories, the process that launchd directly
#   spawns must have FDA. macOS checks the "responsible process" — the
#   binary that launchd.plist's ProgramArguments[0] points to.
#
#   nix-darwin's `command` option always wraps in `/bin/sh -c
#   "/bin/wait4path /nix/store && exec ..."`, making /bin/sh the
#   responsible process (which can't be granted FDA). To avoid this,
#   FDA-enabled jobs set serviceConfig.ProgramArguments directly,
#   bypassing the /bin/sh wrapper. The ssh-agent-mux module
#   demonstrates this same pattern.
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
#         rustic-backup         — default executable, delegates to rustic
#         backup-<name>         — per-job script (launchd entry point)
#
#   Each backup-<name> script is a single self-contained bash script
#   that does everything: wait for Nix store, acquire flock, run
#   backup, forget/prune/check. The script must NEVER exec into
#   another binary (flock, rustic, etc.) because that replaces the
#   process image and macOS TCC will attribute file access to that
#   binary instead of the .app. We use flock's file-descriptor mode
#   (`exec <fd>>/tmp/lockfile; flock -n <fd>`) which locks without
#   replacing the process.
#
# Useful commands:
#   # Trigger a backup manually:
#   launchctl kickstart gui/$(id -u)/org.nixos.rustic-backups-<name>
#
#   # Force restart (kills running instance first):
#   launchctl kickstart -k gui/$(id -u)/org.nixos.rustic-backups-<name>
#
#   # Check agent status (exit code in column 1):
#   launchctl list | grep rustic
#
#   # View logs:
#   tail -f ~/Library/Logs/rustic-<name>.log
#   tail -f ~/Library/Logs/rustic-<name>-error.log
#
#   # Check FDA grant status:
#   sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
#     "SELECT client, auth_value FROM access
#      WHERE service='kTCCServiceSystemPolicyAllFiles'
#        AND client='com.kradalby.rustic-backup'"
#
# Paths (all must be absolute — rustic's TOML parser does NOT expand $HOME):
#   Config:  /etc/rustic/<name>.toml
#   App:     ~/Applications/RusticBackup.app
#   Logs:    ~/Library/Logs/rustic-<name>.log
#   Lock:    /tmp/rustic_<name>.lockfile
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

  # Generate the per-job script (backup-<name>).
  # This is the direct launchd entry point — ProgramArguments[0]
  # points here. Because it lives inside the .app bundle, macOS
  # TCC sees the .app as the "responsible process" for FDA checks.
  #
  # IMPORTANT: This script must NOT exec into another binary (e.g.
  # flock, rustic). If it does, the process image changes and macOS
  # TCC will attribute file access to that binary instead of the
  # .app. We use flock's file-descriptor mode (flock <fd>) to
  # acquire the lock without replacing the process.
  #
  # Uses /run/current-system/sw so the rustic binary can be updated
  # by darwin-rebuild without changing the .app or invalidating the
  # FDA grant.
  mkJobScript = name: backup: let
    rusticBin = "/run/current-system/sw/bin/rustic";
  in ''
    #!/bin/bash
    set -euo pipefail

    # Wait for the Nix store firmlink (may not be ready at early boot)
    /bin/wait4path /nix/store

    export PATH="${lib.makeBinPath [pkgs.rclone pkgs._1password-cli]}:$PATH"

    # Prevent concurrent runs using flock on a file descriptor.
    # We intentionally avoid `exec flock ... <command>` or `flock ... <command>`
    # because both replace or spawn a new process image, causing macOS
    # TCC to attribute file access to flock instead of the .app.
    exec 200>/tmp/rustic_${name}.lockfile
    if ! ${pkgs.flock}/bin/flock -n 200; then
      echo "Another backup is already running, skipping"
      exit 0
    fi

    echo "=== rustic backup ${name} started at $(date) ==="

    # Run backup
    ${rusticBin} -P ${name} backup

    # Forget/prune/check (optionally only on AC power)
    ${
      if backup.pruneOnACOnly
      then ''
        if pmset -g ps | grep -q "AC Power"; then
          echo "On AC power, running forget + check..."
          ${rusticBin} -P ${name} forget
          ${rusticBin} -P ${name} check
        else
          echo "On battery, skipping forget + check"
        fi
      ''
      else ''
        ${rusticBin} -P ${name} forget
        ${rusticBin} -P ${name} check
      ''
    }

    echo "=== rustic backup ${name} finished at $(date) ==="
  '';

  # Build the .app bundle derivation. Contains Info.plist (with the
  # stable bundle ID that FDA is granted to) and per-job scripts.
  # Built in the Nix store, then copied to ~/Applications/ by the
  # activation script so the path stays stable across rebuilds.
  #
  # LSUIElement=true hides the app from the Dock.
  mkFdaApp = pkgs.stdenv.mkDerivation {
    name = "rustic-backup-app";
    buildCommand = let
      jobs = filterAttrs (_: b: b.enableFDA) cfg.backups;
    in ''
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
        <string>rustic-backup</string>
        <key>CFBundleVersion</key>
        <string>1.0</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>LSUIElement</key>
        <true/>
      </dict>
      </plist>
      PLIST

      # Default executable -- just delegates to rustic
      cat > $out/RusticBackup.app/Contents/MacOS/rustic-backup <<'SCRIPT'
      #!/bin/bash
      /bin/wait4path /nix/store
      exec /run/current-system/sw/bin/rustic "$@"
      SCRIPT
      chmod +x $out/RusticBackup.app/Contents/MacOS/rustic-backup

      ${concatStringsSep "\n" (mapAttrsToList (name: backup: ''
          # Job script for "${name}" -- launchd entry point
          cat > $out/RusticBackup.app/Contents/MacOS/backup-${name} <<'JOBSCRIPT'
          ${mkJobScript name backup}
          JOBSCRIPT
          chmod +x $out/RusticBackup.app/Contents/MacOS/backup-${name}
        '')
        jobs)}
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
            example = ''op read "op://Private/restic/password"'';
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

          pruneOnACOnly = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Only run forget/prune/check when on AC power.
              Saves battery on laptops.
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

    fdaAppDir = mkOption {
      type = types.str;
      default = "/Users/kradalby/Applications";
      description = ''
        Directory where the RusticBackup.app wrapper is installed.
        This .app must be granted Full Disk Access in System Settings
        to allow rustic to read TCC-protected directories.
      '';
    };
  };

  config = mkIf (cfg.backups != {}) {
    # Ensure rustic and rclone are available system-wide.
    # The FDA wrapper resolves rustic via /run/current-system/sw/bin/rustic.
    environment.systemPackages = [
      pkgs.rustic
      pkgs.rclone
    ];

    # Install the FDA wrapper .app via activation script so it
    # persists across rebuilds at a stable path.
    system.activationScripts.postActivation.text = let
      anyFDA = any (b: b.enableFDA) (attrValues cfg.backups);
    in
      optionalString anyFDA ''
        echo "installing RusticBackup.app FDA wrapper..."
        mkdir -p "${cfg.fdaAppDir}"
        rm -rf "${fdaAppPath}"
        cp -R "${mkFdaApp}/RusticBackup.app" "${fdaAppPath}"
        chmod -R u+w "${fdaAppPath}"
        chown -R kradalby:staff "${fdaAppPath}"

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

    # Generate a launchd user agent for each backup job.
    # For FDA-enabled jobs, launchd runs the .app binary directly
    # (no /bin/sh wrapper) so macOS sees the .app as the responsible
    # process for TCC checks.
    launchd.user.agents =
      mapAttrs'
      (name: backup: let
        fdaJobBin = "${fdaAppPath}/Contents/MacOS/backup-${name}";

        # Non-FDA fallback: use a regular bash script with fd-based flock
        fallbackScript = pkgs.writers.writeBash "rustic-backup-${name}" ''
          set -euo pipefail

          export PATH="${lib.makeBinPath [pkgs.rclone pkgs._1password-cli]}:$PATH"

          exec 200>/tmp/rustic_${name}.lockfile
          if ! ${pkgs.flock}/bin/flock -n 200; then
            echo "Another backup is already running, skipping"
            exit 0
          fi

          echo "=== rustic backup ${name} started at $(date) ==="

          ${pkgs.rustic}/bin/rustic -P ${name} backup

          ${
            if backup.pruneOnACOnly
            then ''
              if pmset -g ps | grep -q "AC Power"; then
                echo "On AC power, running forget + check..."
                ${pkgs.rustic}/bin/rustic -P ${name} forget
                ${pkgs.rustic}/bin/rustic -P ${name} check
              else
                echo "On battery, skipping forget + check"
              fi
            ''
            else ''
              ${pkgs.rustic}/bin/rustic -P ${name} forget
              ${pkgs.rustic}/bin/rustic -P ${name} check
            ''
          }

          echo "=== rustic backup ${name} finished at $(date) ==="
        '';
      in
        nameValuePair "rustic-backups-${name}" (
          if backup.enableFDA
          then {
            # FDA path: launchd runs .app binary directly, no /bin/sh wrapper.
            # This makes the .app the "responsible process" for TCC.
            serviceConfig = {
              ProgramArguments = [fdaJobBin];
              Disabled = false;
              StartCalendarInterval = [backup.calendarInterval];
              ProcessType = "Background";
              RunAtLoad = true;
              LowPriorityIO = true;
              StandardOutPath = "${backup.logPath}/rustic-${name}.log";
              StandardErrorPath = "${backup.logPath}/rustic-${name}-error.log";
            };
          }
          else {
            # Non-FDA path: use regular command with nix-darwin's /bin/sh wrapper.
            command = "${fallbackScript}";
            serviceConfig = {
              Disabled = false;
              StartCalendarInterval = [backup.calendarInterval];
              ProcessType = "Background";
              RunAtLoad = true;
              LowPriorityIO = true;
              StandardOutPath = "${backup.logPath}/rustic-${name}.log";
              StandardErrorPath = "${backup.logPath}/rustic-${name}-error.log";
            };
          }
        ))
      cfg.backups;

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
        cfg.backups);
  };
}
