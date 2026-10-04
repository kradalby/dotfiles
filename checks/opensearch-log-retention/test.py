import copy
import http.server
import importlib.util
import json
import sys
import threading
import unittest
import urllib.error
import urllib.parse


spec = importlib.util.spec_from_file_location("retention", sys.argv[1])
retention = importlib.util.module_from_spec(spec)
spec.loader.exec_module(retention)
with open(sys.argv[2]) as policy_file:
    desired = json.load(policy_file)
sys.argv = [sys.argv[0]]


class RetentionTest(unittest.TestCase):
    def setUp(self) -> None:
        self.policy = None
        self.policy_seq_no = 7
        self.policy_primary_term = 2
        self.managed = {}
        self.changes = {}
        self.indices = ["garnix-build-logs-old", "garnix-system-old", "nginx-old", ".security"]
        self.calls = []
        self.failure = None
        test = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self, format: str, *args: object) -> None:
                pass

            def do_GET(self) -> None:
                self.handle_request()

            def do_PUT(self) -> None:
                self.handle_request()

            def do_POST(self) -> None:
                self.handle_request()

            def handle_request(self) -> None:
                parsed = urllib.parse.urlsplit(self.path)
                path = urllib.parse.unquote(parsed.path)
                body = (
                    json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                    if "Content-Length" in self.headers
                    else None
                )
                test.calls.append((self.command, path, parsed.query, body))
                status = 200
                if test.failure == "http":
                    status, result = 403, {"error": "forbidden"}
                elif path.startswith("/_plugins/_ism/policies/"):
                    if self.command == "PUT":
                        test.policy = copy.deepcopy(body["policy"])
                        test.policy_seq_no += 1
                        result = {"_id": retention.POLICY_ID}
                    elif test.policy is None:
                        status, result = 404, {"error": "missing policy"}
                    else:
                        # Model 2.19.6 serialization independently of the submitted JSON.
                        policy = copy.deepcopy(test.policy)
                        policy.update(
                            policy_id=retention.POLICY_ID,
                            schema_version=21,
                            last_updated_time=123,
                            error_notification=None,
                        )
                        for state in policy["states"]:
                            for action in state["actions"]:
                                retry = action.setdefault("retry", {})
                                retry.setdefault("count", 3)
                                retry.setdefault("backoff", "exponential")
                                retry.setdefault("delay", "1m")
                        for template in policy["ism_template"]:
                            template["last_updated_time"] = 123
                        result = {
                            "_seq_no": test.policy_seq_no,
                            "_primary_term": test.policy_primary_term,
                            "policy": policy,
                        }
                elif path.startswith("/_cat/indices/"):
                    result = [{"index": index} for index in test.indices]
                elif path.startswith("/_plugins/_ism/explain/"):
                    index = path.rsplit("/", 1)[1]
                    explanation = copy.deepcopy(
                        test.managed.get(
                            index,
                            {
                                "index.plugins.index_state_management.policy_id": None,
                                "index.opendistro.index_state_management.policy_id": None,
                                "enabled": None,
                            },
                        )
                    )
                    if urllib.parse.parse_qs(parsed.query).get("show_policy") != ["true"]:
                        explanation.pop("policy", None)
                    result = {index: explanation}
                elif path.startswith("/_plugins/_ism/add/"):
                    index = path.rsplit("/", 1)[1]
                    test.manage(index, seq_no=None, primary_term=None)
                    result = {"failures": test.failure == "partial-add", "failed_indices": []}
                elif path.startswith("/_plugins/_ism/change_policy/"):
                    index = path.rsplit("/", 1)[1]
                    # Policy changes are queued; PUT never mutates the applied version.
                    test.changes[index] = body
                    result = {"failures": test.failure == "partial-change", "failed_indices": []}
                else:
                    status, result = 404, {"error": "unexpected path"}
                data = json.dumps(result).encode()
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)

        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever)
        self.thread.start()
        self.base = f"http://127.0.0.1:{self.server.server_port}"

    def tearDown(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def manage(
        self,
        index: str,
        seq_no: int | None = 7,
        primary_term: int | None = 2,
        policy_id: str = retention.POLICY_ID,
        state: str = "hot",
    ) -> None:
        self.managed[index] = {
            "index.plugins.index_state_management.policy_id": policy_id,
            "index.opendistro.index_state_management.policy_id": policy_id,
            "policy_id": policy_id,
            "policy_seq_no": seq_no,
            "policy_primary_term": primary_term,
            "enabled": True,
            "state": {"name": state, "start_time": 111},
            "policy": copy.deepcopy(self.policy) if seq_no is not None else None,
        }

    def complete_jobs(self) -> None:
        for index, explanation in list(self.managed.items()):
            if explanation["policy_id"] != retention.POLICY_ID:
                continue
            if index not in self.changes and explanation.get("policy_seq_no") is not None:
                continue
            state = explanation["state"]
            self.manage(index, self.policy_seq_no, self.policy_primary_term)
            self.managed[index]["state"] = state
        self.changes.clear()

    def test_existing_and_future_logs_have_a_bounded_lifetime(self) -> None:
        retention.configure(self.base, desired)
        self.assertEqual(set(self.managed), set(self.indices[:-1]))
        hot, delete = self.policy["states"]
        self.assertEqual(hot["transitions"][0]["conditions"], {"min_index_age": "30d"})
        self.assertEqual(
            delete["actions"],
            [
                {
                    "delete": {},
                    "retry": {
                        "count": 3,
                        "backoff": "exponential",
                        "delay": "1m",
                    },
                }
            ],
        )
        self.assertEqual(
            self.policy["ism_template"][0]["index_patterns"],
            [
                "garnix-build-logs-*",
                "garnix-system-*",
                "nginx-*",
            ],
        )
        self.assertEqual(
            [method for method, path, *_ in self.calls if "/policies/" in path],
            ["GET", "PUT", "GET"],
        )
        self.assertTrue(
            all(
                query == "show_policy=true"
                for _, path, query, _ in self.calls
                if "/explain/" in path
            )
        )

    def test_normalized_get_does_not_update_or_reattach(self) -> None:
        retention.configure(self.base, desired)
        self.complete_jobs()
        # The server must supply the defaults itself, even if absent on disk.
        self.policy["states"][1]["actions"][0].pop("retry", None)
        self.calls.clear()
        retention.configure(self.base, desired)
        retention.configure(self.base, desired)
        self.assertTrue(all(method == "GET" for method, *_ in self.calls))

    def test_changed_policy_migrates_own_indices_without_resetting_state(self) -> None:
        self.policy = copy.deepcopy(desired["policy"])
        self.policy["states"][0]["transitions"][0]["conditions"] = {"min_index_age": "90d"}
        self.manage("garnix-build-logs-old", state="delete")
        original_state = copy.deepcopy(self.managed["garnix-build-logs-old"]["state"])
        retention.configure(self.base, desired)
        updates = [query for method, _, query, _ in self.calls if method == "PUT"]
        self.assertEqual(updates, ["if_seq_no=7&if_primary_term=2"])
        self.assertEqual(
            [method for method, path, *_ in self.calls if "/policies/" in path],
            ["GET", "PUT", "GET"],
        )
        self.assertEqual(
            self.changes, {"garnix-build-logs-old": {"policy_id": retention.POLICY_ID}}
        )
        self.assertEqual(
            self.managed["garnix-build-logs-old"]["policy"]["states"][0]["transitions"][0][
                "conditions"
            ],
            {"min_index_age": "90d"},
        )
        self.complete_jobs()
        applied = self.managed["garnix-build-logs-old"]
        self.assertEqual(applied["policy_seq_no"], 8)
        self.assertEqual(
            applied["policy"]["states"][0]["transitions"][0]["conditions"], {"min_index_age": "30d"}
        )
        self.assertEqual(applied["state"], original_state)
        self.calls.clear()
        retention.configure(self.base, desired)
        self.assertTrue(all(method == "GET" for method, *_ in self.calls))

    def test_stale_own_version_changes_even_without_a_policy_put(self) -> None:
        self.policy = copy.deepcopy(desired["policy"])
        self.indices = ["nginx-old"]
        for seq_no, primary_term in [(6, 2), (7, 1), (0, 2)]:
            with self.subTest(seq_no=seq_no, primary_term=primary_term):
                self.manage("nginx-old", seq_no, primary_term)
                self.calls.clear()
                self.changes.clear()
                retention.configure(self.base, desired)
                self.assertFalse(any(method == "PUT" for method, *_ in self.calls))
                self.assertEqual(self.changes, {"nginx-old": {"policy_id": retention.POLICY_ID}})

    def test_recreated_policy_uses_fresh_version_for_existing_jobs(self) -> None:
        self.indices = ["nginx-old"]
        self.manage("nginx-old")
        retention.configure(self.base, desired)
        self.assertEqual(self.policy_seq_no, 8)
        self.assertEqual(self.changes, {"nginx-old": {"policy_id": retention.POLICY_ID}})

    def test_pending_versions_do_not_add_or_change_jobs(self) -> None:
        self.policy = copy.deepcopy(desired["policy"])
        self.indices = ["nginx-old"]
        versions = [
            {},
            {"policy_seq_no": None, "policy_primary_term": None},
            {"policy_seq_no": 7},
            {"policy_primary_term": 2},
            {"policy_seq_no": -2, "policy_primary_term": 0},
            {"policy_seq_no": -2, "policy_primary_term": 2},
            {"policy_seq_no": 7, "policy_primary_term": 0},
        ]
        for version in versions:
            with self.subTest(version=version):
                self.manage("nginx-old", seq_no=None, primary_term=None)
                explanation = self.managed["nginx-old"]
                del explanation["policy_seq_no"], explanation["policy_primary_term"]
                explanation.update(version)
                self.calls.clear()
                retention.configure(self.base, desired)
                retention.configure(self.base, desired)
                self.assertTrue(all(method == "GET" for method, *_ in self.calls))

    def test_new_jobs_wait_for_initialization_after_a_policy_update(self) -> None:
        retention.configure(self.base, desired)
        self.policy["states"][0]["transitions"][0]["conditions"] = {"min_index_age": "90d"}
        self.calls.clear()
        retention.configure(self.base, desired)
        self.assertFalse(any(method == "POST" for method, *_ in self.calls))
        self.complete_jobs()
        self.calls.clear()
        retention.configure(self.base, desired)
        self.assertTrue(all(method == "GET" for method, *_ in self.calls))

    def test_legacy_policy_id_fields_identify_own_jobs(self) -> None:
        self.policy = copy.deepcopy(desired["policy"])
        self.indices = ["nginx-old"]
        for field in [
            "index.plugins.index_state_management.policy_id",
            "index.opendistro.index_state_management.policy_id",
        ]:
            with self.subTest(field=field):
                self.manage("nginx-old", seq_no=6)
                for key in [
                    "policy_id",
                    "index.plugins.index_state_management.policy_id",
                    "index.opendistro.index_state_management.policy_id",
                ]:
                    if key != field:
                        del self.managed["nginx-old"][key]
                self.changes.clear()
                retention.configure(self.base, desired)
                self.assertEqual(self.changes, {"nginx-old": {"policy_id": retention.POLICY_ID}})

    def test_existing_custom_policy_is_preserved(self) -> None:
        self.manage("nginx-old", policy_id="custom-policy", seq_no=0, primary_term=1)
        original = copy.deepcopy(self.managed["nginx-old"])
        retention.configure(self.base, desired)
        self.assertEqual(self.managed["nginx-old"], original)
        self.assertNotIn("nginx-old", self.changes)
        self.assertNotIn(".security", self.managed)

    def test_http_error_fails_the_service(self) -> None:
        self.failure = "http"
        with self.assertRaises(urllib.error.HTTPError):
            retention.configure(self.base, desired)

    def test_partial_attachment_failure_fails_the_service(self) -> None:
        self.failure = "partial-add"
        with self.assertRaises(RuntimeError):
            retention.configure(self.base, desired)

    def test_partial_policy_change_failure_fails_the_service(self) -> None:
        self.policy = copy.deepcopy(desired["policy"])
        self.manage("nginx-old", seq_no=6)
        self.indices = ["nginx-old"]
        self.failure = "partial-change"
        with self.assertRaises(RuntimeError):
            retention.configure(self.base, desired)


unittest.main()
