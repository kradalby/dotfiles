#!/usr/bin/env bash
# BASH_ENV is sourced by each Bash tool; direnv itself runs only in SessionStart.
# Shell snapshot capture can precede SessionStart, so a missing file is normal
# during initialization. Ordinary shells outside Codex have no thread ID.
_codex_env_id="${CODEX_SESSION_ID:-${CODEX_THREAD_ID:-}}"
if [[ "$_codex_env_id" =~ ^[a-zA-Z0-9-]+$ ]]; then
  # Descendant agents share the root session's environment and identity.
  _codex_session_env="${CODEX_HOME:-$HOME/.codex}/session-env/$_codex_env_id.sh"
  if [[ -f "$_codex_session_env" ]]; then
    # shellcheck disable=SC1090
    source "$_codex_session_env"
  fi
  unset _codex_session_env
fi
unset _codex_env_id
