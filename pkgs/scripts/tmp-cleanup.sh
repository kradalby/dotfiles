#!/usr/bin/env bash
# Prune stale entries from /tmp. Dry-run by default; lsof guard skips live state.
# writeShellApplication injects `set -e -u -o pipefail`; we relax errexit and
# pipefail because lsof / du / find legitimately return nonzero on root-owned
# dirs an unprivileged user cannot read. Errors are handled explicitly.
set +o errexit +o pipefail
set -o nounset

DIR_PATTERNS=(
  'nix-shell.*'
  'nix-build-*'
  'nix-develop-*'
  'auth-agent*'
  'colmena-assets-*'
  'claude-*'
  'commit-stash'
  'go-build*'
  'go-test-*'
  'go-link-*'
  'gopls-*'
  '_home_*'
  'hs-*'
  'integration-*'
  'headscale-*'
  'tmp.*'
  'org.chromium.*'
  'TemporaryDirectory.*'
  'Test*'
  'pyright-*'
  'uv-*'
)

FILE_PATTERNS=(
  '*.log'
  '*.tsv'
  '*.json'
  '*.txt'
  '*.md'
  '*.sh'
  '*.swift'
  '*.sql'
  '*.sql.*'
  '*.awk'
  '*.bak'
  '*.out'
  '*.err'
  '.*-*.so'
)

SKIP_PATTERNS=(
  '.X11-unix'
  '.ICE-unix'
  '.font-unix'
  '.XIM-unix'
  'systemd-private-*'
  'claude-[0-9]*'
)

EXECUTE=0
AGE_MIN=20
SESSION_AGE_MIN=480
VERBOSE=0
USE_LSOF=1

usage() {
  cat <<EOF
tmp-cleanup — prune stale entries from /tmp.

USAGE
  tmp-cleanup [-y|--execute] [-d MINUTES] [-s MINUTES] [-v] [--no-lsof]
              [-h|--help]

OPTIONS
  -y, --execute    actually delete (default: dry-run)
  -d MINUTES       age threshold in minutes (default: 20)
  -s MINUTES       claude session-scratch threshold (default: 480)
  -v               verbose: also list KEEP entries
  --no-lsof        skip lsof guard (NOT recommended)
  -h, --help       this help

WHAT GETS REMOVED (when older than threshold AND not held open by lsof)
  Directories:
$(printf '    %s\n' "${DIR_PATTERNS[@]}")
  Files (top-level only):
$(printf '    %s\n' "${FILE_PATTERNS[@]}")

  Claude session scratch (older than -s AND no open fd):
    /tmp/claude-<pid>/<project>/<session-uuid>

NEVER TOUCHED (regardless of age or pattern)
$(printf '    %s\n' "${SKIP_PATTERNS[@]}")

SAFETY
  Default mode is dry-run; pass -y to actually delete.
  lsof guard skips any path with an open file descriptor — it is the
  real safety net, not the age threshold. Use --no-lsof at your peril.

EXAMPLES
  tmp-cleanup                  # preview what would go
  tmp-cleanup -y               # actually clean
  tmp-cleanup -d 1440 -v       # one-day threshold, verbose
  tmp-cleanup -y -s 240        # also drop session scratch idle 4h+
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -y | --execute) EXECUTE=1 ;;
    -d)
      shift
      [ $# -gt 0 ] || {
        echo "tmp-cleanup: -d needs a value" >&2
        exit 2
      }
      AGE_MIN="$1"
      ;;
    -s)
      shift
      [ $# -gt 0 ] || {
        echo "tmp-cleanup: -s needs a value" >&2
        exit 2
      }
      SESSION_AGE_MIN="$1"
      ;;
    -v) VERBOSE=1 ;;
    --no-lsof) USE_LSOF=0 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "tmp-cleanup: unknown arg: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

case "$AGE_MIN" in
  '' | *[!0-9]*)
    echo "tmp-cleanup: -d needs a non-negative integer (minutes), got: $AGE_MIN" >&2
    exit 2
    ;;
