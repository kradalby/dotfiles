#!/usr/bin/env bash
# Every herdr action is mocked; these tests never contact a production pane.
set -euo pipefail

script=${1:-$(dirname "$0")/ac.sh}
# shellcheck disable=SC1090
source "$script"
root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
calls="$root/calls"
new_id=11111111-1111-4111-8111-111111111111
resume_id=22222222-2222-4222-8222-222222222222
switched_id=33333333-3333-4333-8333-333333333333
export AC_REMOTE_CONTROL=1 AC_CODEX_REMOTE=ws://review.invalid TEST_ROOT="$root"
mode=normal
reported_id="$resume_id"

hostname() { echo dev; }
server_running() { return 0; }
ensure_trusted_codex() { :; }
codex_start_thread() {
  echo '"created"' >>"$calls"
  echo "$new_id"
}
codex_connection() {
  [[ $1 == ws://review.invalid ]]
  local operation=$2
  shift 2
  "$operation" "$@"
}
request() {
  jq -nc --arg method "$2" --argjson params "$3" '{method:$method,params:$params}' >>"$calls"
  [[ $mode != missing ]] || return 1
  jq -nc --arg id "$reported_id" '{result:{thread:{id:$id}}}'
}
h() {
  jq -nc --args '$ARGS.positional' -- "$@" >>"$calls"
  case "$1 $2" in
    'pane get')
      jq -nc --arg dir "$root" --arg mode "$mode" '{result:{pane:{pane_id:"w1:p1",cwd:$dir,
        agent:(if $mode == "occupied" then "codex" else null end)}}}'
      ;;
    'agent start')
      [[ $mode != start-failed ]] || return 1
      if [[ $mode == switched ]]; then
        jq -nc --arg id "$switched_id" '{result:{agent:{agent_session:{source:"herdr:codex",agent:"codex",kind:"id",value:$id}}}}'
      else
        echo '{"result":{"agent":{}}}'
      fi
      ;;
    'pane report-agent-session') [[ $mode != bind-failed ]] ;;
    'agent list')
      jq -nc --arg mode "$mode" --arg id "$switched_id" '{result:{agents:[{workspace_id:"w1",pane_id:"w1:p1",tab_id:"t1",agent:"codex",
        agent_session:(if $mode == "bound" then {source:"herdr:codex",agent:"codex",kind:"id",value:$id} else null end)}]}}'
      ;;
    'workspace rename') : ;;
    *)
      echo "unexpected herdr call: $*" >&2
      return 1
      ;;
  esac
}

: >"$calls"
start_agent codex w1:p1 fixture "$root" fixture ''
grep -q '^"created"$' "$calls"
jq -se --arg id "$new_id" 'any(.[]; type == "array" and .[0:3] == ["pane","report-agent-session","w1:p1"] and .[-3:] == [$id,"--session-start-source","resume"])' "$calls" >/dev/null
echo 'ok   new thread launches still register their exact initial binding'

: >"$calls"
main codex-resume w1:p1 "$resume_id"
jq -se --arg id "$resume_id" '
  any(.[]; type == "object" and .method == "thread/resume" and .params == {threadId:$id}) and
  any(.[]; type == "array" and .[0:2] == ["agent","start"] and .[-6:] == ["--remote","ws://review.invalid","--cd",env.TEST_ROOT,"resume",$id]) and
  any(.[]; type == "array" and .[0:3] == ["pane","report-agent-session","w1:p1"] and .[-3:] == [$id,"--session-start-source","resume"])
' "$calls" >/dev/null
# No new thread should have been created to satisfy an explicit resume.
if grep -q created "$calls"; then exit 1; fi
echo 'ok   explicit resume preserves the exact ID and remote endpoint, then binds it'

for mode in occupied missing mismatch start-failed bind-failed; do
  : >"$calls"
  reported_id="$resume_id"
  [[ $mode != mismatch ]] || reported_id="$switched_id"
  if (cmd_codex_resume w1:p1 "$resume_id") >"$root/out" 2>&1; then
    echo "FAIL $mode resume unexpectedly succeeded" >&2
    exit 1
  fi
  case "$mode" in
    occupied | missing | mismatch)
      jq -se 'all(.[]; type != "array" or .[0:2] != ["agent","start"])' "$calls" >/dev/null
      ;;
    start-failed)
      jq -se 'all(.[]; type != "array" or .[0:2] != ["pane","report-agent-session"])' "$calls" >/dev/null
      ;;
  esac
  echo "ok   $mode resume fails without fabricating a binding"
done

mode=normal
: >"$calls"
if (cmd_codex_resume w1:p1 'some-thread-title') >"$root/out" 2>&1; then exit 1; fi
[[ ! -s "$calls" ]]
echo 'ok   thread titles and UUID prefixes are rejected before any pane operation'

mode=switched
: >"$calls"
cmd_codex_resume w1:p1 "$resume_id"
jq -se 'all(.[]; type != "array" or .[0:2] != ["pane","report-agent-session"])' "$calls" >/dev/null
echo 'ok   startup preserves a newer native thread binding'

for mode in normal bound; do
  : >"$calls"
  ensure_session_agents w1 "$root" fixture '' codex >"$root/out" 2>"$root/err"
  jq -se 'all(.[]; type != "array" or (.[0:2] != ["pane","report-agent-session"] and .[0:2] != ["agent","start"]))' "$calls" >/dev/null
  if [[ $mode == normal ]]; then
    grep -q 'no exact thread binding' "$root/err"
  else
    [[ ! -s "$root/err" ]]
  fi
  echo "ok   $mode reconciliation preserves live panes and never infers thread identity"
done
