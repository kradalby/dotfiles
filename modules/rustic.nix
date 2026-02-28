{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.rustic;

  # Generate a rustic TOML profile for a backup job
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

  # Stable wrapper .app bundle for Full Disk Access.
  # The .app has a fixed path and bundle ID so FDA grant survives
  # darwin-rebuild. The embedded script resolves the real rustic
  # binary at runtime via /run/current-system/sw/bin/rustic.
  fdaAppPath = "${cfg.fdaAppDir}/RusticBackup.app";
  fdaAppBin = "${fdaAppPath}/Contents/MacOS/rustic-backup";

  mkFdaApp = pkgs.stdenv.mkDerivation {
    name = "rustic-backup-app";
    buildCommand = ''
      mkdir -p $out/RusticBackup.app/Contents/MacOS

      cat > $out/RusticBackup.app/Contents/Info.plist <<PLIST
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

      cat > $out/RusticBackup.app/Contents/MacOS/rustic-backup <<'SCRIPT'
      #!/bin/bash
      # Resolve rustic from the current system profile so the .app
      # wrapper stays stable across darwin-rebuild while the actual
      # binary can be updated.
      exec /run/current-system/sw/bin/rustic "$@"
      SCRIPT
      chmod +x $out/RusticBackup.app/Contents/MacOS/rustic-backup
    '';
  };
in {
  options.services.rustic = {
    backups = mkOption {
      description = ''
        Periodic backups to create with rustic.
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
            example = ["$HOME/git" "$HOME/Pictures"];
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

  config = mkMerge [
    {
      # Ensure rustic and rclone are available system-wide.
      environment.systemPackages = [
        pkgs.rustic
        pkgs.rclone
      ];
    }
    (mkIf (cfg.backups != {}) {
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

    # Generate a launchd user agent for each backup job
    launchd.user.agents =
      mapAttrs'
      (name: backup: let
        rusticBin =
          if backup.enableFDA
          then fdaAppBin
          else "${pkgs.rustic}/bin/rustic";

        # The backup script: run backup, then optionally prune on AC power.
        # rustic -P <name> loads /etc/rustic/<name>.toml automatically.
        backupScript = pkgs.writers.writeBash "rustic-backup-${name}" ''
          set -euo pipefail

          export PATH="${lib.makeBinPath [pkgs.rclone pkgs._1password-cli]}:$PATH"

          # Wait for the FDA wrapper to be installed (activation may
          # still be running on the very first darwin-rebuild switch).
          ${optionalString backup.enableFDA ''
            if [ ! -x "${rusticBin}" ]; then
              echo "Waiting for ${rusticBin} to appear..."
              for i in $(seq 1 30); do
                [ -x "${rusticBin}" ] && break
                sleep 2
              done
              if [ ! -x "${rusticBin}" ]; then
                echo "ERROR: ${rusticBin} not found after 60s, skipping backup"
                exit 1
              fi
            fi
          ''}

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

        # Wrap with flock to prevent concurrent runs
        runScript = pkgs.writers.writeBash "run-rustic-${name}" ''
          ${pkgs.flock}/bin/flock -n /tmp/rustic_${name}.lockfile ${backupScript}
        '';
      in
        nameValuePair "rustic-backups-${name}" {
          command = "${runScript}";
          serviceConfig = {
            Disabled = false;
            StartCalendarInterval = [backup.calendarInterval];
            ProcessType = "Background";
            RunAtLoad = true;
            LowPriorityIO = true;
            StandardOutPath = "${backup.logPath}/rustic-${name}.log";
            StandardErrorPath = "${backup.logPath}/rustic-${name}-error.log";
          };
        })
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
    })
  ];
}
