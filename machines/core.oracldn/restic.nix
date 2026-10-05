{ config, lib, ... }:
let
  databases = config.my.litestream.databases;
  backupDirectory = "/var/backup/sqlite";
  snapshotUnits = map (db: "sqlite-backup-${db.name}.service") databases;
  liveDatabaseFiles = lib.concatMap (db: [
    db.path
    "${db.path}-wal"
    "${db.path}-shm"
  ]) databases;
  paths = [
    "/etc/nixos"
    # uptime-kuma runs without DynamicUser; the /var/lib/private path was a
    # stale symlink target that backed up nothing.
    "/var/lib/uptime-kuma"
    # headscale's sqlite is otherwise only replicated via litestream; keep a
    # second, independent copy in restic.
    "/var/lib/headscale"
    config.services.golink.dataDir
    config.services.postgresqlBackup.location
    config.services.grafana.dataDir
    backupDirectory
  ];

  mkJob = site: {
    enable = true;
    inherit site paths;
    secret = "restic-core-oracldn-token";
    extraConfig.exclude = liveDatabaseFiles ++ [ "${backupDirectory}/.sqlite-backup.*" ];
  };
in
{
  # The same producer interface is used by SFiber. Restic requires successful
  # snapshots on every run, including first boot, rather than accepting stale
  # archives after a failed independent timer. Concurrent starts share the
  # systemd job; later runs create a fresh snapshot.
  # Restore the chosen <db.name>_backup_<timestamp>.db.xz with xz -dc into
  # db.path while its service is stopped, then restore the service ownership.
  services.sqlite-backup = lib.listToAttrs (
    map (
      db:
      lib.nameValuePair db.name {
        enable = true;
        databasePath = db.path;
        backupPath = backupDirectory;
        user = "root";
        group = "root";
        # Match SFiber's hourly archive tier; Restic keeps long-term history.
        retention = "1day";
      }
    ) databases
  );

  systemd.services =
    lib.genAttrs [ "restic-backups-tjoda" "restic-backups-ldn" "restic-backups-jotta" ]
      (_: {
        requires = snapshotUnits;
        after = snapshotUnits;
      });

  services.restic.jobs = {
    tjoda = mkJob "tjoda";
    ldn = mkJob "ldn";
    # Offsite via the Jotta proxy on core.tjoda (no Jotta credentials here).
    # targetHost is the opaque repo name on Jotta — house convention, nothing
    # host-identifying on the provider side.
    jotta = mkJob "jotta" // {
      targetHost = "f553137cb49962eeb9f01cb958dfcf95";
      # Jotta egress is paid/slow: verify metadata only, monthly. The REST
      # repos get the read-data checks.
      check = {
        args = [ ];
        interval = "monthly";
      };
    };
  };
}
