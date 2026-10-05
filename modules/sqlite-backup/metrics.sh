#!/usr/bin/env bash
set -euo pipefail

directory=$1
name=$2
labels=$3
metricfile="$directory/sqlite-backup-$name.prom"
last_success=0

if [ -f "$metricfile" ]; then
  last_success=$(awk '$1 ~ /^sqlite_backup_last_success_timestamp_seconds\{/ {print $2}' "$metricfile")
  [[ "$last_success" =~ ^[0-9]+$ ]]
fi

now=$(date +%s)
success=0
if [ "${SERVICE_RESULT:-}" = success ]; then
  success=1
  last_success=$now
fi

tmp=$(mktemp "$directory/.sqlite-backup-$name.XXXXXX")
trap 'rm -f -- "$tmp"' EXIT
{
  cat <<'EOF'
# HELP sqlite_backup_last_run_success Whether the last SQLite snapshot attempt succeeded.
# TYPE sqlite_backup_last_run_success gauge
# HELP sqlite_backup_last_run_timestamp_seconds Completion time of the last SQLite snapshot attempt.
# TYPE sqlite_backup_last_run_timestamp_seconds gauge
# HELP sqlite_backup_last_success_timestamp_seconds Completion time of the last successful SQLite snapshot.
# TYPE sqlite_backup_last_success_timestamp_seconds gauge
EOF
  printf 'sqlite_backup_last_run_success{%s} %s\n' "$labels" "$success"
  printf 'sqlite_backup_last_run_timestamp_seconds{%s} %s\n' "$labels" "$now"
  printf 'sqlite_backup_last_success_timestamp_seconds{%s} %s\n' "$labels" "$last_success"
} >"$tmp"
chmod 0644 "$tmp"
mv -- "$tmp" "$metricfile"
