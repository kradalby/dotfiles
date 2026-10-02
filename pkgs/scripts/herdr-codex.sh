#!/usr/bin/env bash
set -euo pipefail

# Remote Codex tools inherit the shared server's environment. Recover the
# caller from the thread identity reported by ac, never from UI focus or cwd.
if [[ "${HERDR_ENV:-}" != 1 ]]; then
  [[ -n "${CODEX_THREAD_ID:-}" ]] || {
    echo "herdr-codex: no Codex thread or inherited herdr context" >&2
    exit 1
  }
  sessions=$(herdr session list --json)
  matches='[]'
  while IFS= read -r session; do
    name=$(jq -r '.name' <<<"$session")
    socket=$(jq -r '.socket_path' <<<"$session")
    # A listed server can exit before it is queried.
    agents=$(herdr --session "$name" agent list 2>/dev/null) || continue
    found=$(jq -c --arg thread "$CODEX_THREAD_ID" --arg session "$name" --arg socket "$socket" '
      [.result.agents[] | select(.agent == "codex" and
        .agent_session.kind == "id" and .agent_session.value == $thread) |
        {HERDR_ENV:"1", HERDR_SESSION:$session, HERDR_SOCKET_PATH:$socket,
         HERDR_WORKSPACE_ID:.workspace_id, HERDR_TAB_ID:.tab_id, HERDR_PANE_ID:.pane_id}]' <<<"$agents")
    matches=$(jq -nc --argjson old "$matches" --argjson new "$found" '$old + $new')
  done < <(jq -c '.sessions[] | select(.running)' <<<"$sessions")
  if [[ "$(jq 'length' <<<"$matches")" != 1 ]]; then
    echo "herdr-codex: expected one live herdr pane for thread $CODEX_THREAD_ID; found $(jq 'length' <<<"$matches")" >&2
    exit 1
  fi
  exports=$(jq -r '.[0] | to_entries[] | "export \(.key)=\(.value | @sh)"' <<<"$matches")
  eval "$exports"
fi

if [[ "${1:-}" == --context ]]; then
  jq -nr '{HERDR_ENV:env.HERDR_ENV, HERDR_SESSION:env.HERDR_SESSION,
    HERDR_SOCKET_PATH:env.HERDR_SOCKET_PATH, HERDR_WORKSPACE_ID:env.HERDR_WORKSPACE_ID,
    HERDR_TAB_ID:env.HERDR_TAB_ID, HERDR_PANE_ID:env.HERDR_PANE_ID} |
    to_entries[] | select(.value != null) | "export \(.key)=\(.value | @sh)"'
else
  exec herdr "$@"
fi
