#!/usr/bin/env python3
"""Check exact cold resumes and saved permissions without model turns or live services."""

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from uuid import UUID

script = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).with_name("ac.sh")).resolve()
with tempfile.TemporaryDirectory(prefix="ac-thread-test-") as temporary:
    root = Path(temporary)
    home = root / "codex"
    project = root / "project"
    home.mkdir()
    project.mkdir()
    (home / "config.toml").write_text("""model_provider = "review-local"
model = "review-model"
default_permissions = ":read-only"
approval_policy = "on-request"
[model_providers.review-local]
name = "Review local"
base_url = "http://127.0.0.1:9/v1"
wire_api = "responses"
requires_openai_auth = false
""")
    env = {
        k: v
        for k, v in os.environ.items()
        if not k.startswith(("CODEX_", "HERDR_", "OPENAI_", "DIRENV_")) and k != "BASH_ENV"
    }
    env.update(
        HOME=str(root),
        CODEX_HOME=str(home),
        XDG_CONFIG_HOME=str(root / "config"),
        XDG_CACHE_HOME=str(root / "cache"),
        XDG_DATA_HOME=str(root / "data"),
    )

    def run(command: str, *arguments: str) -> str:
        result = subprocess.run(
            ["bash", "-c", 'source "$1"; ' + command, "test", str(script), *arguments],
            cwd=root,
            env=env,
            capture_output=True,
            text=True,
            timeout=30,
        )
        assert result.returncode == 0, result.stderr
        return result.stdout.strip()

    thread_id = run('codex_start_thread "$2" isolated-review ""', str(project))
    assert str(UUID(thread_id)) == thread_id
    # Each call opens a new standalone app-server, forcing a cold disk-backed resume.
    assert run('codex_connection "" codex_resume_thread "$2"', thread_id) == thread_id
    params = json.dumps({"threadId": thread_id})
    resumed = json.loads(run('codex_connection "" request 1 thread/resume "$2"', params))["result"]
    assert resumed["thread"]["id"] == thread_id
    assert resumed["approvalPolicy"] == "never"
    assert resumed["sandbox"]["type"] == "dangerFullAccess"
    assert resumed["thread"]["cwd"] == str(project)
    assert resumed["thread"]["name"] == "isolated-review"
    print("ok   cold exact resume retains thread identity, name, cwd, and explicit permissions")
