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

  # Stable .app bundle path for Full Disk Access.
  # The .app has a fixed path and bundle ID so the FDA grant
  # survives darwin-rebuild.
  fdaAppPath = "${cfg.fdaAppDir}/RusticBackup.app";

  # Generate the per-job backup script that lives inside the .app
  # bundle. This script IS the launchd entry point so macOS sees the
  # .app as the responsible process for TCC/FDA checks.
  mkJobScript = name: backup: let
    rusticBin = "/run/current-system/sw/bin/rustic";
  in ''
    #!/bin/bash
    set -euo pipefail

    # Wait for the Nix store firmlink (may not be ready at early boot)
    /bin/wait4path /nix/store

    export PATH="${lib.makeBinPath [pkgs.rclone pkgs._1password-cli pkgs.flock]}:$PATH"

    # Prevent concurrent runs of this backup job
    exec ${pkgs.flock}/bin/flock -n /tmp/rustic_${name}.lockfile "$0-inner" "$@"
  '';

  # The "inner" script that flock execs into -- does the actual backup
  mkJobInnerScript = name: backup: let
    rusticBin = "/run/current-system/sw/bin/rustic";
  in ''
    #!/bin/bash
    set -euo pipefail

    export PATH="${lib.makeBinPath [pkgs.rclone pkgs._1password-cli]}:$PATH"

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

  # Build the .app bundle derivation containing Info.plist and
  # per-job scripts. The activation script copies this to a stable
  # path so the FDA grant persists across rebuilds.
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
          # Job script for "${name}" -- launchd entry point (holds flock)
          cat > $out/RusticBackup.app/Contents/MacOS/backup-${name} <<'JOBSCRIPT'
          ${mkJobScript name backup}
          JOBSCRIPT
          chmod +x $out/RusticBackup.app/Contents/MacOS/backup-${name}

          # Inner script for "${name}" -- actual backup logic (flock execs into this)
          cat > $out/RusticBackup.app/Contents/MacOS/backup-${name}-inner <<'JOBSCRIPT'
          ${mkJobInnerScript name backup}
          JOBSCRIPT
          chmod +x $out/RusticBackup.app/Contents/MacOS/backup-${name}-inner
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

        # Non-FDA fallback: use a regular bash script
        fallbackScript = pkgs.writers.writeBash "rustic-backup-${name}" ''
          set -euo pipefail

          export PATH="${lib.makeBinPath [pkgs.rclone pkgs._1password-cli]}:$PATH"

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

        fallbackRunScript = pkgs.writers.writeBash "run-rustic-${name}" ''
          ${pkgs.flock}/bin/flock -n /tmp/rustic_${name}.lockfile ${fallbackScript}
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
            command = "${fallbackRunScript}";
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
