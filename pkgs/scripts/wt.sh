#!/usr/bin/env bash
# wt: git worktree helper. Main repo lives at ~/git/<repo>; worktrees at
# $WT_ROOT/<repo>/<branch>. create/checkout/pr print the worktree path on
# stdout so callers can cd into it (`cd (wt create x)`); every other message
# goes to stderr.

usage() {
  cat <<'EOF'
Usage: wt <command> [args]

Commands:
  create <branch> [base]   Create branch in a new worktree (default base: origin's default branch)
  checkout, co <branch>    Check out an existing branch in a new worktree
  pr <number|url>          Check out a GitHub PR in a new worktree (uses gh)
  list, ls                 List worktrees
  remove, rm <branch>      Remove a worktree
  prune                    Prune stale worktree metadata

create, checkout and pr print the worktree path on stdout and allow its direnv.
Worktrees live at $WT_ROOT/<repo>/<branch> (default WT_ROOT: ~/worktrees);
slashes in branch names become nested dirs.
EOF
}

die() {
  echo "wt: $*" >&2
  exit 1
}

# existing prints the worktree holding branch, if any.
existing() {
  local found
  found=$(git worktree list --porcelain |
    awk -v b="refs/heads/$1" '/^worktree /{p=substr($0,10)} /^branch /&&$2==b&&f==""{f=p} END{print f}')
  # A branch mid-rebase lists as detached HEAD; fall back to its canonical path.
  if [[ -z "$found" && -e "$root/$1/.git" ]]; then
    found="$root/$1"
  fi
  printf '%s' "$found"
}

# land allows direnv so the caller arrives ready to work, then prints the path.
land() {
  if [[ -f "$1/.envrc" ]]; then
    direnv allow "$1"
  fi
  printf '%s\n' "$1"
}

# add creates $root/<branch> unless branch already has a worktree. Remaining
# args follow the path in `git worktree add`.
add() {
  local branch="$1" found dir
  shift
  found=$(existing "$branch")
  if [[ -n "$found" ]]; then
    echo "Worktree already exists: $found" >&2
    land "$found"
    return
  fi
  dir="$root/$branch"
  mkdir -p "$(dirname "$dir")"
  git worktree add "$dir" "$@" >&2
  echo "Worktree created at: $dir" >&2
  land "$dir"
}

default_base() {
  local ref
  ref=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null) || ref=main
  printf '%s\n' "${ref#refs/remotes/origin/}"
}

cmd="${1:-help}"
shift $(($# > 0))

case "$cmd" in
  help | --help | -h)
    usage
    exit 0
    ;;
esac

# First entry is the main worktree; its basename is the repo name regardless
# of bare/shared-gitdir layout.
main_wt=$(git worktree list --porcelain 2>/dev/null |
  awk '/^worktree /&&p==""{p=substr($0,10)} END{print p}') || true
[[ -n "$main_wt" ]] || die "not in a git repository"
repo=$(basename "$main_wt")
root="${WT_ROOT:-$HOME/worktrees}/${repo%.git}"

case "$cmd" in
  create)
    [[ $# -ge 1 ]] || die "usage: wt create <branch> [base]"
    add "$1" -b "$1" "${2:-$(default_base)}"
    ;;
  checkout | co)
    [[ $# -ge 1 ]] || die "usage: wt checkout <branch>"
    if [[ -z "$(existing "$1")" ]] &&
      ! git show-ref --verify --quiet "refs/heads/$1" &&
      ! git show-ref --verify --quiet "refs/remotes/origin/$1"; then
      die "branch '$1' does not exist; use 'wt create $1'"
    fi
    add "$1" "$1"
    ;;
  pr)
    [[ $# -ge 1 ]] || die "usage: wt pr <number|url>"
    [[ "$1" =~ ^(https://github\.com/.*/pull/)?([0-9]+)$ ]] || die "invalid PR number or URL: $1"
    pr="${BASH_REMATCH[2]}"
    head=$(gh pr view "$pr" --json headRefOid --jq .headRefOid) || die "failed to get PR #$pr"
    git fetch origin "$head" >&2
    add "pr-$pr" -b "pr-$pr" "$head"
    ;;
  list | ls)
    git worktree list
    ;;
  remove | rm)
    [[ $# -ge 1 ]] || die "usage: wt remove <branch>"
    found=$(existing "$1")
    [[ -n "$found" ]] || die "no worktree for branch: $1"
    git worktree remove "$found"
    echo "Removed worktree: $found" >&2
    ;;
  prune)
    git worktree prune
    echo "Pruned stale worktree administrative files" >&2
    ;;
  *)
    die "unknown command '$cmd'; run 'wt help'"
    ;;
esac
