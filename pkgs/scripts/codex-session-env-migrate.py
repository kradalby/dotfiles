#!/usr/bin/env python3
"""Replace the managed Bash rewrite hook while preserving client-owned config."""

import json
import os
import stat
import sys
import tempfile
from pathlib import Path
from typing import cast

import tomlkit
from tomlkit.items import Table
from tomlkit.toml_document import TOMLDocument

type JsonValue = None | bool | int | float | str | list[JsonValue] | dict[str, JsonValue]
type JsonObject = dict[str, JsonValue]


def atomic_write(path: Path, content: str) -> None:
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    fd, name = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(fd, "w") as handle:
            handle.write(content)
        os.chmod(name, mode)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def as_object(value: JsonValue) -> JsonObject:
    if not isinstance(value, dict):
        raise ValueError("Expected a JSON object")
    return value


def as_list(value: JsonValue) -> list[JsonValue]:
    if not isinstance(value, list):
        raise ValueError("Expected a JSON array")
    return value


def load_json(text: str) -> JsonObject:
    return as_object(cast(JsonValue, json.loads(text)))


def remove_managed_hook(hooks: JsonObject, event: str) -> None:
    groups: list[JsonValue] = []
    for value in as_list(hooks.get(event, [])):
        group = as_object(value)
        handlers = [
            handler
            for handler in as_list(group.get("hooks", []))
            if as_object(handler).get("command") != '"$HOME/.codex/hooks/nix-dev-env.sh"'
        ]
        if handlers:
            groups.append(dict(group, hooks=handlers))
    if groups:
        hooks[event] = groups
    elif event in hooks:
        del hooks[event]


def table(parent: TOMLDocument | Table, key: str) -> Table:
    if key not in parent:
        parent[key] = tomlkit.table()
    item = parent[key]
    if not isinstance(item, Table):
        raise ValueError(f"Expected a TOML table for {key}")
    return item


def main() -> None:
    root = Path(sys.argv[1])
    reference = load_json(Path(sys.argv[2]).read_text())
    config_path = root / "config.toml"
    config_text = config_path.read_text() if config_path.exists() else ""
    config = tomlkit.parse(config_text)
    table(table(config, "shell_environment_policy"), "set")["BASH_ENV"] = (
        "$HOME/.codex/hooks/session-env.sh"
    )
    table(config, "features")["hooks"] = True
    if "hooks" in config:
        inline_hooks = table(config, "hooks")
        values = cast(JsonObject, inline_hooks.unwrap())
        old_pre_tool = values.get("PreToolUse")
        remove_managed_hook(values, "PreToolUse")
        if values.get("PreToolUse") != old_pre_tool:
            if "PreToolUse" in values:
                inline_hooks["PreToolUse"] = values["PreToolUse"]
            else:
                del inline_hooks["PreToolUse"]
    new_config = config.as_string()
    if new_config != config_text:
        atomic_write(config_path, new_config)

    hooks_path = root / "hooks.json"
    hooks_text = hooks_path.read_text() if hooks_path.exists() else "{}"
    document = load_json(hooks_text)
    hooks = as_object(document.setdefault("hooks", {}))
    remove_managed_hook(hooks, "PreToolUse")
    remove_managed_hook(hooks, "SessionStart")
    as_list(hooks.setdefault("SessionStart", [])).extend(
        as_list(as_object(reference["hooks"])["SessionStart"])
    )
    new_hooks = json.dumps(document, indent=2) + "\n"
    if new_hooks != hooks_text:
        atomic_write(hooks_path, new_hooks)


if __name__ == "__main__":
    main()
