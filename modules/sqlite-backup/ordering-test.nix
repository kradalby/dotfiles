{ pkgs }:
pkgs.testers.runNixOSTest {
  name = "sqlite-backup-ordering";
  nodes.machine = { ... }: {
    imports = [ ./default.nix ];
    environment.systemPackages = with pkgs; [
      sqlite
      restic
      xz
      curl
    ];
    environment.etc.backup-password.text = "isolated-test-password";
    users.groups.backup-readers = { };
    users.users.snapshot-reader = {
      isSystemUser = true;
      group = "backup-readers";
    };
    users.users.snapshot-writer = {
      isSystemUser = true;
      group = "backup-readers";
    };
    services.prometheus.exporters.node = {
      enable = true;
      enabledCollectors = [ "textfile" ];
      extraFlags = [ "--collector.textfile.directory=/var/lib/node-textfile" ];
    };
    systemd.tmpfiles.rules = [ "d /var/lib/node-textfile 0755 root root -" ];
    services.sqlite-backup.fixture = {
      enable = true;
      databasePath = "/var/lib/fixture.db";
      backupPath = "/var/backup/sqlite";
      user = "root";
      group = "backup-readers";
    };
    services.sqlite-backup.unprivileged = {
      enable = true;
      databasePath = "/var/lib/fixture.db";
      backupPath = "/var/lib/sqlite-unprivileged/archives";
      user = "snapshot-writer";
      group = "backup-readers";
      timeout = "1s";
    };
    systemd.services.sqlite-backup-unprivileged.serviceConfig.StateDirectory = "sqlite-unprivileged";
    services.restic.backups.fixture = {
      repository = "/var/lib/restic-fixture";
      passwordFile = "/etc/backup-password";
      paths = [ "/var/backup/sqlite" ];
      initialize = true;
      timerConfig = null;
    };
    systemd.services.restic-backups-fixture = {
      requires = [ "sqlite-backup-fixture.service" ];
      after = [ "sqlite-backup-fixture.service" ];
    };
  };
  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.succeed("systemctl stop sqlite-backup-fixture.timer sqlite-backup-unprivileged.timer")
    machine.wait_for_unit("prometheus-node-exporter.service")

    def metric(backup, name):
        return machine.succeed(f"awk '/^{name}\\{{/ {{print $2}}' /var/lib/node-textfile/sqlite-backup-{backup}.prom").strip()

    with subtest("expected jobs are visible before any snapshot completes"):
        machine.succeed("curl -fsS localhost:9100/metrics | grep -F 'sqlite_backup_expected{backup=\"fixture\"} 1'")
        machine.succeed("test ! -f /var/lib/node-textfile/sqlite-backup-fixture.prom")

    with subtest("first backup requires a snapshot and creates its source directory"):
        machine.succeed("sqlite3 /var/lib/fixture.db 'CREATE TABLE entries (value INTEGER); INSERT INTO entries VALUES (1);'")
        machine.succeed("systemctl start restic-backups-fixture.service")
        machine.succeed("runuser -u snapshot-reader -- sh -c 'xz -t /var/backup/sqlite/*.db.xz'")
        machine.succeed("restic -r /var/lib/restic-fixture -p /etc/backup-password snapshots --json | ${pkgs.jq}/bin/jq -e 'length == 1'")
        assert metric("fixture", "sqlite_backup_last_run_success") == "1"
        assert int(metric("fixture", "sqlite_backup_last_success_timestamp_seconds")) > 0
        machine.succeed("curl -fsS localhost:9100/metrics | grep -F 'sqlite_backup_last_run_success{backup=\"fixture\"} 1'")

    with subtest("an independent non-root producer can publish readable metrics"):
        machine.succeed("systemctl start sqlite-backup-unprivileged.service")
        assert metric("unprivileged", "sqlite_backup_last_run_success") == "1"
        previous = metric("unprivileged", "sqlite_backup_last_success_timestamp_seconds")
        machine.succeed("test \"$(stat -c %U /var/lib/sqlite-unprivileged/archives/*.db.xz)\" = snapshot-writer")
        machine.succeed("test \"$(stat -c %a /var/lib/node-textfile/sqlite-backup-unprivileged.prom)\" = 644")

    with subtest("a timeout preserves the last successful timestamp"):
        machine.succeed("mkdir -p /run/systemd/system/sqlite-backup-unprivileged.service.d")
        machine.succeed("printf '[Service]\\nExecStart=\\nExecStart=${pkgs.coreutils}/bin/sleep 120\\n' > /run/systemd/system/sqlite-backup-unprivileged.service.d/slow.conf")
        machine.succeed("systemctl daemon-reload")
        machine.fail("systemctl start sqlite-backup-unprivileged.service")
        assert metric("unprivileged", "sqlite_backup_last_run_success") == "0"
        assert metric("unprivileged", "sqlite_backup_last_success_timestamp_seconds") == previous
        machine.succeed("test \"$(systemctl show -p Result --value sqlite-backup-unprivileged.service)\" = timeout")

    with subtest("a killed producer also records failure"):
        machine.succeed("printf '[Service]\\nExecStart=\\nExecStart=${pkgs.coreutils}/bin/sleep 120\\nTimeoutStartSec=30min\\n' > /run/systemd/system/sqlite-backup-unprivileged.service.d/slow.conf")
        machine.succeed("systemctl daemon-reload")
        machine.succeed("systemctl start --no-block sqlite-backup-unprivileged.service")
        machine.wait_until_succeeds("test \"$(systemctl show -p SubState --value sqlite-backup-unprivileged.service)\" = start")
        machine.succeed("systemctl kill --kill-whom=main --signal=SIGKILL sqlite-backup-unprivileged.service")
        machine.wait_until_succeeds("systemctl is-failed sqlite-backup-unprivileged.service")
        assert metric("unprivileged", "sqlite_backup_last_run_success") == "0"
        assert metric("unprivileged", "sqlite_backup_last_success_timestamp_seconds") == previous

    with subtest("later backup triggers a fresh snapshot"):
        machine.succeed("sqlite3 /var/lib/fixture.db 'INSERT INTO entries VALUES (2);'")
        machine.succeed("systemctl start restic-backups-fixture.service")
        machine.succeed("restic -r /var/lib/restic-fixture -p /etc/backup-password restore latest --target /var/lib/restored")
        machine.succeed("archive=$(ls /var/lib/restored/var/backup/sqlite/*.db.xz | sort | tail -1); xz -dc \"$archive\" > /var/lib/restored.db")
        machine.succeed("test \"$(sqlite3 /var/lib/restored.db 'SELECT count(*) FROM entries;')\" = 2")

    with subtest("failed snapshot blocks Restic despite existing good archives"):
        last_success = metric("fixture", "sqlite_backup_last_success_timestamp_seconds")
        machine.succeed("printf corrupt > /var/lib/fixture.db")
        machine.fail("systemctl start restic-backups-fixture.service")
        machine.succeed("restic -r /var/lib/restic-fixture -p /etc/backup-password snapshots --json | ${pkgs.jq}/bin/jq -e 'length == 2'")
        machine.succeed("systemctl is-failed sqlite-backup-fixture.service")
        assert metric("fixture", "sqlite_backup_last_run_success") == "0"
        assert metric("fixture", "sqlite_backup_last_success_timestamp_seconds") == last_success

    with subtest("a metric publication error fails the producer"):
        machine.succeed("sqlite3 /var/lib/healthy.db 'CREATE TABLE entries (value INTEGER);'")
        machine.succeed("mv /var/lib/healthy.db /var/lib/fixture.db")
        machine.succeed("mv /var/lib/node-textfile /var/lib/node-textfile.saved; touch /var/lib/node-textfile")
        machine.fail("systemctl start sqlite-backup-fixture.service")
        machine.succeed("systemctl is-failed sqlite-backup-fixture.service")
        machine.succeed("rm /var/lib/node-textfile; mv /var/lib/node-textfile.saved /var/lib/node-textfile")
  '';
}
