import concurrent.futures
import http.server
import os
import pathlib
import subprocess
import sys
import tempfile
import threading
import time


def environment(root: pathlib.Path) -> dict[str, str]:
    root.mkdir()
    env = dict(os.environ)
    env.pop("BASH_ENV", None)
    env.pop("ENV", None)
    return {
        **env,
        "HOME": str(root),
        "TMPDIR": str(root),
        "APERTURE_OPENCODE_CONFIG": str(root / "opencode.json"),
        "APERTURE_HERMES_CONFIG": str(root / "config.yaml"),
        "NO_PROXY": "127.0.0.1,localhost",
        "no_proxy": "127.0.0.1,localhost",
    }


def refresh(script: str, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run([script], env=env, capture_output=True, text=True, timeout=25)


def assert_fallback(result: subprocess.CompletedProcess[str], *, cached: bool) -> None:
    assert result.returncode == (0 if cached else 1), result.stderr
    message = "keeping the last-known-good" if cached else "no valid managed config pair exists"
    assert message in result.stderr, result.stderr


def main() -> None:
    script, valid_response = sys.argv[1:]
    with tempfile.TemporaryDirectory() as directory:
        root = pathlib.Path(directory)
        cached_env = environment(root / "cached")
        fresh_env = environment(root / "fresh")
        seed = refresh(
            script,
            {**cached_env, "APERTURE_AGENT_CONFIG_URL": pathlib.Path(valid_response).as_uri()},
        )
        assert seed.returncode == 0, seed.stderr
        targets = [
            pathlib.Path(cached_env["APERTURE_OPENCODE_CONFIG"]),
            pathlib.Path(cached_env["APERTURE_HERMES_CONFIG"]),
        ]
        before = [target.read_bytes() for target in targets]

        stub = root / "timeout.sh"
        stub.write_text(
            "curl() {\n"
            '  case " $* " in\n'
            '    *" --connect-timeout 5 "*) ;; *) return 97 ;; esac\n'
            '  case " $* " in\n'
            '    *" --max-time 20 "*) ;; *) return 97 ;; esac\n'
            '  echo "fixture: curl timed out" >&2\n'
            "  return 28\n"
            "}\n"
        )
        for cached, env in [(True, cached_env), (False, fresh_env)]:
            result = refresh(
                script,
                {**env, "BASH_ENV": str(stub), "APERTURE_AGENT_CONFIG_URL": "http://127.0.0.1:1/"},
            )
            assert "fixture: curl timed out" in result.stderr, result.stderr
            assert_fallback(result, cached=cached)
            print(f"timeout stub: cached={cached} passed")

        release = threading.Event()
        requests: list[str] = []

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self) -> None:
                requests.append(self.path)
                release.wait(30)

            def log_message(self, format: str, *args: object) -> None:
                pass

        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        server.daemon_threads = True
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        url = f"http://127.0.0.1:{server.server_port}/agent-config"

        def stalled_refresh(cached: bool, env: dict[str, str]) -> None:
            started = time.monotonic()
            result = refresh(script, {**env, "APERTURE_AGENT_CONFIG_URL": url})
            elapsed = time.monotonic() - started
            assert "curl: (28)" in result.stderr, result.stderr
            assert 18 <= elapsed < 25, elapsed
            assert_fallback(result, cached=cached)
            print(f"stalled HTTP: cached={cached} passed in {elapsed:.1f}s")

        try:
            with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
                futures = [
                    executor.submit(stalled_refresh, cached, env)
                    for cached, env in [(True, cached_env), (False, fresh_env)]
                ]
                for future in futures:
                    future.result()
        finally:
            release.set()
            server.shutdown()
            server.server_close()
            thread.join()
        assert requests == ["/agent-config", "/agent-config"], requests
        assert before == [target.read_bytes() for target in targets]
        assert not pathlib.Path(fresh_env["APERTURE_OPENCODE_CONFIG"]).exists()
        assert not pathlib.Path(fresh_env["APERTURE_HERMES_CONFIG"]).exists()


if __name__ == "__main__":
    main()
