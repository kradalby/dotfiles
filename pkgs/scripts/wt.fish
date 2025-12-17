# Minimal git worktree helper for fish
# Usage: wt <command> [options]

function wt --description "Git worktree helper with organized directory structure"
    # Worktrees are created as siblings of the main repo directory
    # e.g., ~/git/headscale/main -> ~/git/headscale/<branch>
    set -l WORKTREE_ROOT (dirname (git rev-parse --show-toplevel 2>/dev/null))
    if test -z "$WORKTREE_ROOT" -o "$WORKTREE_ROOT" = "."
        echo "Error: Not in a git repository" >&2
        return 1
    end

    if test (count $argv) -eq 0
        __tree_me_help
        return 0
    end

    set -l command $argv[1]
    set -l args $argv[2..-1]

    switch $command
        case help --help -h
            __tree_me_help

        case checkout co
            if test (count $args) -lt 1
                echo "Error: Branch name required. Usage: tree-me checkout <branch>" >&2
                return 1
            end
            __tree_me_checkout $WORKTREE_ROOT $args[1]

        case create
            if test (count $args) -lt 1
                echo "Error: Branch name required. Usage: tree-me create <branch> [base-branch]" >&2
                return 1
            end
            __tree_me_create $WORKTREE_ROOT $args

        case pr
            if test (count $args) -lt 1
                echo "Error: PR number or URL required. Usage: tree-me pr <number|url>" >&2
                return 1
            end
            __tree_me_pr $WORKTREE_ROOT $args[1]

        case list ls
            git worktree list

        case remove rm
            if test (count $args) -lt 1
                echo "Error: Branch name required. Usage: tree-me remove <branch>" >&2
                return 1
            end
            __tree_me_remove $args[1]

        case prune
            git worktree prune
            echo "Pruned stale worktree administrative files"

        case '*'
            echo "Error: Unknown command '$command'" >&2
            echo "Run 'tree-me help' for usage information" >&2
            return 1
    end
end

function __tree_me_help
    echo "Usage: wt <command> [options]

Git-like worktree management with organized directory structure.

Commands:
  checkout, co <branch>         Checkout existing branch in new worktree
  create <branch> [base]        Create new branch in worktree (default: main/master)
  pr <number|url>               Checkout GitHub PR in worktree (uses gh)
  list, ls                      List all worktrees
  remove, rm <branch>           Remove a worktree
  prune                         Remove worktree administrative files

Examples:
  wt checkout feature-branch
  wt create my-feature
  wt create my-feature develop
  wt pr 123
  wt pr https://github.com/org/repo/pull/123
  wt list
  wt remove old-branch

Worktrees are created as siblings of your main repo directory.
e.g., ~/git/repo/main -> ~/git/repo/<branch>"
end

function __tree_me_get_default_base
    set -l base (git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    test -n "$base" && echo $base || echo main
end

function __tree_me_checkout
    set -l worktree_root $argv[1]
    set -l branch $argv[2]
    set -l path "$worktree_root/$branch"

    # Check if worktree already exists
    set -l existing (git worktree list | grep "\[$branch\]" | awk '{print $1}')
    if test -n "$existing"
        echo "Worktree already exists: $existing"
        cd "$existing"
        return 0
    end

    # Check if branch exists
    if git show-ref --verify --quiet "refs/heads/$branch"; or git show-ref --verify --quiet "refs/remotes/origin/$branch"
        git worktree add "$path" "$branch"
        echo "Worktree created at: $path"
        cd "$path"
    else
        echo "Error: Branch '$branch' does not exist" >&2
        echo "Use 'tree-me create $branch' to create a new branch" >&2
        return 1
    end
end

function __tree_me_create
    set -l worktree_root $argv[1]
    set -l branch $argv[2]
    set -l base (test (count $argv) -ge 3 && echo $argv[3] || __tree_me_get_default_base)
    set -l path "$worktree_root/$branch"

    # Check if worktree already exists
    set -l existing (git worktree list | grep "\[$branch\]" | awk '{print $1}')
    if test -n "$existing"
        echo "Worktree already exists: $existing"
        cd "$existing"
        return 0
    end

    git worktree add "$path" -b "$branch" "$base"
    echo "Worktree created at: $path"
    cd "$path"
end

function __tree_me_pr
    set -l worktree_root $argv[1]
    set -l input $argv[2]

    # Check if gh is installed
    if not command -v gh >/dev/null 2>&1
        echo "Error: 'gh' CLI not found. Install it from https://cli.github.com" >&2
        return 1
    end

    # Extract PR number from URL or use directly
    set -l pr_number
    if string match -qr '^https://github.com/.*/pull/([0-9]+)' -- $input
        set pr_number (string match -r '^https://github.com/.*/pull/([0-9]+)' -- $input)[2]
    else if string match -qr '^[0-9]+$' -- $input
        set pr_number $input
    else
        echo "Error: Invalid PR number or URL: $input" >&2
        return 1
    end

    set -l branch "pr-$pr_number"
    set -l path "$worktree_root/$branch"

    # Check if worktree already exists
    set -l existing (git worktree list | grep "\[$branch\]" | awk '{print $1}')
    if test -n "$existing"
        echo "Worktree already exists: $existing"
        cd "$existing"
        return 0
    end

    # Use gh to get PR info and fetch the head ref
    set -l pr_head (gh pr view $pr_number --json headRefName,headRefOid --jq '.headRefOid')
    if test -z "$pr_head"
        echo "Error: Failed to get PR #$pr_number info" >&2
        return 1
    end

    # Fetch the PR head commit and create a local branch
    git fetch origin $pr_head
    git worktree add "$path" -b "$branch" $pr_head
    echo "PR #$pr_number checked out at: $path"
    cd "$path"
end

function __tree_me_remove
    set -l branch $argv[1]
    set -l existing (git worktree list | grep "\[$branch\]" | awk '{print $1}')
    if test -z "$existing"
        echo "Error: No worktree found for branch: $branch" >&2
        return 1
    end
    git worktree remove "$existing"
    echo "Removed worktree: $existing"
end
