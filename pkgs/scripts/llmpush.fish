# Relay a branch from the llm box (no GitHub push access) to origin.

function llmpush --description "Pull a branch from the llm box and push it to origin"
    argparse f/force -- $argv; or return 1

    set -l usage "Usage: llmpush [-f] <repo> <branch>  |  llmpush [-f] [branch] (inside a repo)" \
        "  -f  abort an in-progress rebase/merge first"
    set -l dir
    set -l branch
    switch (count $argv)
        case 2
            set dir "$HOME/git/$argv[1]"
            set branch $argv[2]
            if not git -C "$dir" rev-parse --git-dir >/dev/null 2>&1
                echo "Error: $dir is not a git repository" >&2
                return 1
            end
        case 0 1
            # Main worktree: its basename is the repo name on llm; a linked
            # worktree's basename is a branch leaf.
            set dir (git worktree list --porcelain 2>/dev/null | awk '/^worktree / {print substr($0, 10); exit}')
            if test -z "$dir"
                echo "Error: not in a git repository" >&2
                printf '%s\n' $usage >&2
                return 1
            end
            if test (count $argv) -eq 1
                set branch $argv[1]
            else
                set branch (__llmpush_current_branch)
                or begin
                    echo "Error: detached HEAD; name a branch" >&2
                    return 1
                end
            end
        case '*'
            printf '%s\n' $usage >&2
            return 1
    end

    # wt cd's into the worktree; fish has no subshell, so restore by hand.
    set -l start $PWD
    cd "$dir"
    __llmpush_run (basename "$dir") $branch $_flag_force
    set -l rc $status
    cd "$start"
    return $rc
end

function __llmpush_run --argument-names repo branch force
    if not git remote get-url llm >/dev/null 2>&1
        git remote add llm "ubuntu@kradalby-llm:/home/ubuntu/git/$repo"; or return 1
        echo "Added remote llm -> "(git remote get-url llm)
    end

    # Full refname: a bare name would also match refs/heads/*/<branch>.
    git ls-remote --exit-code llm "refs/heads/$branch" >/dev/null
    switch $status
        case 0
        case 2
            echo "Error: branch '$branch' not found on llm" >&2
            return 1
        case '*'
            echo "Error: cannot reach llm remote "(git remote get-url llm) >&2
            return 1
    end
    git fetch llm $branch; or return 1

    if git show-ref --verify --quiet "refs/heads/$branch"
        wt checkout $branch
    else
        wt create $branch llm/$branch
    end
    or return 1

    set -l pending
    if test -d (git rev-parse --git-path rebase-merge); or test -d (git rev-parse --git-path rebase-apply)
        set pending rebase
    else if git rev-parse --quiet --verify MERGE_HEAD >/dev/null
        set pending merge
    end
    if test -n "$pending"
        if test -z "$force"
            echo "Error: $pending in progress in $PWD; finish it or rerun with -f" >&2
            return 1
        end
        git $pending --abort; or return 1
    end

    # After the abort: mid-rebase HEAD is detached, so check only now.
    set -l head (git symbolic-ref --quiet --short HEAD)
    if test "$head" != "$branch"
        echo "Error: worktree $PWD is on '$head', expected '$branch'" >&2
        return 1
    end

    # Untracked files survive the reset; only tracked edits are at risk.
    set -l dirty (git status --porcelain --untracked-files=no)
    if test -n "$dirty"
        echo "Error: uncommitted changes in $PWD:" >&2
        printf '%s\n' $dirty >&2
        return 1
    end

    # llm owns the branch and rewrites it freely, so mirror rather than pull.
    # The lease still refuses when origin has commits this clone never fetched.
    git reset --hard llm/$branch; and git push --force-with-lease -u origin $branch
end

# Mid-rebase HEAD is detached; the branch name lives in the rebase state.
function __llmpush_current_branch
    git symbolic-ref --quiet --short HEAD 2>/dev/null; and return
    for state in rebase-merge rebase-apply
        set -l head_name (git rev-parse --git-path $state/head-name)
        if test -f "$head_name"
            string replace -r '^refs/heads/' '' <$head_name
            return
        end
    end
    return 1
end
