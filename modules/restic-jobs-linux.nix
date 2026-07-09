{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.restic.jobs;

  # State directories of DynamicUser units live under /var/lib/private/<x>;
  # /var/lib/<x> is only a symlink and restic snapshots it as ~20 bytes.
  # A backup path that is itself a symlink is essentially always this
  # mistake — fail the unit before restic runs so ServiceFailed pages.
  symlinkGuard = jobName: jobCfg:
    pkgs.writeShellScript "restic-symlink-guard-${jobName}" ''
      status=0
      for p in ${escapeShellArgs jobCfg.paths}; do
        if [ -L "$p" ]; then
          echo "restic job ${jobName}: $p is a symlink ($(readlink "$p")) — back up the target instead (DynamicUser state lives in /var/lib/private/)" >&2
          status=1
        fi
      done
      exit $status
    '';

  # After every backup unit stops, push the outcome to the pushgateway on
  # core.oracldn. The timer-staleness alerts only prove the timer fired; this
  # is the signal that a backup actually SUCCEEDED recently. Failures are
  # covered by ServiceFailed; this must never flip the unit state itself.
  pushSuccess = jobName:
    pkgs.writeShellScript "restic-push-success-${jobName}" ''
      [ "$SERVICE_RESULT" = "success" ] || exit 0
      ${pkgs.curl}/bin/curl -s --max-time 30 --data-binary @- \
        "http://pushgateway/metrics/job/restic/instance/$(${pkgs.coreutils}/bin/uname -n)/repo/${jobName}" <<EOF || true
      # TYPE restic_backup_last_success_timestamp_seconds gauge
      restic_backup_last_success_timestamp_seconds $(${pkgs.coreutils}/bin/date +%s)
      EOF
      exit 0
    '';
in {
  config = {
    systemd.services = mkMerge [
      (mapAttrs' (jobName: jobCfg:
        nameValuePair "restic-backups-${jobName}" (mkIf jobCfg.enable {
          serviceConfig.ExecStartPre = [(symlinkGuard jobName jobCfg)];
          serviceConfig.ExecStopPost = [(pushSuccess jobName)];
        }))
      cfg)
      (mapAttrs' (jobName: jobCfg:
        nameValuePair "restic-check-${jobName}" (mkIf (jobCfg.enable && jobCfg.check.enable) {
          description = "restic repository check for ${jobName}";
          # The restic module's generated wrapper carries the repository,
          # password file, and extra options (incl. rclone remotes).
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "/run/current-system/sw/bin/restic-${jobName} check ${escapeShellArgs jobCfg.check.args}";
          };
        }))
      cfg)
    ];

    systemd.timers = mapAttrs' (jobName: jobCfg:
      nameValuePair "restic-check-${jobName}" (mkIf (jobCfg.enable && jobCfg.check.enable) {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = jobCfg.check.interval;
          Persistent = true;
          RandomizedDelaySec = "6h";
        };
      }))
    cfg;
  };
}
