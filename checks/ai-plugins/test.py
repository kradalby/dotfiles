"""Exercise native installs, source updates, and OpenCode discovery in an isolated home."""

import json
import os
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import NotRequired, TypedDict, cast

import tomllib


class Marketplace(TypedDict):
    names: list[str]
    root: str


class Sources(TypedDict):
    codex: dict[str, Marketplace]
    opencode: dict[str, str]
    skills: dict[str, str]
    agents: str
    commands: str


class Installation(TypedDict):
    installedPath: str


class Plugin(TypedDict):
    pluginId: str
    enabled: bool


class PluginList(TypedDict):
    installed: list[Plugin]


class Enabled(TypedDict):
    enabled: bool
    mcp_servers: NotRequired[dict[str, "Enabled"]]


class Config(TypedDict):
    model: str
    plugins: dict[str, Enabled]


class Skill(TypedDict):
    name: str


class SkillList(TypedDict):
    data: list[Skill]


codex, opencode, installer, source_file = sys.argv[1:]
sources = cast(Sources, json.loads(Path(source_file).read_text()))
root = Path(tempfile.mkdtemp(prefix="ai-plugins-"))
env = os.environ.copy()
env.pop("CODEX_HOME", None)
env.update(
    {
        "HOME": str(root),
        "XDG_CONFIG_HOME": str(root / ".config"),
        "XDG_DATA_HOME": str(root / ".local/share"),
        "XDG_CACHE_HOME": str(root / ".cache"),
        "XDG_STATE_HOME": str(root / ".local/state"),
        "OPENCODE_DISABLE_MODELS_FETCH": "true",
        # A served instance demands a password from its clients.
        "OPENCODE_PASSWORD": "ai-plugins",
    }
)


def run(executable: str, *args: str | Path) -> str:
    result = subprocess.run(
        [executable, *map(str, args)],
        cwd=root,
        env=env,
        capture_output=True,
        text=True,
        timeout=120,
    )
    assert result.returncode == 0, result.stderr
    return result.stdout


config_path = root / ".codex/config.toml"
config_path.parent.mkdir()
config_path.write_text(
    '# User preference\nmodel = "user-model"\n'
    '[plugins."personal@custom"]\nenabled = false\n'
    '[plugins."update-probe@update-probe".mcp_servers.docs]\nenabled = false\n'
)
hooks_path = root / ".codex/hooks.json"
hooks_path.write_text('{"hooks": {"SessionStart": []}}\n')

legacy = root / "legacy"
(legacy / ".agents/plugins").mkdir(parents=True)
(legacy / ".agents/plugins/marketplace.json").write_text(
    json.dumps(
        {
            "name": "claude-code-plugins",
            "plugins": [
                {
                    "name": "frontend-design",
                    "source": {"source": "local", "path": "./frontend-design"},
                    "policy": {"installation": "AVAILABLE", "authentication": "ON_USE"},
                    "category": "Productivity",
                }
            ],
        }
    )
)
(legacy / "frontend-design").symlink_to(
    Path(sources["codex"]["claude-plugins-official"]["root"]) / "plugins/frontend-design"
)
run(codex, "plugin", "marketplace", "add", legacy)
old_frontend = cast(
    Installation,
    json.loads(run(codex, "plugin", "add", "frontend-design@claude-code-plugins", "--json")),
)
expected_ids: list[str] = []
for marketplace, source in sources["codex"].items():
    run(installer, source["root"])
    for name in source["names"]:
        plugin_id = f"{name}@{marketplace}"
        expected_ids.append(plugin_id)
        installation = cast(
            Installation, json.loads(run(codex, "plugin", "add", plugin_id, "--json"))
        )
        assert Path(installation["installedPath"]).is_dir()
        if name == "caveman":
            cached = Path(installation["installedPath"])
            hook = (cached / ".codex/hooks.json").read_text()
            assert "$PLUGIN_ROOT" in hook and "git rev-parse" not in hook
            hook_env = env | {"CAVEMAN_DEFAULT_MODE": "full"}
            activated = subprocess.run(
                ["node", str(cached / ".codex/codex-sessionstart.js")],
                cwd=root,
                env=hook_env,
                capture_output=True,
                text=True,
                check=True,
            )
            assert "CAVEMAN MODE ACTIVE" in activated.stdout
    installed = cast(
        PluginList, json.loads(run(codex, "plugin", "list", "--marketplace", marketplace, "--json"))
    )["installed"]
    assert {item["pluginId"] for item in installed} == {
        f"{name}@{marketplace}" for name in source["names"]
    }
    assert all(item["enabled"] for item in installed)
assert len(expected_ids) == 7
assert not Path(old_frontend["installedPath"]).exists()
# Fresh homes and repeated activation must handle an absent duplicate too.
run(installer, sources["codex"]["claude-plugins-official"]["root"])

