#!/usr/bin/env bash
# Exercises wt against a throwaway repo.
set -euo pipefail

HOME=$(mktemp -d)
export HOME WT_ROOT="$HOME/wt"
git config --global user.email t@t
git config --global user.name t
git config --global init.defaultBranch main
git init -q "$HOME/repo"
cd "$HOME/repo"
git commit -q --allow-empty -m init

dir=$(wt create kra/feat)
[[ "$dir" == "$WT_ROOT/repo/kra/feat" ]] || {
  echo "create printed '$dir'"
  exit 1
}
[[ "$(git -C "$dir" branch --show-current)" == kra/feat ]]
[[ "$(wt create kra/feat)" == "$dir" ]] || {
  echo "second create did not reuse the worktree"
  exit 1
}
[[ "$(cd "$dir" && wt checkout kra/feat)" == "$dir" ]] || {
  echo "checkout from inside a worktree missed it"
  exit 1
}
WT_CD_FILE="$HOME/cd" wt checkout kra/feat >/dev/null 2>&1
[[ "$(<"$HOME/cd")" == "$dir" ]] || {
  echo "checkout did not hand '$dir' to WT_CD_FILE"
  exit 1
}
if wt checkout missing 2>/dev/null; then
  echo "checkout of a missing branch succeeded"
  exit 1
fi
wt rm kra/feat 2>/dev/null
[[ ! -e "$dir" ]] || {
  echo "rm left $dir"
  exit 1
}
echo ok
