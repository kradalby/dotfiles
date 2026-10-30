#!/usr/bin/env bash
# Free disk before agents hit "no space left on device". Dry-run by default.
# writeShellApplication injects errexit; one failed step must not stop the next.
set +o errexit +o pipefail
set -o nounset

EXECUTE=0
ROOT_PCT=85
TMP_PCT=80
IDLE_DAYS=7

usage() {
  cat <<EOF
disk-cleanup — free /tmp and / when they run low.

USAGE
  disk-cleanup [-y|--execute] [-f PERCENT] [-t PERCENT] [-o DAYS] [-h|--help]

OPTIONS
  -y, --execute    actually delete (default: dry-run)
  -f PERCENT       act on / at or above this (default: $ROOT_PCT; 0 runs every step)
  -t PERCENT       act on /tmp at or above this (default: $TMP_PCT)
  -o DAYS          overflow scratch idle threshold (default: $IDLE_DAYS)
  -h, --help       this help

STEPS
  /tmp is a separate tmpfs, so only tmp-cleanup frees it.
  / runs these in order and stops once it is below -f, cheapest loss first:
    1. tmp-cleanup -o DAYS          overflow scratch nobody uses
    2. trim ~/.cache/go-build       entries unused for two hours
    3. docker system prune -af      images rebuild or pull again
    4. nix-collect-garbage          a build running now can fail

  Never --volumes (volumes can hold the only copy of data) and never -d (it
  deletes rollback generations).

EXIT CODES
  0  / below -f and /tmp below -t
  3  either is still at or above its limit: the rest needs a person
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -y | --execute) EXECUTE=1 ;;
    -f | -t | -o)
      [ $# -gt 1 ] && [[ "$2" != *[!0-9]* && -n "$2" ]] || {
        echo "disk-cleanup: $1 needs a non-negative integer" >&2
        exit 2
      }
      case "$1" in
        -f) ROOT_PCT=$2 ;;
        -t) TMP_PCT=$2 ;;
        -o) IDLE_DAYS=$2 ;;
      esac
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "disk-cleanup: unknown arg: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

used_pct() {
  df --output=pcent "$1" 2>/dev/null | tail -1 | tr -dc '0-9'
}

root_full() {
  [ "$(used_pct /)" -ge "$ROOT_PCT" ]
}

tmp_full() {
  [ "$(used_pct /tmp)" -ge "$TMP_PCT" ]
}

report() {
  printf '/ %s%% (limit %s%%), /tmp %s%% (limit %s%%)\n' \
    "$(used_pct /)" "$ROOT_PCT" "$(used_pct /tmp)" "$TMP_PCT"
}

run() {
  # Dry-run names a destructive step instead of taking it.
  if [ "$EXECUTE" -eq 1 ]; then
    echo "+ $*"
    "$@"
  else
    echo "would run: $*"
  fi
}

report

tmp_args=(-f 101)
[ "$EXECUTE" -eq 1 ] && tmp_args+=(-y)
root_full && tmp_args+=(-o "$IDLE_DAYS")

# tmp-cleanup previews by itself in dry-run, so it never goes through run().
if root_full || tmp_full; then
  echo "+ tmp-cleanup ${tmp_args[*]}"
  tmp-cleanup "${tmp_args[@]}"
fi

if root_full && [ -d "$HOME/.cache/go-build" ]; then
  # Two hours, not less: Go refreshes an entry's mtime at most hourly on use.
  run find "$HOME/.cache/go-build" -type f -mmin +120 -delete
fi
if root_full && command -v docker >/dev/null; then
  run docker system prune -af
fi
if root_full && command -v nix-collect-garbage >/dev/null; then
  run nix-collect-garbage
fi

report

status=0
if root_full; then
  echo 'disk-cleanup: / still full. Next: du -xsh ~/worktrees/*/*' >&2
  status=3
fi
if tmp_full; then
  echo 'disk-cleanup: /tmp still full. Next: tmp-cleanup -v lists what stayed' >&2
  status=3
fi
exit "$status"
