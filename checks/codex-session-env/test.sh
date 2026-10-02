#!/usr/bin/env bash
# Probe expressions are evaluated by the child Bash, not this test driver.
# shellcheck disable=SC2016
set -euo pipefail
hook=$1
loader=$2
migrate=$3
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
export CODEX_HOME="$root/codex"
unset CODEX_SESSION_ID BASH_ENV
mkdir -p "$root/bin" "$root/one/child" "$root/two" "$root/flake" "$CODEX_HOME"
touch "$root/one/.envrc" "$root/two/.envrc" "$root/flake/flake.nix"

# Keep the boundary independent of Nix/network access; exercise the installed
# loader with hostile shell literals, unsets, and two simultaneous sessions.
printf '#!%s\n' "$(command -v bash)" >"$root/bin/direnv"
cat >>"$root/bin/direnv" <<'MOCK'
set -eu
printf '%s\n' "$PWD" >> "$CODEX_HOME/loads"
[[ ! -f "$CODEX_HOME/fail" ]] || exit 1
cat "$CODEX_HOME/changes.json"
MOCK
printf '#!%s\n' "$(command -v bash)" >"$root/bin/nix"
cat >>"$root/bin/nix" <<'MOCK'
set -eu
[[ "$*" == 'print-dev-env --json' ]]
printf '%s\n' '{"variables":{"DEV_TOOL":{"type":"exported","value":"from-flake"},"LOCAL_ONLY":{"type":"var","value":"hidden"}}}'
MOCK
chmod +x "$root/bin/direnv" "$root/bin/nix"
export PATH="$root/bin:$PATH"

start() {
  jq -n --arg id "$1" --arg cwd "$2" '{hook_event_name:"SessionStart",session_id:$id,cwd:$cwd}' | bash "$hook"
}
probe() {
  CODEX_THREAD_ID="$1" BASH_ENV="$loader" bash -c "$2"
}

export EXPECTED="quote ' and a newline
\$(touch $root/injected)"
jq -n --arg value "$EXPECTED" '{DEV_TOOL:$value,REMOVE_ME:null,BASH_ENV:"bad",CODEX_THREAD_ID:"wrong",HERDR_PANE_ID:"wrong"}' >"$CODEX_HOME/changes.json"
start one "$root/one/child"
export REMOVE_ME=old HERDR_PANE_ID=original
probe one '[[ "$DEV_TOOL" == "$EXPECTED" && ! -v REMOVE_ME && "$CODEX_THREAD_ID" == one && "$HERDR_PANE_ID" == original ]]'
probe one '[[ "$DEV_TOOL" == "$EXPECTED" ]]'
[[ ! -e "$root/injected" && $(wc -l <"$CODEX_HOME/loads") == 1 ]]
[[ $(stat -c %a "$CODEX_HOME/session-env") == 700 && $(stat -c %a "$CODEX_HOME/session-env/one.sh") == 600 ]]

printf '%s\n' '{"DEV_TOOL":"second"}' >"$CODEX_HOME/changes.json"
start two "$root/two"
probe two '[[ "$DEV_TOOL" == second ]]'
probe one '[[ "$DEV_TOOL" == "$EXPECTED" ]]'
CODEX_SESSION_ID=one probe descendant '[[ "$DEV_TOOL" == "$EXPECTED" && "$CODEX_THREAD_ID" == descendant ]]'

printf '%s\n' '{"DEV_TOOL":"refreshed"}' >"$CODEX_HOME/changes.json"
start one "$root/one"
probe one '[[ "$DEV_TOOL" == refreshed ]]'
probe two '[[ "$DEV_TOOL" == second ]]'
[[ $(wc -l <"$CODEX_HOME/loads") == 3 ]]
# No rewrite or evaluation on old tool payloads; invalid IDs cannot escape.
printf '%s\n' '{"hook_event_name":"PreToolUse","tool_name":"Bash"}' | bash "$hook"
if start ../escape "$root/one"; then exit 1; fi
[[ $(wc -l <"$CODEX_HOME/loads") == 3 ]]
# Loading errors invalidate stale snapshots instead of serving the old env.
touch "$CODEX_HOME/fail"
if start one "$root/one"; then exit 1; fi
[[ ! -e "$CODEX_HOME/session-env/one.sh" ]]
rm "$CODEX_HOME/fail"
start one "$root/flake"
probe one '[[ "$DEV_TOOL" == from-flake && ! -v LOCAL_ONLY ]]'
start one "$root"
probe one '[[ ! -v DEV_TOOL ]]'

# Migrate a copy of live configuration; preserve unrelated hooks and trust.
cat >"$CODEX_HOME/config.toml" <<'TOML'
# User comment
model = "existing-model"
[model_providers.custom]
base_url = "https://provider.invalid"
[shell_environment_policy.set]
CUSTOM = "keep"
[hooks.state."user-hook"]
trusted_hash = "preserve"
[[hooks.PreToolUse]]
matcher = "Bash"
[[hooks.PreToolUse.hooks]]
type = "command"
command = '"$HOME/.codex/hooks/nix-dev-env.sh"'
[[hooks.PreToolUse.hooks]]
type = "command"
command = "user-hook"
TOML
cat >"$CODEX_HOME/hooks.json" <<'JSON'
{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"herdr hook codex"}]}],"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"\"$HOME/.codex/hooks/nix-dev-env.sh\""},{"type":"command","command":"user-tool-hook"}]}]}}
JSON
cat >"$root/reference.json" <<'JSON'
{"hooks":{"SessionStart":[{"matcher":"^(startup|resume|clear|fork)$","hooks":[{"type":"command","command":"\"$HOME/.codex/hooks/nix-dev-env.sh\"","timeout":120}]}]}}
JSON
"$migrate" "$CODEX_HOME" "$root/reference.json"
python3 - "$CODEX_HOME" <<'PY'
import json
import sys
import tomllib
from pathlib import Path
root = Path(sys.argv[1])
text = (root / "config.toml").read_text()
config = tomllib.loads(text)
assert "# User comment" in text
assert config["model"] == "existing-model"
assert config["model_providers"]["custom"]["base_url"] == "https://provider.invalid"
assert config["shell_environment_policy"]["set"] == {"CUSTOM": "keep", "BASH_ENV": "$HOME/.codex/hooks/session-env.sh"}
assert config["hooks"]["state"]["user-hook"]["trusted_hash"] == "preserve"
assert config["hooks"]["PreToolUse"][0]["hooks"][0]["command"] == "user-hook"
hooks = json.loads((root / "hooks.json").read_text())["hooks"]
assert hooks["PreToolUse"][0]["hooks"][0]["command"] == "user-tool-hook"
assert hooks["SessionStart"][0]["hooks"][0]["command"] == "herdr hook codex"
assert len(hooks["SessionStart"]) == 2
PY
cp "$CODEX_HOME/config.toml" "$root/config.before"
cp "$CODEX_HOME/hooks.json" "$root/hooks.before"
"$migrate" "$CODEX_HOME" "$root/reference.json"
cmp "$CODEX_HOME/config.toml" "$root/config.before"
cmp "$CODEX_HOME/hooks.json" "$root/hooks.before"
printf '%s\n' 'Codex session environment and migration checks passed'