esac

case "$SESSION_AGE_MIN" in
  '' | *[!0-9]*)
    echo "tmp-cleanup: -s needs a non-negative integer (minutes), got: $SESSION_AGE_MIN" >&2
    exit 2
    ;;
esac

match_any() {
  local name=$1
  shift
  local p
  for p in "$@"; do
    # shellcheck disable=SC2254
    case "$name" in $p) return 0 ;; esac
  done
  return 1
}

is_old() {
  local found
  found=$(find "$1" -maxdepth 0 -mmin +"$AGE_MIN" -print 2>/dev/null || true)
  [ -n "$found" ]
}

declare -A BUSY_NAMES=()
BUSY_PATHS=()
if [ "$USE_LSOF" -eq 1 ]; then
  # One bulk lsof pass; bucket each held /tmp path by its top-level name.
  # Per-target `lsof +D` is slow on hosts with many mounts (docker
  # overlay2/nsfs adds seconds per call), so calling it 1× per candidate
  # would push cleanup into many minutes. Read from OUTPUT, not exit code:
  # lsof exits non-zero when it can't stat unrelated mounts even with the
  # target held — relying on $? would falsely greenlight rm.
  # BUSY_PATHS keeps the full path too: the top-level bucket is too coarse for
  # anything nested, where one held fd would otherwise shield every sibling.
  while IFS= read -r line; do
    BUSY_PATHS+=("${line#n}")
    name=${line#n/tmp/}
    name=${name%%/*}
    [ -n "$name" ] && BUSY_NAMES["$name"]=1
  done < <(lsof -F n 2>/dev/null | awk '/^n\/tmp\//')
fi

is_busy() {
  [ "$USE_LSOF" -eq 1 ] || return 1
  [ -n "${BUSY_NAMES["${1##*/}"]+x}" ]
}

busy_under() {
  # True if any held fd is $1 itself or below it. Matching $1 exactly matters:
  # lsof reports a process cwd, and a shell sitting in the directory holds it.
  [ "$USE_LSOF" -eq 1 ] || return 1
  [ "${#BUSY_PATHS[@]}" -gt 0 ] || return 1
  local p
  for p in "${BUSY_PATHS[@]}"; do
    case "$p" in "$1" | "$1"/*) return 0 ;; esac
  done
  return 1
}

has_recent_write() {
  # Age of a session tree is the newest mtime anywhere inside, never the
  # directory's own: a live session writing only into tasks/ leaves its own
  # mtime hours stale, and deleting on that would take out a running session.
  # -quit stops at the first hit, so this costs a match, not a full walk.
  local found
  found=$(find "$1" -mmin -"$SESSION_AGE_MIN" -print -quit 2>/dev/null || true)
  [ -n "$found" ]
}

get_size() {
  # Sets size_b (integer bytes) and size_h (human readable) for $1
  # via a single du call rather than separate -sh/-sb passes.
  # Disk usage, not apparent size: sparse test fixtures make -sb report tens of
  # gigabytes for a tree that frees a few, and freed space is the whole point.
  size_b=$(du -s --block-size=1 "$1" 2>/dev/null | awk '{print $1}')
  case "$size_b" in '' | *[!0-9]*) size_b=0 ;; esac
  size_h=$(numfmt --to=iec "$size_b" 2>/dev/null) || size_h="?"
}

emit() {
  # Buffer one report line keyed by size. When /tmp is full the useful question
  # is what is big, so the whole report is sorted by size at the end rather
  # than streamed in filesystem order.
  REPORT+=("$1"$'\t'"$(printf '%-9s%-55s (%s)' "[$2]" "$3" "$4")")
}

prune() {
  # Remove (or, in dry-run, account for) $1. Expects get_size already called.
  if [ "$EXECUTE" -eq 1 ]; then
    if rm -rf -- "$1" 2>/dev/null; then
      emit "$size_b" RM "$1" "$size_h"
      removed=$((removed + 1))
      freed=$((freed + size_b))
    else
      printf '[ERR]    %-55s (rm failed)\n' "$1" >&2
      errors=$((errors + 1))
    fi
  else
    emit "$size_b" DRY "$1" "$size_h"
    removed=$((removed + 1))
    freed=$((freed + size_b))
  fi
}

removed=0
freed=0
busy=0
kept=0
errors=0
REPORT=()

shopt -s nullglob dotglob

for path in /tmp/*; do
  [ -e "$path" ] || continue
  name=${path##*/}

  if match_any "$name" "${SKIP_PATTERNS[@]}"; then
    [ "$VERBOSE" -eq 1 ] && emit 0 KEEP "$path" "skip-list"
    kept=$((kept + 1))
    continue
  fi

  hit=0
  if [ -d "$path" ] && match_any "$name" "${DIR_PATTERNS[@]}"; then hit=1; fi
  if [ -f "$path" ] && match_any "$name" "${FILE_PATTERNS[@]}"; then hit=1; fi

  if [ "$hit" -eq 0 ]; then
    [ "$VERBOSE" -eq 1 ] && emit 0 KEEP "$path" "no pattern"
    kept=$((kept + 1))
    continue
  fi

  if ! is_old "$path"; then
    [ "$VERBOSE" -eq 1 ] && emit 0 KEEP "$path" "younger than ${AGE_MIN}m"
    kept=$((kept + 1))
    continue
  fi

  if is_busy "$path"; then
    get_size "$path"
    emit "$size_b" BUSY "$path" "open fd, $size_h"
    busy=$((busy + 1))
    continue
  fi

  get_size "$path"
  prune "$path"
