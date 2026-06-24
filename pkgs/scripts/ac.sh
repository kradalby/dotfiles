#!/usr/bin/env bash
set -euo pipefail

# Main repos live at $GIT_ROOT/<repo>; worktrees at $WT_ROOT/<repo>/<branch>.
# Mirrors the layout used by wt.fish (default WT_ROOT: ~/worktrees).
GIT_ROOT="$HOME/git"
WT_ROOT="${WT_ROOT:-$HOME/worktrees}"
DEFAULT_AGENT="claude"
SESSION_PREFIX="ac"

# boo (the multiplexer) keeps its own daemon + sockets, so there is no socket
# bookkeeping here. boo's `ls --json` carries no working directory, so the
# repo/branch/agent metadata for `ac ls` is stashed in small state files.
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ac"

# --- helpers ---

die() {
	echo "error: $*" >&2
	exit 1
}

sanitize() {
	# boo session names allow letters, digits, '.', '_', '-'. Fold anything
	# else (notably the '/' in branch names) to '-'.
	echo "$1" | tr -c 'A-Za-z0-9._-' '-' | sed 's/-*$//'
}

session_name() {
	local repo="$1" branch="$2"
	if [[ -n "$branch" ]]; then
		echo "${SESSION_PREFIX}-${repo}-$(sanitize "$branch")"
	else
		echo "${SESSION_PREFIX}-${repo}"
	fi
}

meta_file() {
	echo "$STATE_DIR/$1.meta"
}

agent_label() {
	case "$1" in
	opencode) echo "oc" ;;
	claude) echo "cl" ;;
	*) echo "$1" ;;
	esac
}

resolve_path() {
	local repo="$1" branch="${2:-}"

	# A branch maps to a worktree under $WT_ROOT/<repo>/<branch>.
	if [[ -n "$branch" ]]; then
		local path="$WT_ROOT/$repo/$branch"
		if [[ -d "$path" ]]; then
			echo "$path"
			return 0
		fi
		die "worktree not found: $path"
	fi

	# No branch: the main repo itself at $GIT_ROOT/<repo>.
	local repo_path="$GIT_ROOT/$repo"
	if [[ -e "$repo_path/.git" ]]; then
		echo "$repo_path"
		return 0
	fi

	die "cannot resolve repo '$repo': $repo_path is not a git repo"
}

resolve_branch() {
	# Given repo and optional branch, return the effective branch name
	local repo="$1" branch="${2:-}"

	if [[ -n "$branch" ]]; then
		echo "$branch"
		return 0
	fi

	# No branch given: the main repo has no branch component.
	echo ""
}

find_main_worktree() {
	# Locate the main worktree for a repo (needed to run git commands from)
	local repo="$1"
	local repo_path="$GIT_ROOT/$repo"

	if [[ -e "$repo_path/.git" ]]; then
		echo "$repo_path"
		return 0
	fi

	die "cannot find main worktree for '$repo': $repo_path"
}

create_branch_worktree() {
	# Add a worktree for $branch. The branch may already exist (created in the
	# main repo, or pushed to a remote) or be brand new:
	#   - Existing local branch: check it out into the worktree as-is.
	#   - Existing remote branch: create a local tracking branch from it.
	#   - New branch: base off the appropriate remote. Repos with an 'upstream'
	#     remote (e.g. headscale forks) base off upstream/main; all others base
	#     off origin's default branch.
	# `git worktree add -b` refuses a name that already exists, so we must not
	# pass -b for an existing branch.
	local main_wt="$1" target_path="$2" branch="$3"

	# Ensure the parent dir exists for nested branch names (e.g. feature/foo).
	mkdir -p "$(dirname "$target_path")"

	local has_upstream=""
	git -C "$main_wt" remote | grep -q '^upstream$' && has_upstream=1

	# Fetch first so existing-remote detection and new-branch bases are current.
	if [[ -n "$has_upstream" ]]; then
		echo "Fetching upstream..."
		git -C "$main_wt" fetch upstream
	else
		echo "Fetching origin..."
		git -C "$main_wt" fetch origin
	fi

	if git -C "$main_wt" show-ref --verify --quiet "refs/heads/$branch"; then
		echo "Creating worktree at $target_path for existing branch $branch..."
		git -C "$main_wt" worktree add "$target_path" "$branch"
	elif [[ -n "$has_upstream" ]] && git -C "$main_wt" show-ref --verify --quiet "refs/remotes/upstream/$branch"; then
		echo "Creating worktree at $target_path tracking upstream/$branch..."
		git -C "$main_wt" worktree add "$target_path" --track -b "$branch" "upstream/$branch"
	elif git -C "$main_wt" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
		echo "Creating worktree at $target_path tracking origin/$branch..."
		git -C "$main_wt" worktree add "$target_path" --track -b "$branch" "origin/$branch"
	elif [[ -n "$has_upstream" ]]; then
		echo "Creating worktree at $target_path from upstream/main..."
		git -C "$main_wt" worktree add "$target_path" -b "$branch" upstream/main
	else
		# Determine origin's default branch
		local base
		base=$(git -C "$main_wt" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null |
			sed 's@^refs/remotes/@@' || echo "origin/main")
		echo "Creating worktree at $target_path from $base..."
		git -C "$main_wt" worktree add "$target_path" -b "$branch" "$base"
	fi

	# Allow direnv if the new worktree has an .envrc
	if [[ -f "$target_path/.envrc" ]]; then
		echo "Allowing direnv in $target_path..."
		direnv allow "$target_path"
	fi
}

