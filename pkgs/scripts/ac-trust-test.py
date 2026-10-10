#!/usr/bin/env python3
"""Exercise the pinned Codex TOML writer with an isolated, unauthenticated home."""

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import tomllib

script = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).with_name("ac.sh")).resolve()
with tempfile.TemporaryDirectory(prefix="ac-trust-test-") as temporary:
    root = Path(temporary)
    project = root / 'project with.space"quote\\backslash'
    project.mkdir()
    new_project = root / "new project.with[brackets]\"double'single\\backslash"
    new_project.mkdir()
    other = str(root / "other")
    prefix = """# Keep the user configuration comment.
model_provider = "review-local"
model = "review-model"
[model_providers.review-local]
name = "Review local"
base_url = "http://127.0.0.1:9/v1"
wire_api = "responses"
requires_openai_auth = false
"""
    key = json.dumps(str(project))
    fixtures = {
        "existing untrusted": (
            project,
            f'[projects.{key}]\ntrust_level = "untrusted"\nnote = "keep"\n',
        ),
        "literal table": (
            project,
            f"[projects.'{project}']\ntrust_level = 'untrusted'\nnote = 'keep'\n",
        ),
        "inline table": (project, f'{key} = {{ trust_level = "untrusted", note = "keep" }}\n'),
        "dotted assignment": (project, f'{key}.trust_level = "untrusted"\n{key}.note = "keep"\n'),
        "missing trust field": (project, f'[projects.{key}]\nnote = "keep"\n'),
        "new project": (project, ""),
        "new quoted project": (new_project, ""),
    }
    unrelated = (
        f"{json.dumps(other)} = {{ trust_level = 'untrusted', note = 'keep quoting' }}"
        " # Keep the unrelated project comment.\n"
    )
    env = {
        k: v
        for k, v in os.environ.items()
        if not k.startswith(("CODEX_", "HERDR_", "OPENAI_", "DIRENV_"))
        and k not in ("BASH_ENV", "AC_TRUST")
    }
    env.update(
        HOME=str(root),
        XDG_CONFIG_HOME=str(root / "config"),
        XDG_CACHE_HOME=str(root / "cache"),
        XDG_DATA_HOME=str(root / "data"),
    )

    def trust(
        home: Path, enabled: str = "1", target: Path = project
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                "bash",
                "-c",
                'source "$1"; ensure_trusted_codex "$2"',
                "test",
                str(script),
                str(target),
            ],
            cwd=root,
            env={**env, "CODEX_HOME": str(home), "AC_TRUST": enabled},
            capture_output=True,
            text=True,
            timeout=30,
        )

    for name, (target, body) in fixtures.items():
        home = root / name
        home.mkdir()
        config = home / "config.toml"
        original = prefix + "[projects]\n" + unrelated + body
        config.write_text(original)
        expected = tomllib.loads(original)
        expected.setdefault("projects", {}).setdefault(str(target), {})["trust_level"] = "trusted"
        result = trust(home, target=target)
        assert result.returncode == 0, (name, result.stderr)
        updated = config.read_text()
        assert tomllib.loads(updated) == expected, name
        assert "# Keep the user configuration comment." in updated, name
        assert unrelated in updated, name
        result = trust(home, target=target)
        assert result.returncode == 0, (name, result.stderr)
        assert config.read_text() == updated, name
        print(f"ok   {name}: valid TOML, preserved fields, idempotent update")

    home = root / "invalid"
    home.mkdir()
    config = home / "config.toml"
    config.write_text('model = "unterminated\n')
    original = config.read_bytes()
    assert trust(home).returncode != 0
    assert config.read_bytes() == original
    assert trust(home, "0").returncode == 0
    assert config.read_bytes() == original
    print("ok   invalid TOML fails without modification; AC_TRUST=0 skips editing")
