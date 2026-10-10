#!/usr/bin/env bash
# Run destructive paths only against a private copy of /tmp.
set -euo pipefail

SCRIPT=${1:-$(dirname "$0")/tmp-cleanup.sh}
ROOT=$(mktemp -d)
trap 'rm -rf -- "$ROOT"' EXIT
mkdir -p "$ROOT/tmp" "$ROOT/bin"
sed "s@/tmp@$ROOT/tmp@g" "$SCRIPT" >"$ROOT/cleanup.sh"

cat >"$ROOT/bin/lsof" <<'MOCK'
#!/usr/bin/env bash
printf '%s' "${LSOF_OUTPUT:-}"
printf '%s' "${LSOF_ERRORS:-}" >&2
exit "${LSOF_STATUS:-0}"
MOCK
sed -i "1c#!$BASH" "$ROOT/bin/lsof"
chmod +x "$ROOT/bin/lsof"
export PATH="$ROOT/bin:$PATH"

mkdir -p "$ROOT/tmp/nix-build-idle"
touch -d '2 days ago' "$ROOT/tmp/nix-build-idle"
for failure in fatal partial warning empty; do
  export LSOF_STATUS=0 LSOF_ERRORS='' LSOF_OUTPUT=$'p1\nn/somewhere\n'
  case "$failure" in
    fatal) LSOF_STATUS=127 LSOF_ERRORS='lsof unavailable' LSOF_OUTPUT='' ;;
    partial) LSOF_STATUS=1 LSOF_OUTPUT=$'p1\nn/tmp/unrelated\n' ;;
    warning) LSOF_ERRORS='WARNING: cannot stat filesystem' ;;
    empty) LSOF_OUTPUT='' ;;
  esac
  rc=0
  out=$(bash "$ROOT/cleanup.sh" -y 2>&1) || rc=$?
  [[ $rc == 1 && -d "$ROOT/tmp/nix-build-idle" && "$out" == *'refusing cleanup'* ]]
  echo "ok   $failure enumeration refuses deletion"
done

session_root="$ROOT/tmp/claude-999999/-fixture"
mkdir -p "$session_root/stale/tasks" "$session_root/recent/tasks" "$session_root/busy/tasks" \
  "$ROOT/tmp/nix-build-busy"
echo x >"$session_root/stale/tasks/old.output"
echo x >"$session_root/recent/tasks/live.output"
echo x >"$session_root/busy/tasks/open.output"
touch -d '2 days ago' "$session_root/stale/tasks/old.output" "$session_root/stale/tasks" \
  "$session_root/stale" "$session_root/recent/tasks" "$session_root/recent" \
  "$session_root/busy/tasks/open.output" "$session_root/busy/tasks" "$session_root/busy" \
  "$ROOT/tmp/nix-build-busy"

export LSOF_STATUS=0 LSOF_ERRORS=''
# The copied script maps /private/tmp to /private<fixture>/tmp too.
for alias in '' /private; do
  LSOF_OUTPUT=$(printf 'p1\nn%s%s/nix-build-busy/open\nn%s%s/busy/tasks/open.output\n' \
    "$alias" "$ROOT/tmp" "$alias" "$session_root")
  out=$(bash "$ROOT/cleanup.sh" -s 60 -f 101)
  [[ "$out" == *"[BUSY]"* && "$out" == *"$session_root/stale"* ]]
  [[ "$out" != *"[DRY]    $session_root/recent "* ]]
  [[ "$out" != *"[DRY]    $session_root/busy "* ]]
  [[ "$out" != *"[DRY]    $ROOT/tmp/nix-build-busy "* ]]
  echo "ok   ${alias:-logical} paths protect open files and recent writes"
done

bash "$ROOT/cleanup.sh" -y -s 60 -f 101 >/dev/null
[[ ! -e "$ROOT/tmp/nix-build-idle" && ! -e "$session_root/stale" ]]
[[ -d "$ROOT/tmp/nix-build-busy" && -d "$session_root/busy" && -d "$session_root/recent" ]]
echo 'ok   complete enumeration removes only stale, unused fixtures'
