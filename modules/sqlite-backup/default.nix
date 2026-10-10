{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  cfg = lib.filterAttrs (_: job: job.enable) config.services.sqlite-backup;
  nodeExporter = config.services.prometheus.exporters.node;
  textfileFlag = "--collector.textfile.directory=";
  textfileDirectory = lib.removePrefix textfileFlag (
    lib.findFirst (lib.hasPrefix textfileFlag)
      "${textfileFlag}/var/lib/prometheus-node-exporter-textfile"
      nodeExporter.extraFlags
  );
  monitored = lib.filterAttrs (_: job: job.monitoring.enable) cfg;
  metricDirectories = lib.unique (
    lib.optional (
      nodeExporter.enable && lib.elem "textfile" nodeExporter.enabledCollectors
    ) textfileDirectory
    ++ map (job: job.monitoring.textfileDirectory) (lib.attrValues monitored)
  );
  promEscape = lib.replaceStrings [ "\\" "\"" "\n" ] [ "\\\\" "\\\"" "\\n" ];
  labels = name: ''backup="${promEscape name}"'';
  metrics = pkgs.writeShellApplication {
    name = "sqlite-backup-metrics";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
    ];
    text = builtins.readFile ./metrics.sh;
  };
in
{
  options.services.sqlite-backup = lib.mkOption {
    default = { };
    description = "Scheduled, compressed SQLite snapshots.";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "SQLite backups";
          databasePath = lib.mkOption {
            type = lib.types.path;
            description = "Existing SQLite database to snapshot.";
          };
          backupPath = lib.mkOption {
            type = lib.types.path;
            description = "Directory for timestamped .db.xz archives.";
          };
          schedule = lib.mkOption {
            type = lib.types.str;
            default = "hourly";
            description = "systemd OnCalendar expression.";
          };
          user = lib.mkOption {
            type = lib.types.str;
            default = "fiberdb";
            description = "Account with read access to the database and write access to backups.";
          };
          group = lib.mkOption {
            type = lib.types.str;
            default = "fiberdb";
            description = "Group under which the backup runs.";
          };
          retention = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Age passed to fd --changed-before; empty keeps all archives.";
          };
          timeout = lib.mkOption {
            type = lib.types.str;
            default = "30min";
            description = "Maximum time for snapshot preparation, in systemd duration syntax.";
          };
          monitoring = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Publish snapshot outcomes and freshness through node-exporter's textfile collector.";
            };
            maxAgeSeconds = lib.mkOption {
              type = lib.types.ints.positive;
              default = 2 * 3600;
              description = "Maximum age of a successful snapshot. Set this to suit the job's schedule.";
            };
            textfileDirectory = lib.mkOption {
              type = lib.types.path;
              default = textfileDirectory;
              description = "Metrics directory; defaults to the configured node-exporter textfile directory.";
            };
          };
        };
      }
    );
  };

  config = {
    assertions = lib.mapAttrsToList (name: job: {
      assertion =
        nodeExporter.enable
        && lib.elem "textfile" nodeExporter.enabledCollectors
        && lib.elem "${textfileFlag}${job.monitoring.textfileDirectory}" nodeExporter.extraFlags;
      message = "sqlite-backup.${name}: monitoring requires node-exporter's textfile collector at ${job.monitoring.textfileDirectory}.";
    }) monitored;

    # Static expectations make a job visible before its first completion and
    # keep missing result files from silently removing it from monitoring.
    systemd.tmpfiles.rules = map (
      directory:
      let
        jobs = lib.filterAttrs (_: job: job.monitoring.textfileDirectory == directory) monitored;
        expected = pkgs.writeText "sqlite-backup-expected.prom" (
          ''
            # HELP sqlite_backup_expected Configured SQLite snapshot jobs.
            # TYPE sqlite_backup_expected gauge
            # HELP sqlite_backup_max_age_seconds Maximum age of a successful SQLite snapshot.
            # TYPE sqlite_backup_max_age_seconds gauge
          ''
          + lib.concatStrings (
            lib.mapAttrsToList (name: job: ''
              sqlite_backup_expected{${labels name}} 1
              sqlite_backup_max_age_seconds{${labels name}} ${toString job.monitoring.maxAgeSeconds}
            '') jobs
          )
        );
        destination = "${directory}/sqlite-backup-expected.prom";
      in
      "L+ ${builtins.toJSON destination} - - - - ${expected}"
    ) metricDirectories;

    systemd.services = lib.mapAttrs' (
      name: job:
      lib.nameValuePair "sqlite-backup-${name}" {
        description = "Backup SQLite database ${name}";
        after = [ "systemd-tmpfiles-setup.service" ];
        path = [ pkgs.coreutils ];
        serviceConfig = {
          User = job.user;
          Group = job.group;
          Type = "oneshot";
          TimeoutStartSec = job.timeout;
          # The dump keeps its service account; only metric publication needs
          # access to the host-owned collector directory, including on failure.
          ExecStopPost = lib.optionals job.monitoring.enable [
            "+${lib.getExe metrics} ${
              utils.escapeSystemdExecArgs [
                job.monitoring.textfileDirectory
                (utils.escapeSystemdPath name)
                (labels name)
              ]
            }"
          ];
        };
        script = ''
          set -euo pipefail
          # SFiber's backupd reads published archives through this job's group.
          # Staging remains private (mktemp creates it with mode 0700).
          umask 027
          database=${lib.escapeShellArg job.databasePath}
          directory=${lib.escapeShellArg job.backupPath}
          prefix=${lib.escapeShellArg "${name}_backup_"}

          # SQLite normally creates a missing source as an empty database.
          test -f "$database"
          mkdir -p -- "$directory"
          staging=$(mktemp -d "$directory/.sqlite-backup.XXXXXX")
          trap 'rm -rf -- "$staging"' EXIT
          archive="$directory/''${prefix}$(date +%Y%m%d_%H%M%S).db.xz"

          # Keep SQL independent of configured path quoting. The destination
          # is relative to a unique staging directory on the publication disk.
          cd "$staging"
          ${pkgs.sqlite}/bin/sqlite3 -batch -init /dev/null -readonly "$database" \
            "VACUUM INTO 'snapshot.db';"
          result=$(${pkgs.sqlite}/bin/sqlite3 -batch -init /dev/null -readonly snapshot.db \
            'PRAGMA integrity_check;')
          test "$result" = ok
          ${pkgs.xz}/bin/xz -9 -c snapshot.db > archive.xz
          mv -- archive.xz "$archive"

          # Delete only this job's archives, after a new snapshot is published.
          ${lib.optionalString (job.retention != "") ''
            ${pkgs.fd}/bin/fd --base-directory "$directory" --max-depth 1 \
              --type file --changed-before ${lib.escapeShellArg job.retention} \
              --extension xz --fixed-strings "$prefix" --exec rm -- {}
          ''}
        '';
      }
    ) cfg;

    systemd.timers = lib.mapAttrs' (
      name: job:
      lib.nameValuePair "sqlite-backup-${name}" {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "1min";
          OnCalendar = job.schedule;
          Persistent = true;
          Unit = "sqlite-backup-${name}.service";
        };
      }
    ) cfg;
  };
}
