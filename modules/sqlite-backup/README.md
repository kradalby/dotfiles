# SQLite snapshots

Import `nixosModules.sqlite-backup` on producer hosts and configure
`services.sqlite-backup.<name>` with the source database, archive directory,
service account and schedule. Archives retain the
`<name>_backup_<timestamp>.db.xz` naming used by SFiber's seed consumers.

Each job publishes its last attempt result, completion time and last successful
snapshot time through the existing node-exporter textfile collector. Success is
recorded only after the dump, integrity check, compression, publication and
retention finish successfully. Failures and terminations preserve the last
successful timestamp. Metric files are published atomically and readable by the
exporter; the dump continues running as its configured user.

The collector directory is detected from node-exporter's configured flag and
must already exist. Override `monitoring.textfileDirectory` if needed. Configure
`monitoring.maxAgeSeconds` for each schedule: the default is two hours, ten-minute
jobs can use `30 * 60`, and daily jobs can use `26 * 3600`. Snapshot preparation
has a configurable `timeout`, defaulting to thirty minutes.

Import `nixosModules.sqlite-backup-monitoring` on the Prometheus host. It installs
the shared `SQLiteBackupFailed`, `SQLiteBackupStale` and
`SQLiteBackupMetricsMissing` rules, plus a metric-family absence canary. Static
expected-job metrics make a job that
never completes, or loses its result metrics, visible independently of other
jobs. No file-upload service is required.

For source-only consumers such as SFiber, import `modules/sqlite-backup` and
`modules/sqlite-backup/monitoring.nix` from the pinned dotfiles source. Import
`modules/sqlite-backup/tests.nix { inherit pkgs; }` into CI to run the same snapshot,
metric-publication and Prometheus-rule fixtures with the consumer's package pins.
