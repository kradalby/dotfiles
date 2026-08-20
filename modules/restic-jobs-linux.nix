{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.services.restic.jobs;

  # Fleet identity is <host>-<site> (core-tjoda, dev-ldn) — the same name the
  # tailnet and every scrape target uses. NEVER the bare hostName: `core`,
  # `dev` and `storage` are each shared by two machines, so a bare name merges
  # two hosts into one pushgateway series and a failing host is hidden behind
  # its healthy twin. Hosts without a site (garnix, gigabuilder) keep their
  # plain name, since removeSuffix leaves nothing to dash.
  fleetInstance = builtins.replaceStrings [ "." ] [ "-" ] (
    removeSuffix ".fap.no" config.networking.fqdnOrHostName
  );

  # State directories of DynamicUser units live under /var/lib/private/<x>;
  # /var/lib/<x> is only a symlink and restic snapshots it as ~20 bytes.
  # A backup path that is itself a symlink is essentially always this
  # mistake — fail the unit before restic runs so ServiceFailed pages.
  symlinkGuard =
    jobName: jobCfg:
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
  pushSuccess =
    jobName:
    pkgs.writeShellScript "restic-push-success-${jobName}" ''
      [ "$SERVICE_RESULT" = "success" ] || exit 0
      # Exit 3 counts as success (SuccessExitStatus) but means "some source
      # files could not be read". Push the status alongside the timestamp so
      # ResticBackupPartial can page on a PERSISTENTLY unreadable path, which
      # the success stamp alone would mask forever.
      ${pkgs.curl}/bin/curl -s --max-time 30 --data-binary @- \
        "http://pushgateway/metrics/job/restic/instance/${fleetInstance}/repo/${jobName}" <<EOF || true
      # TYPE restic_backup_last_success_timestamp_seconds gauge
      restic_backup_last_success_timestamp_seconds $(${pkgs.coreutils}/bin/date +%s)
      # TYPE restic_backup_last_exit_status gauge
      restic_backup_last_exit_status ''${EXIT_STATUS:-0}
      EOF
      exit 0
    '';
in
{
  config = {
    systemd.services = mkMerge [
      (mapAttrs' (
        jobName: jobCfg:
        nameValuePair "restic-backups-${jobName}" (
          mkIf jobCfg.enable {
            serviceConfig.ExecStartPre = [ (symlinkGuard jobName jobCfg) ];
            serviceConfig.ExecStopPost = [ (pushSuccess jobName) ];
            # Exit 3 = "some source files could not be read" (files vanishing
            # mid-scan on live homedirs). A snapshot IS created; treat it as
            # success instead of paging ServiceFailed every time a browser
            # cache file disappears under the scanner.
            serviceConfig.SuccessExitStatus = [ 3 ];
            # restic streams pack files through $TMPDIR. The default /tmp is a
            # 4G tmpfs here, so unrelated scratch files can starve a backup:
            # every job on dev-ldn died on "no space left on device" writing
            # /tmp/restic-temp-pack-*. CacheDirectory= already gives us a
            # disk-backed per-job dir; point TMPDIR at it so backups only
            # compete with themselves. serviceConfig.Environment (not
            # environment.*): the nixpkgs module copies `environment` into the
            # interactive restic-<job> wrapper, where this root-owned dir would
            # break ad-hoc restores.
            serviceConfig.Environment = [ "TMPDIR=/var/cache/restic-backups-${jobName}" ];
          }
        )
      ) cfg)
      (mapAttrs' (
        jobName: jobCfg:
        nameValuePair "restic-prune-${jobName}" (
          mkIf (jobCfg.enable && jobCfg.pruneOpts != [ ]) {
            description = "restic forget --prune for ${jobName}";
            # Pruning repacks the repo, so it runs weekly here — never as part
            # of the hourly backups (that would mean 24 repacks/day, paid
            # egress on jotta).
            # Prune runs Wednesday, the check Monday, so the two exclusive-lock
            # holders never share a window by construction; --retry-lock=3h
            # still outlasts any hourly backup that holds the lock.
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            environment.TMPDIR = "/var/cache/restic-backups-${jobName}";
            serviceConfig = {
              Type = "oneshot";
              CacheDirectory = "restic-backups-${jobName}";
              User = config.services.restic.backups.${jobName}.user;
              TimeoutStartSec = "6h";
              # pruneOpts entries are pre-split shell words ("--keep-daily 7");
              # systemd word-splits ExecStart the same way.
              ExecStart = "/run/current-system/sw/bin/restic-${jobName} forget --prune --retry-lock=3h ${concatStringsSep " " jobCfg.pruneOpts}";
            };
          }
        )
      ) cfg)
      (mapAttrs' (
        jobName: jobCfg:
        nameValuePair "restic-check-${jobName}" (
          mkIf (jobCfg.enable && jobCfg.check.enable) {
            description = "restic repository check for ${jobName}";
            # Persistent=true catch-up runs fire seconds after boot; without
            # this ordering they dial before the network is up and page.
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            # Same tmpfs starvation applies to `check`, which unpacks into
            # $TMPDIR while verifying — keep it on disk with the backup job.
            environment.TMPDIR = "/var/cache/restic-backups-${jobName}";
            # The restic module's generated wrapper carries the repository,
            # password file, and extra options (incl. rclone remotes).
            serviceConfig = {
              Type = "oneshot";
              # Same dir the backup unit gets; declared here too so the check
              # cannot run before it exists (TMPDIR above points into it).
              CacheDirectory = "restic-backups-${jobName}";
              # systemd only exports $HOME when User= is set. rclone needs it
              # to find rclone.conf; without it it shells out to `getent`,
              # which is not on this unit's PATH, and the check dies with
              # "didn't find section in config file". Mirror the backup unit.
              User = config.services.restic.backups.${jobName}.user;
              # Type=oneshot defaults to no start timeout. A wedged rclone or
              # REST connection would hang in `activating` forever — which is
              # not `failed`, so ServiceFailed never fires. Bound it clear of
              # the lock wait plus a --read-data-subset run.
              TimeoutStartSec = "6h";
              # Backups run hourly and this timer has a 6h random delay, so
              # overlap is routine; restic defaults to no lock retry and exits
              # 11 the moment it finds the repository locked.
              ExecStart = "/run/current-system/sw/bin/restic-${jobName} check --retry-lock=1h ${escapeShellArgs jobCfg.check.args}";
            };
          }
        )
      ) cfg)
    ];

    systemd.timers = mkMerge [
      (mapAttrs' (
        jobName: jobCfg:
        nameValuePair "restic-check-${jobName}" (
          mkIf (jobCfg.enable && jobCfg.check.enable) {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = jobCfg.check.interval;
              Persistent = true;
              RandomizedDelaySec = "6h";
            };
          }
        )
      ) cfg)
      (mapAttrs' (
        jobName: jobCfg:
        nameValuePair "restic-prune-${jobName}" (
          mkIf (jobCfg.enable && jobCfg.pruneOpts != [ ]) {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              # Wednesday, away from the Monday check window (see the unit).
              OnCalendar = "Wed 03:00";
              Persistent = true;
              RandomizedDelaySec = "6h";
            };
          }
        )
      ) cfg)
    ];
  };
}
