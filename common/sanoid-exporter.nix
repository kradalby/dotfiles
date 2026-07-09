{
  config,
  lib,
  pkgs,
  ...
}: let
  # Only meaningful on hosts that actually run sanoid.
  cfg = config.services.sanoid;
  datasets = lib.attrNames cfg.datasets;
  # Pools backing the managed datasets (first path component).
  pools = lib.unique (map (d: lib.head (lib.splitString "/" d)) datasets);

  textfileDir = "/var/lib/prometheus-node-exporter-textfile";
  outFile = "${textfileDir}/sanoid.prom";

  # zfs list with -p emits the raw unix-second creation time; -s creation sorts
  # ascending so `tail -1` is the newest snapshot. -d1 keeps us on the dataset
  # itself (not its children). Missing/empty -> 0, which reads as "epoch old"
  # and correctly trips a snapshot-freshness alert.
  snapshotLines =
    lib.concatMapStrings (ds: ''
      ts=$(${pkgs.zfs}/bin/zfs list -H -p -t snapshot -o creation -s creation -d1 ${lib.escapeShellArg ds} 2>/dev/null | tail -1)
      printf 'zfs_snapshot_newest_creation_seconds{dataset="%s"} %s\n' ${lib.escapeShellArg ds} "''${ts:-0}" >>"$tmp"
    '')
    datasets;

  # `zpool status -x <pool>` prints "pool '<pool>' is healthy" when all is well;
  # anything else (DEGRADED, checksum/read/write errors, scrub findings) means
  # the pool needs attention even while it stays ONLINE.
  poolLines =
    lib.concatMapStrings (pool: ''
      if ${pkgs.zfs}/bin/zpool status -x ${lib.escapeShellArg pool} 2>/dev/null | grep -q 'is healthy'; then
        err=0
      else
        err=1
      fi
      printf 'zfs_pool_status_errors{pool="%s"} %s\n' ${lib.escapeShellArg pool} "$err" >>"$tmp"
    '')
    pools;
in {
  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${textfileDir} 0755 root root -"
    ];

    # No official sanoid exporter exists; zfs_exporter covers pool health but
    # not snapshot age or `zpool status -x`, so we emit those via textfile.
    systemd.services.sanoid-exporter = {
      description = "Write sanoid/zpool freshness metrics to the node_exporter textfile collector";
      serviceConfig = {
        Type = "oneshot";
      };
      script = ''
        tmp=$(mktemp ${textfileDir}/sanoid.prom.XXXXXX)
        {
          echo '# HELP zfs_snapshot_newest_creation_seconds Unix time of the newest snapshot of a sanoid-managed dataset.'
          echo '# TYPE zfs_snapshot_newest_creation_seconds gauge'
          echo '# HELP zfs_pool_status_errors 1 if zpool status -x reports the pool is not healthy, else 0.'
          echo '# TYPE zfs_pool_status_errors gauge'
        } >"$tmp"
        ${snapshotLines}
        ${poolLines}
        mv -f "$tmp" ${outFile}
      '';
    };

    systemd.timers.sanoid-exporter = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "15m";
        Persistent = true;
      };
    };
  };
}