# A source revision can change without an upstream plugin-version bump.
for revision in ["first", "second"]:
    catalog_root = root / revision
    plugin_root = catalog_root / "plugins/update-probe"
    (plugin_root / "skills/probe").mkdir(parents=True)
    (plugin_root / ".codex-plugin").mkdir()
    (plugin_root / ".codex-plugin/plugin.json").write_text(
        json.dumps(
            {
                "name": "update-probe",
                "version": "1.0.0",
                "description": "Update probe",
                "skills": "./skills/",
                "interface": {"displayName": "Update probe"},
            }
        )
    )
    (plugin_root / "skills/probe/SKILL.md").write_text(
        f"---\nname: probe\ndescription: Update probe\n---\n{revision}\n"
    )
    (catalog_root / ".agents/plugins").mkdir(parents=True)
    (catalog_root / ".agents/plugins/marketplace.json").write_text(
        json.dumps(
            {
                "name": "update-probe",
                "plugins": [
                    {
                        "name": "update-probe",
                        "source": {"source": "local", "path": "./plugins/update-probe"},
                        "policy": {
                            "installation": "INSTALLED_BY_DEFAULT",
                            "authentication": "ON_USE",
                        },
                        "category": "Productivity",
                    }
                ],
            }
        )
    )
    run(installer, catalog_root)
    installation = cast(
        Installation, json.loads(run(codex, "plugin", "add", "update-probe@update-probe", "--json"))
    )
    assert (
        (Path(installation["installedPath"]) / "skills/probe/SKILL.md")
        .read_text()
        .endswith(f"{revision}\n")
    )

config = cast(Config, tomllib.loads(config_path.read_text()))
assert config["model"] == "user-model"
assert config["plugins"]["personal@custom"]["enabled"] is False
assert (
    config["plugins"]["update-probe@update-probe"].get("mcp_servers", {})["docs"]["enabled"]
    is False
)
assert "# User preference" in config_path.read_text()
assert hooks_path.read_text() == '{"hooks": {"SessionStart": []}}\n'

opencode_root = root / ".config/opencode"
(opencode_root / "plugins").mkdir(parents=True)
(opencode_root / "skills").mkdir()
(opencode_root / "agents").mkdir()
for name, source in sources["opencode"].items():
    (opencode_root / f"plugins/{name}.js").symlink_to(source)
for name, source in sources["skills"].items():
    (opencode_root / f"skills/{name}").symlink_to(source)
for agent in Path(sources["agents"]).glob("*.md"):
    content = agent.read_text()
    frontmatter = content.split("---", 2)[1]
    assert "mode: subagent" in frontmatter
    assert "model:" not in frontmatter and "tools:" not in frontmatter
    (opencode_root / f"agents/{agent.name}").symlink_to(agent)
(opencode_root / "commands").symlink_to(sources["commands"])
(opencode_root / "opencode.json").write_text("{}\n")

# OpenCode answers before it has discovered plugins and skills, so poll a
# private server until the expected skills show up.
with socket.socket() as probe:
    probe.bind(("127.0.0.1", 0))
    port = str(probe.getsockname()[1])
url = f"http://127.0.0.1:{port}"
expected = {"ponytail", "brainstorming", "caveman", "frontend-design", "ui-ux-pro-max"}
expected_commands = {"caveman", "caveman-init", "code-review"}
skills: set[str] = set()
commands: set[str] = set()
server = subprocess.Popen(
    [opencode, "serve", "--hostname", "127.0.0.1", "--port", port],
    cwd=root,
    env=env,
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
)
try:
    deadline = time.monotonic() + 120
    while not (expected <= skills and expected_commands <= commands) and (
        time.monotonic() < deadline
    ):
        time.sleep(1)
        for operation in ("skill.list", "command.list"):
            # File stdout avoids truncation from OpenCode exiting before a large pipe flushes.
            with (root / "listing.json").open("w") as output:
                listed = subprocess.run(
                    [opencode, "api", operation, "--server", url],
                    cwd=root,
                    env=env,
                    stdout=output,
                    stderr=subprocess.DEVNULL,
                    timeout=60,
                )
            if listed.returncode != 0:
                continue
            try:
                response = cast(SkillList, json.loads((root / "listing.json").read_text()))
            except ValueError:
                continue
            names = {item["name"] for item in response["data"]}
            if operation == "skill.list":
                skills = names
            else:
                commands = names
finally:
    server.terminate()
    server.wait(timeout=30)
logs = "".join(p.read_text() for p in (root / ".local/share/opencode/log").glob("*.log"))
assert "failed to load plugin" not in logs, logs
assert expected <= skills, (sorted(expected - skills), logs[-4000:])
assert expected_commands <= commands, (sorted(expected_commands - commands), logs[-4000:])
print("Native installs, same-version updates, config preservation, and OpenCode discovery passed")
