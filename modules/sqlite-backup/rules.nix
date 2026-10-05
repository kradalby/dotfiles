{
  name = "sqlite-backup";
  rules = [
    {
      alert = "SQLiteBackupFailed";
      expr = "(sqlite_backup_last_run_success == 0) and sqlite_backup_expected";
      for = "2m";
      labels.severity = "critical";
      annotations = {
        summary = "SQLite snapshot {{ $labels.backup }} failed on {{ $labels.instance }}";
        description = "The latest snapshot attempt failed. Check sqlite-backup-{{ $labels.backup }}.service; older archives do not indicate a successful new dump.";
      };
    }
    {
      alert = "SQLiteBackupStale";
      expr = "(time() - sqlite_backup_last_success_timestamp_seconds > sqlite_backup_max_age_seconds) and sqlite_backup_expected";
      for = "5m";
      labels.severity = "critical";
      annotations = {
        summary = "SQLite snapshot {{ $labels.backup }} stale on {{ $labels.instance }}";
        description = "No validated snapshot has been published within the configured maximum age. Check the dump timer and service; file uploads may still be succeeding.";
      };
    }
    {
      alert = "SQLiteBackupMetricsMissing";
      expr = ''
        sqlite_backup_expected unless
          (sqlite_backup_last_run_success
           and sqlite_backup_last_run_timestamp_seconds
           and sqlite_backup_last_success_timestamp_seconds)
      '';
      for = "15m";
      labels.severity = "critical";
      annotations = {
        summary = "SQLite snapshot {{ $labels.backup }} has no results on {{ $labels.instance }}";
        description = "A configured snapshot job has incomplete or missing metrics. It may never have run, or its result file cannot be published or read.";
      };
    }
    {
      alert = "SQLiteBackupMonitoringMissing";
      expr = "absent(sqlite_backup_expected) or absent(sqlite_backup_max_age_seconds) or absent(sqlite_backup_last_run_success) or absent(sqlite_backup_last_run_timestamp_seconds) or absent(sqlite_backup_last_success_timestamp_seconds)";
      for = "15m";
      labels.severity = "critical";
      annotations = {
        summary = "SQLite snapshot monitoring is missing";
        description = "An expected SQLite snapshot metric family is absent fleet-wide. Check node-exporter's textfile collection and the configured snapshot jobs.";
      };
    }
  ];
}
