#!/usr/bin/env fish
# Regression check for llmpush against local fixtures: origin (bare), llm (the
# box's clone) and a laptop clone at ~/git/repo. HOME, git config and ssh are
# sandboxed; nothing outside the temp dir is touched.

set -l here (realpath (status dirname))
source $here/wt.fish; or exit 1
source $here/llmpush.fish; or exit 1

set -g tmp (mktemp -d)
function __cleanup --on-event fish_exit
    rm -rf -- $tmp
end

set -gx HOME $tmp/home
set -gx WT_ROOT $tmp/worktrees
set -gx GIT_CONFIG_NOSYSTEM 1
set -gx GIT_CONFIG_GLOBAL $tmp/gitconfig
set -gx GIT_SSH_COMMAND false
printf '[user]\n\tname = t\n\temail = t@t\n[init]\n\tdefaultBranch = main\n' >$GIT_CONFIG_GLOBAL

set -g fail 0
set -g log $tmp/log
function ok
    echo "ok   $argv"
end
function bad
    echo "FAIL $argv"
    sed 's/^/     | /' $log
    set -g fail 1
end
function sha --argument-names repo ref
    git -C $repo rev-parse --verify --quiet $ref
end

set -l laptop $HOME/git/repo
set -l wtdir $WT_ROOT/repo/kradalby/feat

git init -q --bare $tmp/origin.git
git clone -q $tmp/origin.git $tmp/seed 2>/dev/null
echo base >$tmp/seed/f
git -C $tmp/seed add f
git -C $tmp/seed commit -qm base
git -C $tmp/seed push -q origin main
git clone -q $tmp/origin.git $tmp/llm
git clone -q $tmp/origin.git $laptop
git -C $laptop remote add llm $tmp/llm

git -C $tmp/llm checkout -qb kradalby/feat
echo one >$tmp/llm/g
git -C $tmp/llm add g
git -C $tmp/llm commit -qm one

# main moves on after llm branched; a main-based branch would carry this along
echo main2 >$laptop/f
git -C $laptop commit -qam main2
git -C $laptop push -q origin main

cd $tmp
llmpush repo kradalby/feat >$log 2>&1
set -l rc $status
test $rc -eq 0 -a "$(sha $tmp/origin.git kradalby/feat)" = "$(sha $tmp/llm HEAD)"
and ok "new branch pushed at llm's commit, main not dragged in"
or bad "new branch push (rc=$rc)"
test "$PWD" = $tmp; and ok "cwd restored"; or bad "cwd is $PWD"

echo two >$tmp/llm/g
git -C $tmp/llm commit -qam two
cd $laptop
llmpush kradalby/feat >$log 2>&1
set rc $status
test $rc -eq 0 -a "$(sha $tmp/origin.git kradalby/feat)" = "$(sha $tmp/llm HEAD)"
and ok "branch arg inside repo fast-forwards origin"
or bad "update push (rc=$rc)"
test "$PWD" = $laptop; and ok "cwd restored"; or bad "cwd is $PWD"

echo TWO >$tmp/llm/g
git -C $tmp/llm commit -q --amend -am two-rewritten
llmpush repo kradalby/feat >$log 2>&1
set rc $status
test $rc -eq 0 -a "$(sha $tmp/origin.git kradalby/feat)" = "$(sha $tmp/llm HEAD)"
and ok "llm rewrite mirrored without -f"
or bad "llm rewrite (rc=$rc)"

# someone else pushes to origin; this clone never fetched it
git -C $tmp/seed fetch -q origin
git -C $tmp/seed checkout -q kradalby/feat
echo other >$tmp/seed/h
git -C $tmp/seed add h
git -C $tmp/seed commit -qm other
git -C $tmp/seed push -q origin kradalby/feat
set -l before (sha $tmp/origin.git kradalby/feat)
llmpush repo kradalby/feat >$log 2>&1
set rc $status
test $rc -ne 0 -a "$(sha $tmp/origin.git kradalby/feat)" = "$before"
and ok "lease refuses to drop unseen origin commits"
or bad "lease (rc=$rc)"
git -C $laptop fetch -q origin

# stuck rebase in the worktree, as left by a conflicting pull
echo three >$tmp/llm/g
git -C $tmp/llm commit -qam three
git -C $laptop fetch -q llm
echo laptop >$wtdir/g
git -C $wtdir commit -qam laptop
git -C $wtdir rebase -q llm/kradalby/feat >/dev/null 2>&1
cd $wtdir
llmpush >$log 2>&1
set rc $status
test $rc -ne 0 -a "$(sha $tmp/origin.git kradalby/feat)" = "$before"
and grep -q "rebase in progress" $log
and ok "no args mid-rebase finds branch, refuses without -f"
or bad "mid-rebase without -f (rc=$rc)"

llmpush -f >$log 2>&1
set rc $status
test $rc -eq 0 -a "$(sha $tmp/origin.git kradalby/feat)" = "$(sha $tmp/llm HEAD)"
and ok "-f aborts rebase and mirrors"
or bad "-f (rc=$rc)"
test "$PWD" = $wtdir; and ok "cwd restored"; or bad "cwd is $PWD"

set before (sha $tmp/origin.git kradalby/feat)
echo dirty >$wtdir/g
llmpush -f repo kradalby/feat >$log 2>&1
set rc $status
test $rc -ne 0 -a "$(sha $tmp/origin.git kradalby/feat)" = "$before" -a "$(cat $wtdir/g)" = dirty
and ok "dirty worktree refused, edit kept"
or bad "dirty worktree (rc=$rc)"
git -C $wtdir checkout -q -- g

llmpush repo nope >$log 2>&1
set rc $status
test $rc -ne 0; and grep -q "not found on llm" $log
and ok "missing branch reported"
or bad "missing branch (rc=$rc)"

git clone -q $tmp/origin.git $HOME/git/other
llmpush other kradalby/feat >$log 2>&1
set rc $status
test $rc -ne 0 -a "$(git -C $HOME/git/other remote get-url llm)" = "ubuntu@kradalby-llm:/home/ubuntu/git/other"
and grep -q "cannot reach llm" $log
and ok "missing llm remote added"
or bad "llm remote add (rc=$rc)"

cd $tmp
llmpush >$log 2>&1
set rc $status
test $rc -ne 0; and ok "no args outside repo refused"; or bad "no args outside repo (rc=$rc)"

exit $fail
