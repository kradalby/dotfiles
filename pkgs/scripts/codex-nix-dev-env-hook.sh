#!/usr/bin/env bash
# Capture a thread's dev environment at startup/resume, without rewriting tools.
payload=$(cat)
[[ $(jq -r '.hook_event_name // empty' <<<"$payload") == SessionStart ]] || exit 0
thread_id=$(jq -r '.session_id // empty' <<<"$payload")
cwd=$(jq -r '.cwd // empty' <<<"$payload")
[[ "$thread_id" =~ ^[a-zA-Z0-9-]+$ && -d "$cwd" ]] || exit 1

umask 077
state_dir="${CODEX_HOME:-$HOME/.codex}/session-env"
mkdir -p "$state_dir"
chmod 700 "$state_dir"
# A failed refresh must not keep serving the previous project's environment.
rm -f "$state_dir/$thread_id.sh"
snapshot=$(mktemp "$state_dir/.${thread_id}.XXXXXX")
trap 'rm -f "$snapshot"' EXIT

# direnv finds a parent .envrc too; bare flakes retain the previous fallback.
project_dir="$cwd"
while [[ "$project_dir" != / && ! -f "$project_dir/.envrc" && ! -f "$project_dir/flake.nix" ]]; do
  project_dir=$(dirname "$project_dir")
done
if [[ -f "$project_dir/.envrc" ]]; then
  changes=$(cd "$cwd" && env -u BASH_ENV direnv export json) || exit 1
  changes=${changes:-\{\}}
elif [[ -f "$project_dir/flake.nix" ]]; then
  dev_env=$(cd "$project_dir" && env -u BASH_ENV nix print-dev-env --json) || exit 1
  changes=$(jq '[.variables | to_entries[] | select(.value.type == "exported") |
    {key:.key,value:.value.value}] | from_entries' <<<"$dev_env")
else
  changes='{}'
fi

# Quote values as shell literals, including newlines and apostrophes. Preserve
# Codex/herdr identity and shell bookkeeping when a tool chooses another cwd.
jq -r 'to_entries[] |
  select(.key | test("^[a-zA-Z_][a-zA-Z0-9_]*$")) |
  select(.key | test("^(BASH_ENV|PWD|OLDPWD|SHLVL|_|CODEX_THREAD_ID|CODEX_SESSION_ID|HERDR_.*)$") | not) |
  if .value == null then "unset \(.key)"
  else "export \(.key)=\(.value | @sh)" end' <<<"$changes" >"$snapshot" || exit 1
mv "$snapshot" "$state_dir/$thread_id.sh"
