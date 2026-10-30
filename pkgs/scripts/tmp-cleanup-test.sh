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
for failure in fatal partial empty; do
  export LSOF_STATUS=0 LSOF_ERRORS='' LSOF_OUTPUT=$'p1\nn/somewhere\n'
  case "$failure" in
    fatal) LSOF_STATUS=127 LSOF_ERRORS='lsof unavailable' LSOF_OUTPUT='' ;;
    partial) LSOF_STATUS=1 LSOF_OUTPUT=$'p1\nn/tmp/unrelated\n' ;;
    empty) LSOF_OUTPUT='' ;;
  esac
  rc=0
  out=$(bash "$ROOT/cleanup.sh" -y 2>&1) || rc=$?
  [[ $rc == 1 && -d "$ROOT/tmp/nix-build-idle" && "$out" == *'refusing cleanup'* ]]
  echo "ok   $failure enumeration refuses deletion"
done

export LSOF_STATUS=0 LSOF_OUTPUT=$'p1\nn/somewhere\n'
export LSOF_ERRORS=$'lsof: WARNING: can\'t stat() overlay file system /merged\n'
out=$(bash "$ROOT/cleanup.sh" -f 101 2>&1)
[[ "$out" == *"[DRY]    $ROOT/tmp/nix-build-idle"* ]]
echo 'ok   mount warnings do not block cleanup'

# A here-string or mktemp needs room in /tmp, which is what this tool lacks.
if grep -nE '<<<|mktemp' "$SCRIPT"; then exit 1; fi
echo 'ok   lsof handling never writes to /tmp'

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

git init -q "$ROOT/tmp/hs-clean"
git init -q "$ROOT/tmp/hs-dirty"
echo x >"$ROOT/tmp/hs-dirty/edit"
touch -d '2 days ago' "$ROOT/tmp/hs-clean" "$ROOT/tmp/hs-dirty"

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

out=$(bash "$ROOT/cleanup.sh" -y -s 60 -f 101)
[[ "$out" == *"[DIRTY]  $ROOT/tmp/hs-dirty"* && -e "$ROOT/tmp/hs-dirty/edit" && ! -e "$ROOT/tmp/hs-clean" ]]
echo 'ok   uncommitted worktree survives, clean worktree goes'
[[ ! -e "$ROOT/tmp/nix-build-idle" && ! -e "$session_root/stale" ]]
[[ -d "$ROOT/tmp/nix-build-busy" && -d "$session_root/busy" && -d "$session_root/recent" ]]
echo 'ok   complete enumeration removes only stale, unused fixtures'

# Overflow scratch on disk: everything below is stale unless a test freshens it.
export HOME="$ROOT/home"
cache="$HOME/.cache"
git_q() { git -c user.name=t -c user.email=t@t "$@"; }
mkdir -p "$cache/idle-scratch/run" "$cache/yarn/v6" "$cache/live-cache/old" "$cache/shared-tmp/wt/done" \
  "$cache/shared-tmp/wt/live" "$cache/shared-tmp/wt/open" "$cache/shared-tmp/clone" \
  "$cache/shared-tmp/nested/deep" "$cache/shared-tmp/broken" "$HOME/e2e-tmp/run" "$HOME/project/src"
echo x >"$cache/shared-tmp/wt/live/fresh"
git init -q "$cache/shared-tmp/clone"
git_q -C "$cache/shared-tmp/clone" commit -q --allow-empty -m local
git init -q "$cache/shared-tmp/nested/deep"
echo x >"$cache/shared-tmp/nested/deep/edit"
echo 'gitdir: /nonexistent' >"$cache/shared-tmp/broken/.git"
find "$HOME" -path "$cache/shared-tmp/wt/live" -prune -o -exec touch -h -d '30 days ago' {} +
touch -d '30 days ago' "$cache/shared-tmp/wt/live"
echo x >"$cache/live-cache/fresh"

LSOF_OUTPUT=$(printf 'p1\nn%s\n' "$cache/shared-tmp/wt/open/held")
export LSOF_OUTPUT
bash "$ROOT/cleanup.sh" -f 101 >/dev/null
bash "$ROOT/cleanup.sh" -y -f 101 >/dev/null
[[ -d "$cache/idle-scratch" && -d "$HOME/e2e-tmp" ]]
echo 'ok   overflow scratch stays without -o'

out=$(bash "$ROOT/cleanup.sh" -o 7 -f 101)
[[ -d "$cache/idle-scratch" && "$out" == *"[DRY]    $cache/idle-scratch"* ]]
echo 'ok   overflow dry-run removes nothing'

bash "$ROOT/cleanup.sh" -y -o 7 -f 101 >/dev/null
[[ ! -e "$cache/idle-scratch" && ! -e "$cache/yarn" && ! -e "$HOME/e2e-tmp" ]]
echo 'ok   idle overflow folders go whole'
[[ ! -e "$cache/shared-tmp/wt/done" && -e "$cache/shared-tmp/wt/live/fresh" && -d "$cache/shared-tmp/wt/open" ]]
echo 'ok   shared root keeps live and open runs, drops finished ones'
[[ -d "$cache/live-cache/old" && -d "$HOME/project/src" ]]
echo 'ok   live cache and unrelated folders stay untouched'
[[ -d "$cache/shared-tmp/clone" && -e "$cache/shared-tmp/nested/deep/edit" && -d "$cache/shared-tmp/broken" ]]
echo 'ok   unpushed clone, nested dirty repo, unreadable repo all stay'
