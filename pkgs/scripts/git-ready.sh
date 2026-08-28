#!/usr/bin/env bash
# git-ready — assert a repo is safe to deploy from: on its default branch,
# clean, in sync with origin, nothing unpushed. One line of output either way.
#
# Exit 0  every check passed
# Exit 1  a check failed, or the repo could not be evaluated
#
# Usage: git-ready [--no-fetch] [dir]
#        git-ready --selftest

set -euo pipefail

dir="."
fetch=1

fail() {
  echo "git-ready: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
git-ready — assert a repo is safe to deploy from.

Checks the repo is on its default branch, has a clean tree, is in sync with
origin, and has nothing unpushed (commits or tags).

Usage: git-ready [--no-fetch] [dir]
       git-ready --selftest

Exit 0 = every check passed. Exit 1 = a check failed, or the repo could not be
evaluated. Never mutates the repo and never pushes.
USAGE
}

# g: git in the target repo. Named g, not git, so the calls read as deliberate
# and shellcheck does not have to reason about a shadowed builtin name.
g() { command git -C "$dir" "$@"; }

ready() {
  g rev-parse --git-dir >/dev/null 2>&1 || fail "not a git repository: $dir"

  # symbolic-ref exits non-zero on a detached HEAD. `branch --show-current`
  # would print nothing and exit 0, reporting a blank branch name instead.
  local branch
  branch=$(g symbolic-ref --quiet --short HEAD) || fail "detached HEAD"

  # The local symref is authoritative; ls-remote covers a clone that never ran
  # `git remote set-head`.
  local default
  default=$(g symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  default="${default#origin/}"
  if [[ -z "$default" ]]; then
    default=$(g ls-remote --symref origin HEAD 2>/dev/null |
      awk '$1 == "ref:" { sub("refs/heads/", "", $2); print $2; exit }' || true)
  fi
  [[ -n "$default" ]] ||
    fail "cannot determine origin's default branch (try: git remote set-head origin --auto)"

  # Compare branch NAMES. @{u} is not the test: a worktree can track
  # origin/<default> while sitting on a feature branch.
  [[ "$branch" == "$default" ]] || fail "on '$branch', not '$default'"

  # -unormal defeats status.showUntrackedFiles=no and --ignore-submodules=none
  # defeats diff.ignoreSubmodules; either setting otherwise reads dirty as clean.
  local dirty
  dirty=$(g status --porcelain -unormal --ignore-submodules=none)
  if [[ -n "$dirty" ]]; then
    echo "$dirty" >&2
    fail "working tree not clean"
  fi

  # --prune only. --prune-tags deletes local-only tags, which a check must not do.
  if [[ "$fetch" == 1 ]]; then
    g fetch --quiet --prune origin || fail "git fetch failed"
  fi

  g rev-parse --verify --quiet "refs/remotes/origin/$default" >/dev/null ||
    fail "no refs/remotes/origin/$default — fetch first"

  local behind ahead
  read -r behind ahead < <(g rev-list --left-right --count "refs/remotes/origin/$default...HEAD")
  [[ "$ahead" == 0 ]] || fail "$ahead unpushed commit(s) on $branch"
  [[ "$behind" == 0 ]] || fail "$behind commit(s) behind origin/$default"

  # Tags travel separately from commits, so "everything pushed" has to check
  # them too. --refs drops the peeled ^{} rows so the object names compare.
  local local_tags remote_tags unpushed
  local_tags=$(g for-each-ref --format='%(refname:short) %(objectname)' refs/tags | sort)
  if [[ -n "$local_tags" ]]; then
    remote_tags=$(g ls-remote --tags --refs origin 2>/dev/null |
      awk '{ sub("refs/tags/", "", $2); print $2, $1 }' | sort || true)
    unpushed=$(comm -23 <(echo "$local_tags") <(echo "$remote_tags") || true)
    if [[ -n "$unpushed" ]]; then
      fail "unpushed or moved tag(s): $(awk '{ print $1 }' <<<"$unpushed" | tr '\n' ' ')"
    fi
  fi

  echo "git-ready: ok $branch $(g rev-parse --short HEAD)"
}

# selftest builds throwaway repos and asserts each verdict. This script is a
# deploy gate, so a silent regression here is a silent loss of the gate.
selftest() {
  local root fails=0
  root=$(mktemp -d)
  # shellcheck disable=SC2064 # expand root now; the trap outlives the local
  trap "rm -rf '$root'" EXIT

  local remote="$root/remote.git" work="$root/work" other="$root/other"
  command git init --quiet --bare "$remote"
  command git -C "$remote" symbolic-ref HEAD refs/heads/main
  command git clone --quiet "$remote" "$work" 2>/dev/null
  command git -C "$work" config user.email t@example.invalid
  command git -C "$work" config user.name test
  echo a >"$work/a"
  command git -C "$work" add a
  command git -C "$work" commit --quiet -m init
  command git -C "$work" push --quiet -u origin main
  command git -C "$work" remote set-head origin --auto >/dev/null

  # check <wanted exit> <label>. Runs ready() in a subshell rather than
  # re-execing $0, so the test does not depend on the file being executable.
  check() {
    local want="$1" label="$2" rc=0
    (
      dir="$work"
      fetch=0
      ready
    ) >/dev/null 2>&1 || rc=$?
    if [[ "$rc" == "$want" ]]; then
      echo "ok   $label"
    else
      echo "FAIL $label (exit $rc, wanted $want)" >&2
      fails=$((fails + 1))
    fi
  }

  check 0 "clean, on default branch, in sync"

  echo dirt >"$work/untracked"
  check 1 "untracked file counts as dirty"
  rm "$work/untracked"

  command git -C "$work" checkout --quiet -b feature
  check 1 "not on the default branch"
  command git -C "$work" checkout --quiet main

  echo b >"$work/b"
  command git -C "$work" add b
  command git -C "$work" commit --quiet -m ahead
  check 1 "unpushed commit"
  command git -C "$work" reset --quiet --hard HEAD~1

  command git -C "$work" tag v1
  check 1 "unpushed tag"
  command git -C "$work" tag -d v1 >/dev/null

  check 0 "back to clean"

  # Behind, from a second clone. Last: it leaves $work behind origin.
  command git clone --quiet "$remote" "$other" 2>/dev/null
  command git -C "$other" config user.email t@example.invalid
  command git -C "$other" config user.name test
  echo c >"$other/c"
  command git -C "$other" add c
  command git -C "$other" commit --quiet -m remote-ahead
  command git -C "$other" push --quiet origin main
  command git -C "$work" fetch --quiet origin
  check 1 "behind origin"

  [[ "$fails" == 0 ]] || fail "$fails selftest case(s) failed"
  echo "selftest passed"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-fetch)
      fetch=0
      shift
      ;;
    --selftest)
      selftest
      exit 0
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*) fail "unknown flag: $1" ;;
    *)
      dir="$1"
      shift
      ;;
  esac
done

ready
