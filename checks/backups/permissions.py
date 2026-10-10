"""Check fresh SQLite/WAL modes with the evaluated Kuma and replica umasks."""

import os
import sqlite3
import stat
import subprocess
import sys
from contextlib import closing
from pathlib import Path


def main() -> None:
    state = Path("fresh-kuma-state")
    state.mkdir()
    # Nix's sandbox forbids setting the setgid bit. The Nix assertions cover
    # it; run this fixture outside the sandbox too to exercise the full mode.
    mode = int(sys.argv[1], 8)
    if "--sandbox" in sys.argv[5:]:
        mode &= 0o777
    state.chmod(mode)
    assert stat.S_IMODE(state.stat().st_mode) == mode
    os.umask(int(sys.argv[2], 8))
    database = state / "kuma.db"
    subprocess.run([sys.argv[4]], check=True)
    with closing(sqlite3.connect(database)) as owner:
        assert owner.execute("SELECT value FROM items").fetchone() == (1,)
        owner.execute("PRAGMA journal_mode=WAL")
        with owner:
            owner.execute("UPDATE items SET value = 2")

    # Starting from an existing 0640 database must repair its mode without
    # losing application data or copying the template over it.
    database.chmod(0o640)
    subprocess.run([sys.argv[4]], check=True)

    # Close the owner first, so the replica is the first WAL/SHM creator.
    assert not Path(f"{database}-wal").exists()
    os.umask(int(sys.argv[3], 8))
    with closing(sqlite3.connect(database)) as replica:
        with replica:
            assert replica.execute("SELECT value FROM items").fetchone() == (2,)
            replica.execute("UPDATE items SET value = 3")
        for suffix in ("", "-wal", "-shm"):
            info = Path(f"{database}{suffix}").stat()
            assert stat.S_IMODE(info.st_mode) == 0o660
            assert info.st_gid == state.stat().st_gid
        os.umask(int(sys.argv[2], 8))
        with closing(sqlite3.connect(database)) as owner, owner:
            owner.execute("UPDATE items SET value = 4")
        assert replica.execute("SELECT value FROM items").fetchone() == (4,)
        assert replica.execute("PRAGMA integrity_check").fetchone() == ("ok",)


if __name__ == "__main__":
    main()
