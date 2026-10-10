import concurrent.futures
import contextlib
import hashlib
import lzma
import os
import shlex
import sqlite3
import subprocess
import sys
import threading
from pathlib import Path


def run(*args: str, success: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(args, check=False, capture_output=True, text=True)
    assert (result.returncode == 0) == success, (args, result.stdout, result.stderr)
    return result


def verify(archive: Path, destination: Path) -> None:
    destination.write_bytes(lzma.decompress(archive.read_bytes()))
    with contextlib.closing(sqlite3.connect(destination)) as database:
        assert database.execute("PRAGMA integrity_check").fetchone() == ("ok",)
        assert database.execute("SELECT value FROM entries WHERE id = 1").fetchone() == (
            "committed in WAL",
        )


def main() -> None:
    script, failure_script, metrics_command, root_arg = sys.argv[1:]
    root = Path(root_arg)
    root.mkdir(mode=0o700)
    source = root / "source ' quoted.db"
    archives = root / "archives ' quoted"
    metrics_dir = root / "metrics ' quoted"
    metrics_dir.mkdir()
    metrics_file = metrics_dir / "sqlite-backup-fixture.prom"
    metrics_args = shlex.split(metrics_command)
    metrics_args[0] = metrics_args[0].removeprefix("+")

    def report(result: str) -> dict[str, int]:
        run("env", f"SERVICE_RESULT={result}", *metrics_args)
        assert metrics_file.stat().st_mode & 0o777 == 0o644
        assert not list(metrics_dir.glob(".sqlite-backup.*"))
        return {
            line.split("{", 1)[0]: int(line.rsplit(" ", 1)[1])
            for line in metrics_file.read_text().splitlines()
            if not line.startswith("#")
        }

    # A missing database must never be silently created or backed up empty.
    run(script, success=False)
    assert not source.exists() and not archives.exists()
    initial = report("exit-code")
    assert initial["sqlite_backup_last_run_success"] == 0
    assert initial["sqlite_backup_last_success_timestamp_seconds"] == 0

    stop = threading.Event()
    ready = threading.Event()

    def writer() -> None:
        with contextlib.closing(sqlite3.connect(source)) as database:
            database.execute("PRAGMA journal_mode = WAL")
            database.execute("CREATE TABLE entries (id INTEGER PRIMARY KEY, value TEXT)")
            database.execute("INSERT INTO entries VALUES (1, 'committed in WAL')")
            database.commit()
            ready.set()
            while not stop.wait(0.005):
                database.execute("INSERT INTO entries (value) VALUES ('busy writer')")
                database.commit()

    # Concurrent producers must expose only complete compressed archives.
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        writing = pool.submit(writer)
        try:
            assert ready.wait(10), "writer did not start"
            assert Path(f"{source}-wal").stat().st_size > 0
            first = pool.submit(run, script)
            second = pool.submit(run, script)
            while not first.done() or not second.done():
                for archive in archives.glob("*.db.xz"):
                    verify(archive, root / "observed.db")
            first.result()
            second.result()
        finally:
            stop.set()
            writing.result(timeout=10)

    archive = next(archives.glob("fixture_backup_*.db.xz"))
    verify(archive, root / "restored.db")
    assert archive.stat().st_mode & 0o777 == 0o640
    assert archives.stat().st_mode & 0o777 == 0o750
    assert not list(archives.glob(".sqlite-backup.*"))
    successful = report("success")
    assert successful["sqlite_backup_last_run_success"] == 1
    last_success = successful["sqlite_backup_last_success_timestamp_seconds"]
    assert last_success > 0

    # Retention is per job, and happens only after a successful new snapshot.
    old = archives / "fixture_backup_20000101_000000.db.xz"
    unrelated = archives / "other_backup_20000101_000000.db.xz"
    for path in (old, unrelated):
        path.write_bytes(archive.read_bytes())
        os.utime(path, (0, 0))
    run(script)
    assert not old.exists() and unrelated.exists()
    known_good = {
        path.name: hashlib.sha256(path.read_bytes()).digest() for path in archives.iterdir()
    }

    # A compression failure must clean staging and preserve published archives.
    run(failure_script, success=False)
    failed = report("exit-code")
    assert failed["sqlite_backup_last_run_success"] == 0
    assert failed["sqlite_backup_last_success_timestamp_seconds"] == last_success
    assert known_good == {
        path.name: hashlib.sha256(path.read_bytes()).digest() for path in archives.iterdir()
    }

    source.write_bytes(b"not a SQLite database")
    run(script, success=False)
    assert report("exit-code")["sqlite_backup_last_success_timestamp_seconds"] == last_success
    source.unlink()
    run(script, success=False)
    assert report("exit-code")["sqlite_backup_last_success_timestamp_seconds"] == last_success
    assert not source.exists()
    assert known_good == {
        path.name: hashlib.sha256(path.read_bytes()).digest() for path in archives.iterdir()
    }

    # Failed metric publication must be visible as a failure, without replacing
    # the old complete result file or leaving partial textfiles to scrape.
    published = metrics_file.read_bytes()
    metrics_dir.chmod(0o500)
    try:
        run("env", "SERVICE_RESULT=success", *metrics_args, success=False)
        assert metrics_file.read_bytes() == published
    finally:
        metrics_dir.chmod(0o700)

    # Restic must carry the recoverable archives and other application state,
    # while excluding live SQLite files and unpublished staging directories.
    source.write_bytes(b"excluded live database")
    Path(f"{source}-wal").write_bytes(b"excluded WAL")
    Path(f"{source}-shm").write_bytes(b"excluded SHM")
    (root / "service-key").write_text("preserved application state")
    staging = archives / ".sqlite-backup.unpublished"
    staging.mkdir()
    (staging / "snapshot.db").write_bytes(b"partial")
    os.environ.update(
        RESTIC_REPOSITORY=str(root.parent / "sqlite-backup-restic"),
        RESTIC_PASSWORD="isolated-test-password",
        RESTIC_CACHE_DIR=str(root.parent / "sqlite-backup-cache"),
    )
    run("restic", "init")
    run(
        "restic",
        "backup",
        str(root),
        "--exclude",
        str(source),
        "--exclude",
        f"{source}-wal",
        "--exclude",
        f"{source}-shm",
        "--exclude",
        str(archives / ".sqlite-backup.*"),
    )
    destination = root.parent / "sqlite-backup-restic-restore"
    run("restic", "restore", f"latest:{root}", "--target", str(destination))
    restored_root = destination
    verify(restored_root / archive.relative_to(root), root / "from-restic.db")
    assert (restored_root / "service-key").read_text() == "preserved application state"
    assert not (restored_root / source.name).exists()
    assert not list((restored_root / archives.name).glob(".sqlite-backup.*"))
    print("SQLite WAL snapshots, atomic publication, failures, retention and Restic restore passed")


if __name__ == "__main__":
    main()