# All live boo sessions as JSON (empty array if the daemon is not running).
boo_ls_json() {
	boo ls --json 2>/dev/null || echo '[]'
}

session_alive() {
	local name="$1"
	boo_ls_json | jq -e --arg n "$name" 'any(.[]; .name == $n)' >/dev/null
}

# Names of live ac- sessions, sorted (the order `ac ls` indexes against).
ac_session_names() {
	boo_ls_json |
		jq -r --arg p "${SESSION_PREFIX}-" '.[] | select(.name | startswith($p)) | .name' |
		sort
}

# --- commands ---

create_session() {
	local name="$1" dir="$2" agent="$3" repo="$4" branch="$5"

	# Stash metadata so `ac ls` can show repo/branch/agent (boo ls carries none).
	mkdir -p "$STATE_DIR"
	{
		echo "repo=$repo"
		echo "branch=$branch"
		echo "agent=$agent"
		echo "dir=$dir"
	} >"$(meta_file "$name")"

	# Start a detached login shell in the worktree (boo inherits the cwd), then
	# type the agent into it. Launching via the shell means the shell survives
	# if the agent exits, mirroring the old tmux send-keys behaviour.
	(cd "$dir" && boo new "$name" -d) >/dev/null

	# Let the shell prompt settle before typing, instead of racing it.
	boo wait "$name" --idle --timeout 5s >/dev/null 2>&1 || true
	boo send "$name" --text "$agent" --enter
}

attach_session() {
	local name="$1"
	# boo "steals politely": attaching detaches other clients, which is the
	# phone-takes-over-from-laptop behaviour the old `tmux attach -d` gave.
	boo attach "$name"
}

cmd_create_or_attach() {
	local repo="$1" branch="${2:-}" agent="${3:-$DEFAULT_AGENT}"

	# If a branch is specified and the worktree doesn't exist, offer to create it
	if [[ -n "$branch" ]]; then
		local target_path="$WT_ROOT/$repo/$branch"
		if [[ ! -d "$target_path" ]]; then
			local main_wt
			main_wt=$(find_main_worktree "$repo")

			local answer
			read -rp "No worktree for '$branch' in $repo. Create one? [y/N] " answer
			if [[ "$answer" =~ ^[Yy]$ ]]; then
				create_branch_worktree "$main_wt" "$target_path" "$branch"
			else
				return 1
			fi
		fi
	fi

	local dir effective_branch name
	dir=$(resolve_path "$repo" "$branch")
	effective_branch=$(resolve_branch "$repo" "$branch")
	name=$(session_name "$repo" "$effective_branch")

	if session_alive "$name"; then
		attach_session "$name"
	else
		create_session "$name" "$dir" "$agent" "$repo" "$effective_branch"
		attach_session "$name"
	fi
}