done

# Claude session scratch: /tmp/claude-<pid>/<project>/<session-uuid>.
#
# The claude-<pid> root stays on the skip list, because a live session needs its
# parent. The session directories under it are ordinary scratch, and are the
# only thing in /tmp that grows without bound, so without this pass a full
# tmpfs has no recovery short of rm -rf by hand.
#
# Age here is a backstop only — a session idle waiting for its user writes
# nothing at all — so lsof is the real guard, and it must match per path: the
# top-level bucket would call the whole tree busy over one sibling's fd. The
# default threshold is eight hours rather than the 20 minutes that suits build
# scratch, because -d answers "this build artefact is finished" and -s answers
# "nobody is using this session".
for sess in /tmp/claude-[0-9]*/*/*; do
  [ -d "$sess" ] || continue

  if busy_under "$sess"; then
    get_size "$sess"
    emit "$size_b" BUSY "$sess" "open fd, $size_h"
    busy=$((busy + 1))
    continue
  fi

  if has_recent_write "$sess"; then
    [ "$VERBOSE" -eq 1 ] && emit 0 KEEP "$sess" "written within ${SESSION_AGE_MIN}m"
    kept=$((kept + 1))
    continue
  fi

  get_size "$sess"
  prune "$sess"
done

[ "${#REPORT[@]}" -gt 0 ] && printf '%s\n' "${REPORT[@]}" | sort -t$'\t' -k1,1rn | cut -f2-

freed_h=$(numfmt --to=iec --suffix=B "$freed" 2>/dev/null || echo "${freed}B")
remaining=$(du -sh /tmp 2>/dev/null | awk '{print $1}')

mode="DRY-RUN"
verb="would remove"
if [ "$EXECUTE" -eq 1 ]; then
  mode="EXECUTED"
  verb="removed"
fi

printf '\n--- %s ---\n' "$mode"
printf '%-13s %d (%s)\n' "$verb:" "$removed" "$freed_h"
printf '%-13s %d\n' "busy:" "$busy"
printf '%-13s %d\n' "kept:" "$kept"
[ "$errors" -gt 0 ] && printf '%-13s %d\n' "errors:" "$errors"
printf '%-13s %s\n' "/tmp size:" "$remaining"

[ "$errors" -gt 0 ] && exit 1
exit 0
