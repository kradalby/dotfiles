# Codex PreToolUse hook: make every Bash command run inside the per-directory
# Nix dev env, mirroring the Claude Code nix-dev-env hook.
#
# Codex passes one JSON object on stdin (.tool_input.command, .cwd) and runs the
# rewritten command via `bash -lc <command>`. We wrap the original command so it
# executes inside the dev env:
#   .envrc present  -> `direnv exec <cwd> bash -c <orig>`   (nix-direnv cached)
#   else flake.nix  -> `nix develop <cwd> --command bash -c <orig>`
#   neither         -> no rewrite (exit 0, command runs unchanged)
#
# The original command is round-tripped through base64 to sidestep all quoting:
# the wrapper decodes it and feeds it to `bash -c`, so arbitrary quotes/newlines
# in the model's command survive intact.
payload="$(cat)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')"
cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty')"

[ -n "$cmd" ] || exit 0
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd="$PWD"

b64="$(printf '%s' "$cmd" | base64 -w0)"
decode="\$(printf %s '$b64' | base64 -d)"

if [ -f "$cwd/.envrc" ]; then
  new="direnv exec '$cwd' bash -c \"$decode\""
elif [ -f "$cwd/flake.nix" ]; then
  new="nix develop '$cwd' --command bash -c \"$decode\""
else
  exit 0
fi

jq -n --arg c "$new" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",updatedInput:{command:$c}}}'
