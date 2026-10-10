import http.server
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import threading


def probe(script: pathlib.Path, platform: str, case: str, curl: str, bash: str) -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = pathlib.Path(directory)
        (root / "config").mkdir()
        (root / "runtime").mkdir()
        key = "" if case == "empty-key" else "fixture-key"
        xml = f"<configuration><gui><apikey>{key}</apikey></gui></configuration>"
        (root / "config/config.xml").write_text("<" if case == "invalid-xml" else xml)
        if case == "late-config":
            (root / "config/config.xml").unlink()
            threading.Timer(0.1, lambda: (root / "config/config.xml").write_text(xml)).start()
        (root / "encryption-password").write_text("fixture-secret")
        (root / "gui-password").write_text("fixture-password")
        if case == "missing-secret":
            (root / "encryption-password").unlink()
        if case == "missing-password":
            (root / "gui-password").unlink()
        requests: list[tuple[str, str]] = []
        writes = 0
        reads = 0

        class Handler(http.server.BaseHTTPRequestHandler):
            def respond(self) -> None:
                nonlocal writes, reads
                requests.append((self.command, self.path))
                status = 200
                body: object = {}
                if self.command == "GET":
                    reads += 1
                    if self.path.endswith("restart-required"):
                        body = {"requiresRestart": case != "no-restart"}
                        if case == "restart-http":
                            status = 500
                        if case == "restart-malformed":
                            body = {"requiresRestart": None}
                    elif self.path == "/rest/config":
                        body = {"devices": [], "folders": []}
                    else:
                        body = []
                    if case == "get-http":
                        status = 500
                    if case == "transient-get-http" and reads == 1:
                        status = 503
                        body = {"error": "temporarily unavailable"}
                    if case == "config-malformed" and not self.path.endswith("restart-required"):
                        body = "invalid"
                else:
                    length = int(self.headers.get("Content-Length", "0"))
                    payload = self.rfile.read(length)
                    if payload:
                        try:
                            json.loads(payload)
                        except json.JSONDecodeError:
                            status = 400
                    writes += 1
                    if case == "update-http":
                        status = 400
                    if case == "transient-http" and writes == 1:
                        status = 503
                self.send_response(status)
                self.end_headers()
                self.wfile.write(json.dumps(body).encode())

            def do_GET(self) -> None:
                self.respond()

            def do_POST(self) -> None:
                self.respond()

            def do_PUT(self) -> None:
                self.respond()

            def do_PATCH(self) -> None:
                self.respond()

            def log_message(self, format: str, *args: object) -> None:
                pass

        server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        wrapper = root / "curl"
        # Bound the existing retry budget; all other curl flags and real HTTP remain unchanged.
        wrapper.write_text(
            f"#!{bash}\n"
            'args=()\nwhile [ "$#" -gt 0 ]; do\n'
            'case "$1" in\n'
            "--retry) args+=(--retry 1); shift 2 ;;\n"
            "--retry-delay) args+=(--retry-delay 0); shift 2 ;;\n"
            '*) args+=("$1"); shift ;;\nesac\ndone\n'
            f'exec {curl} "${{args[@]}}"\n'
        )
        wrapper.chmod(0o700)
        candidate = root / "initializer"
        candidate.write_text(
            script.read_text()
            .replace("/fixture", str(root))
            .replace("http://127.0.0.1:1", f"http://127.0.0.1:{server.server_port}")
            .replace(curl, str(wrapper))
        )
        env = {**os.environ, "RUNTIME_DIRECTORY": str(root / "runtime")}
        env.pop("BASH_ENV", None)
        env.pop("ENV", None)
        try:
            result = subprocess.run(
                [bash, str(candidate)], env=env, capture_output=True, text=True, timeout=10
            )
        finally:
            server.shutdown()
            server.server_close()
            thread.join()
        expected_success = case in {
            "success",
            "transient-http",
            "no-restart",
            "late-config",
            "transient-get-http",
        }
        assert (result.returncode == 0) == expected_success, (
            platform,
            case,
            result.returncode,
            result.stdout,
            result.stderr,
        )
        if case in {"empty-key", "invalid-xml"}:
            assert not requests, (platform, case, requests)
        if case == "missing-secret":
            assert ("POST", "/rest/config/folders") not in requests, requests
        if case == "missing-password":
            assert not any(method == "PATCH" for method, _ in requests), requests
        if expected_success:
            assert (("POST", "/rest/system/restart") in requests) == (case != "no-restart"), (
                requests
            )
        if case == "transient-http":
            write_requests = [(method, path) for method, path in requests if method != "GET"]
            assert write_requests[0] == write_requests[1], requests
        print(f"{platform}: {case} passed")


def main() -> None:
    linux, darwin, curl, bash = sys.argv[1:]
    cases = [
        "success",
        "no-restart",
        "late-config",
        "config-malformed",
        "empty-key",
        "invalid-xml",
        "get-http",
        "update-http",
        "restart-http",
        "restart-malformed",
        "transient-http",
        "transient-get-http",
    ]
    for platform, script in [("linux", linux), ("darwin", darwin)]:
        for case in cases + (["missing-secret", "missing-password"] if platform == "linux" else []):
            probe(pathlib.Path(script), platform, case, curl, bash)


if __name__ == "__main__":
    main()