cmd_list() {
	local json
	json=$(boo_ls_json)

	local names=()
	while IFS= read -r name; do
		[[ -n "$name" ]] && names+=("$name")
	done < <(ac_session_names)

	# Prune metadata for sessions that are no longer alive.
	if [[ -d "$STATE_DIR" ]]; then
		local meta repo_name
		for meta in "$STATE_DIR"/*.meta; do
			[[ -e "$meta" ]] || continue
			repo_name=$(basename "$meta" .meta)
			session_alive "$repo_name" || rm -f "$meta"
		done
	fi

	if [[ ${#names[@]} -eq 0 ]]; then
		echo "no agent sessions"
		return 0
	fi

	local idx=0 name
	for name in "${names[@]}"; do
		idx=$((idx + 1))

		# Read metadata; fall back to the session name if it is missing.
		local ac_repo="" ac_branch="" ac_agent=""
		local meta
		meta=$(meta_file "$name")
		if [[ -f "$meta" ]]; then
			# shellcheck disable=SC1090
			ac_repo=$(sed -n 's/^repo=//p' "$meta")
			ac_branch=$(sed -n 's/^branch=//p' "$meta")
			ac_agent=$(sed -n 's/^agent=//p' "$meta")
		fi

		local display
		if [[ -n "$ac_repo" && -n "$ac_branch" ]]; then
			display="$ac_repo/$ac_branch"
		elif [[ -n "$ac_repo" ]]; then
			display="$ac_repo"
		else
			display="${name#"${SESSION_PREFIX}"-}"
		fi

		local label
		label=$(agent_label "${ac_agent:-?}")

		# Attached marker from boo's own state.
		local attached marker=""
		attached=$(echo "$json" | jq -r --arg n "$name" '.[] | select(.name == $n) | .attached')
		[[ "$attached" == "true" ]] && marker=" *"

		printf "%d %s [%s]%s\n" "$idx" "$display" "$label" "$marker"
	done
}

# Resolve a target (name or index number) to a session name
resolve_target() {
	local target="$1"

	# If it's a number, resolve from listing order
	if [[ "$target" =~ ^[0-9]+$ ]]; then
		local idx=0 name
		while IFS= read -r name; do
			[[ -n "$name" ]] || continue
			idx=$((idx + 1))
			if [[ "$idx" -eq "$target" ]]; then
				echo "$name"
				return 0
			fi
		done < <(ac_session_names)
		die "no session at index $target"
	fi

	# Otherwise treat as a session name (with or without prefix)
	local name="$target"
	if [[ ! "$name" =~ ^${SESSION_PREFIX}- ]]; then
		name="${SESSION_PREFIX}-${name}"
	fi

	if session_alive "$name"; then
		echo "$name"
		return 0
	fi

	die "no session found: $target"
}

cmd_remove() {
	local target="$1"
	local name
	name=$(resolve_target "$target")
	boo kill "$name"
	rm -f "$(meta_file "$name")"
	echo "killed: $name"
}

cmd_help() {
	cat <<'EOF'
Usage: ac [flags] [command|repo] [branch]

Agent code session manager — create, attach, and manage
coding agent sessions as isolated boo sessions.

Commands:
  (no args)              List all agent sessions
  <repo> [branch]        Create or attach to session
  <number>               Attach to session by index
  ls                     List all agent sessions
  rm <name|number>       Kill a session
  help                   Show this help

Flags:
  -o, --opencode         Use opencode instead of claude
  -c, --claude           Use claude (default)

If the branch worktree does not exist, you will be prompted to
create it. The new branch is based on the appropriate remote:
  - Repos with an 'upstream' remote: fetches upstream, branches
    from upstream/main (e.g., headscale forks)
  - All other repos: fetches origin, branches from origin's
    default branch

The main repo lives at ~/git/<repo>; branch worktrees are created
under $WT_ROOT/<repo>/<branch> (default WT_ROOT: ~/worktrees).

Examples:
  ac                             List sessions
  ac headscale                   claude on ~/git/headscale (main repo)
  ac headscale kradalby/3049     claude on ~/worktrees/headscale/kradalby/3049
  ac headscale kradalby/new      prompts to create branch from upstream/main
  ac dotfiles                    claude on ~/git/dotfiles
  ac sfiber planet-olt -o        opencode on ~/worktrees/sfiber/planet-olt
  ac 2                           Attach to session #2
  ac rm 2                        Kill session #2
  ac rm headscale-kradalby-3049  Kill by name

Each session runs the coding agent (claude/opencode) in a login
shell, so the shell survives if the agent exits. boo sessions are
single-window: for a plain terminal in the same worktree, open a
new Ghostty tab and cd there.
EOF
}

# --- main ---

main() {
	local agent="$DEFAULT_AGENT"
	local args=()

	# Parse flags
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-o | --opencode)
			agent="opencode"
			shift
			;;
		-c | --claude)
			agent="claude"
			shift
			;;
		-h | --help)
			cmd_help
			return 0
			;;
		--)
			shift
			args+=("$@")
			break
			;;
		-*)
			die "unknown flag: $1"
			;;
		*)
			args+=("$1")
			shift
			;;
		esac
	done

	# No args: list sessions
	if [[ ${#args[@]} -eq 0 ]]; then
		cmd_list
		return 0
	fi

	local first="${args[0]}"

	# Subcommands
	case "$first" in
	ls | list)
		cmd_list
		;;
	rm | remove | kill)
		[[ ${#args[@]} -ge 2 ]] || die "usage: ac rm <name|number>"
		cmd_remove "${args[1]}"
		;;
	help)
		cmd_help
		;;
	*)
		# Number: attach by index
		if [[ "$first" =~ ^[0-9]+$ ]] && [[ ${#args[@]} -eq 1 ]]; then
			local name
			name=$(resolve_target "$first")
			attach_session "$name"
		else
			# repo [branch]: create or attach
			cmd_create_or_attach "$first" "${args[1]:-}" "$agent"
		fi
		;;
	esac
}

main "$@"
