"""Verify exact native selections in a real isolated remote Codex TUI.

No model turns, production panes, user credentials, or live app-server are used.
"""

import json
import os
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time
from collections.abc import Callable
from pathlib import Path
from typing import cast

type JsonValue = None | bool | int | float | str | list[JsonValue] | dict[str, JsonValue]

AC = Path(sys.argv[1]).resolve()
WRAPPER = Path(sys.argv[2]).resolve()
HERDR = Path(shutil.which("herdr") or "herdr").resolve()
CODEX = Path(shutil.which("codex") or "codex").resolve()

with tempfile.TemporaryDirectory(prefix="ntui-", dir="/tmp") as temporary:
    fixture = Path(temporary)
    binary_dir = fixture / "bin"
    binary_dir.mkdir()
    (binary_dir / "herdr").symlink_to(HERDR)
    (binary_dir / "codex").symlink_to(CODEX)
    environment = {
        k: v
        for k, v in os.environ.items()
        if not k.startswith(("HERDR_", "CODEX_", "OPENAI_", "DIRENV_")) and k != "BASH_ENV"
    }
    environment.update(
        HOME=str(fixture / "home"),
        XDG_CONFIG_HOME=str(fixture / "config"),
        XDG_STATE_HOME=str(fixture / "state"),
        XDG_CACHE_HOME=str(fixture / "cache"),
        XDG_DATA_HOME=str(fixture / "data"),
        CODEX_HOME=str(fixture / "codex-home"),
        PATH=os.pathsep.join([str(binary_dir), environment["PATH"]]),
        TERM="xterm-256color",
    )
    for key in [
        "HOME",
        "XDG_CONFIG_HOME",
        "XDG_STATE_HOME",
        "XDG_CACHE_HOME",
        "XDG_DATA_HOME",
        "CODEX_HOME",
    ]:
        Path(environment[key]).mkdir(parents=True)
    project = fixture / "project"
    project.mkdir()
    (Path(environment["CODEX_HOME"]) / "config.toml").write_text(
        """model_provider = "review-local"
model = "review-model"
check_for_update_on_startup = false
[model_providers.review-local]
name = "Review local"
base_url = "http://127.0.0.1:9/v1"
wire_api = "responses"
requires_openai_auth = false
"""
        + f'\n[projects.{json.dumps(str(project))}]\ntrust_level = "trusted"\n'
    )
    config = fixture / "config/herdr"
    config.mkdir()
    (config / "config.toml").write_text(
        f'onboarding = false\n[terminal]\ndefault_shell = "{shutil.which("bash")}"\nshell_mode = "non_login"\n[update]\nversion_check = false\nmanifest_check = false\n'
    )
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    endpoint = f"ws://127.0.0.1:{port}"
    codex_log = (fixture / "app-server.log").open("w")
    server_log = (fixture / "herdr-server.log").open("w")
    # The shared server deliberately starts without any frontend HERDR variables.
    app_server = subprocess.Popen(
        [str(CODEX), "app-server", "--listen", endpoint],
        env=environment,
        cwd=project,
        stdout=codex_log,
        stderr=codex_log,
        start_new_session=True,
    )
    herdr_server: subprocess.Popen[bytes] | None = None
    socket_path = config / "sessions/native-tui/herdr.sock"

    def wait_for(predicate: Callable[[], bool], description: str, seconds: int = 20) -> None:
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(0.1)
        raise AssertionError(description)

    def listening() -> bool:
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=0.2):
                return True
        except OSError:
            return False

    def codex_function(command: str, *arguments: str) -> str:
        result = subprocess.run(
            ["bash", "-c", 'source "$1"; ' + command, "test", str(AC), *arguments],
            env=environment,
            cwd=project,
            capture_output=True,
            text=True,
            timeout=90,
        )
        assert result.returncode == 0, result.stderr
        return result.stdout.strip()

    def rpc(method: str, params: dict[str, JsonValue]) -> dict[str, JsonValue]:
        request = {"id": "native-tui-test", "method": method, "params": params}
        with socket.socket(socket.AF_UNIX) as stream:
            stream.settimeout(65)
            stream.connect(str(socket_path))
            stream.sendall((json.dumps(request) + "\n").encode())
            response = cast(dict[str, JsonValue], json.loads(stream.makefile().readline()))
        assert isinstance(response, dict) and "error" not in response, response
        result = response.get("result")
        assert isinstance(result, dict), response
        return result

    def context(thread: str) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            ["bash", str(WRAPPER), "--context"],
            env=environment | {"CODEX_THREAD_ID": thread},
            cwd=project,
            capture_output=True,
            text=True,
            timeout=10,
        )
        return result

    def current_agents() -> list[dict[str, JsonValue]]:
        agents = rpc("agent.list", {}).get("agents")
        assert isinstance(agents, list), agents
        result: list[dict[str, JsonValue]] = []
        for agent in agents:
            assert isinstance(agent, dict), agent
            result.append(agent)
        return result

    def bound_thread() -> str | None:
        selected: list[str] = []
        for agent in current_agents():
            if agent.get("agent") != "codex":
                continue
            session = agent.get("agent_session")
            if not isinstance(session, dict) or session.get("kind") != "id":
                continue
            value = session.get("value")
            assert isinstance(value, str), session
            assert session.get("source") == "herdr:codex", session
            selected.append(value)
        return selected[0] if len(selected) == 1 else None

    pane: str

    def start(thread: str) -> dict[str, JsonValue]:
        return rpc(
            "agent.start",
            {
                "pane_id": pane,
                "name": "native-tui",
                "kind": "codex",
                "args": ["--remote", endpoint, "--cd", str(project), "resume", thread],
                "timeout_ms": 60000,
            },
        )

    def slash(command: str) -> None:
        rpc("pane.send_input", {"pane_id": pane, "text": command, "keys": ["enter"]})

    try:
        wait_for(listening, "isolated app-server did not listen")
        threads = [
            codex_function(
                'codex_start_thread "$2" "$3" "$4"', str(project), "same-thread-title", endpoint
            )
            for _ in range(2)
        ]
        herdr_server = subprocess.Popen(
            [str(HERDR), "--session", "native-tui", "server"],
            env=environment,
            cwd=project,
            stdout=server_log,
            stderr=server_log,
            start_new_session=True,
        )
        wait_for(socket_path.exists, "isolated herdr did not listen")
        workspace = rpc(
            "workspace.create", {"cwd": str(project), "label": "native-tui", "focus": True}
        )
        root_pane = workspace.get("root_pane")
        assert isinstance(root_pane, dict), workspace
        pane_value = root_pane.get("pane_id")
        assert isinstance(pane_value, str), workspace
        pane = pane_value
        start(threads[0])
        wait_for(lambda: bound_thread() == threads[0], "native initial cold resume did not bind")
        first = context(threads[0])
        assert first.returncode == 0, first.stderr
        print(
            "PASS real remote TUI cold resume A -> exact context, shared server has no HERDR env",
            flush=True,
        )
        for thread, previous in [(threads[1], threads[0]), (threads[0], threads[1])]:
            slash("/resume " + thread)
            wait_for(
                lambda target=thread: bound_thread() == target,
                "native TUI switch did not report selected ID",
            )
            result = context(thread)
            assert result.returncode == 0 and result.stdout == first.stdout, result.stderr
            old = context(previous)
            assert old.returncode == 1 and "; found 0" in old.stderr, old.stderr
        print(
            "PASS real in-TUI A->B->A: exact selected ID, unchanged launch argv/cwd/pane; "
            "threads share a title, old ID found 0",
            flush=True,
        )
        slash("/quit")
        wait_for(
            lambda: not any(a.get("agent") == "codex" for a in current_agents()),
            "frontend did not exit",
        )
        start(threads[1])
        wait_for(
            lambda: bound_thread() == threads[1], "native frontend restart did not recover binding"
        )
        result = context(threads[1])
        assert result.returncode == 0 and result.stdout == first.stdout, result.stderr
        old = context(threads[0])
        assert old.returncode == 1 and "; found 0" in old.stderr, old.stderr
        print("PASS frontend exit + cold resume B restores exact shared-server context", flush=True)
    except Exception:
        for log in [fixture / "app-server.log", fixture / "herdr-server.log"]:
            print(f"{log.name}:\n{log.read_text()[-8000:]}", file=sys.stderr, flush=True)
        raise
    finally:
        for process in [herdr_server, app_server]:
            if process is not None and process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=5)
        codex_log.close()
        server_log.close()
