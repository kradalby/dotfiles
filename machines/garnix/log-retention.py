import fnmatch
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


POLICY_ID = "garnix-log-retention"


def request(base, method, path, body=None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        base + path,
        data=data,
        method=method,
        headers={"Content-Type": "application/json"},
    )
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=10) as response:
                result = json.load(response)
            if isinstance(result, dict) and result.get("failures", False):
                raise RuntimeError(f"{method} {path}: {result}")
            return result
        except urllib.error.HTTPError as error:
            if error.code not in (502, 503, 504) or attempt == 4:
                raise
        except urllib.error.URLError:
            if attempt == 4:
                raise
        time.sleep(2)


def without_metadata(value):
    if isinstance(value, dict):
        return {
            key: without_metadata(item)
            for key, item in value.items()
            if key not in ("last_updated_time", "policy_id", "schema_version")
        }
    if isinstance(value, list):
        return [without_metadata(item) for item in value]
    return value


def configure(base, desired):
    policy_path = f"/_plugins/_ism/policies/{POLICY_ID}"
    try:
        current = request(base, "GET", policy_path)
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
        request(base, "PUT", policy_path, desired)
        current = request(base, "GET", policy_path)
    else:
        fields = {key: current["policy"].get(key) for key in desired["policy"]}
        if without_metadata(fields) != without_metadata(desired["policy"]):
            version = urllib.parse.urlencode(
                {
                    "if_seq_no": current["_seq_no"],
                    "if_primary_term": current["_primary_term"],
                }
            )
            request(base, "PUT", f"{policy_path}?{version}", desired)
            current = request(base, "GET", policy_path)

    policy_version = (current["_seq_no"], current["_primary_term"])

    patterns = [
        pattern
        for template in desired["policy"]["ism_template"]
        for pattern in template["index_patterns"]
    ]
    query = urllib.parse.urlencode(
        {
            "format": "json",
            "h": "index",
            "ignore_unavailable": "true",
            "allow_no_indices": "true",
        }
    )
    indices = request(base, "GET", f"/_cat/indices/{','.join(patterns)}?{query}")
    for item in indices:
        index = item["index"]
        if not any(fnmatch.fnmatchcase(index, pattern) for pattern in patterns):
            continue
        escaped = urllib.parse.quote(index, safe="")
        explanation = request(base, "GET", f"/_plugins/_ism/explain/{escaped}?show_policy=true")[
            index
        ]
        policy_id = (
            explanation.get("policy_id")
            or explanation.get("index.plugins.index_state_management.policy_id")
            or explanation.get("index.opendistro.index_state_management.policy_id")
        )
        if not policy_id:
            request(base, "POST", f"/_plugins/_ism/add/{escaped}", {"policy_id": POLICY_ID})
            continue
        if policy_id != POLICY_ID:
            continue
        seq_no = explanation.get("policy_seq_no")
        primary_term = explanation.get("policy_primary_term")
        # Newly attached jobs have no applied version until ISM initializes them.
        if seq_no is None or primary_term is None or seq_no < 0 or primary_term <= 0:
            continue
        if (seq_no, primary_term) != policy_version:
            request(
                base, "POST", f"/_plugins/_ism/change_policy/{escaped}", {"policy_id": POLICY_ID}
            )


if __name__ == "__main__":
    with open(sys.argv[2]) as policy_file:
        configure(sys.argv[1].rstrip("/"), json.load(policy_file))
