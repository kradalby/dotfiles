#!/usr/bin/env bash
set -euo pipefail

# Main repos live at $GIT_ROOT/<repo>; worktrees at $WT_ROOT/<repo>/<branch>.
# Mirrors the layout used by wt.fish (default WT_ROOT: ~/worktrees).
GIT_ROOT="${GIT_ROOT:-$HOME/git}"
WT_ROOT="${WT_ROOT:-$HOME/worktrees}"
DEFAULT_AGENT="claude"
SERVER_PREFIX="ac"

# --- helpers ---

die() {
	echo "error: $*" >&2
	exit 1
}

sock_dir() {
	echo "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)"
}

sanitize() {
	# Replace / with - for use in tmux server socket names
	echo "$1" | tr '/' '-'
}

server_name() {
	local repo="$1" branch="$2"
	if [[ -n "$branch" ]]; then
		echo "${SERVER_PREFIX}-${repo}-$(sanitize "$branch")"
	else
		echo "${SERVER_PREFIX}-${repo}"
	fi
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
	# Create a new branch worktree, fetching the appropriate remote first.
	# Repos with an 'upstream' remote (e.g. headscale) base off upstream/main;
	# all others base off origin's default branch.
	local main_wt="$1" target_path="$2" branch="$3"

	# Ensure the parent dir exists for nested branch names (e.g. feature/foo).
	mkdir -p "$(dirname "$target_path")"

	# Fetch and pick the base the branch would be created from.
	local base
	if git -C "$main_wt" remote | grep -q '^upstream$'; then
		echo "Fetching upstream..."
		git -C "$main_wt" fetch upstream
		base="upstream/main"
	else
		base=$(git -C "$main_wt" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null |
			sed 's@^refs/remotes/@@' || echo "origin/main")
		echo "Fetching origin..."
		git -C "$main_wt" fetch origin
	fi

	# If the branch already exists locally, check it out; if it exists only on a
	# remote, create a local tracking branch from it; otherwise create from base.
	if git -C "$main_wt" show-ref --verify --quiet "refs/heads/$branch"; then
		echo "Checking out existing branch '$branch' at $target_path..."
		git -C "$main_wt" worktree add "$target_path" "$branch"
	elif git -C "$main_wt" show-ref --verify --quiet "refs/remotes/upstream/$branch"; then
		echo "Creating worktree at $target_path tracking upstream/$branch..."
		git -C "$main_wt" worktree add "$target_path" --track -b "$branch" "upstream/$branch"
	elif git -C "$main_wt" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
		echo "Creating worktree at $target_path tracking origin/$branch..."
		git -C "$main_wt" worktree add "$target_path" --track -b "$branch" "origin/$branch"
	else
		echo "Creating worktree at $target_path from $base..."
		git -C "$main_wt" worktree add "$target_path" -b "$branch" "$base"
	fi

	# Allow direnv if the new worktree has an .envrc
	if [[ -f "$target_path/.envrc" ]]; then
		echo "Allowing direnv in $target_path..."
		direnv allow "$target_path"
	fi
}

# ensure_worktree echoes the worktree dir for a branch, creating it if absent.
# A branch already checked out is resolved to its actual worktree even when the
# directory name differs from the branch (so we always end up in the right
# place). With mode "interactive", prompts before creating; otherwise creates
# silently. Progress goes to stderr so stdout is only the resolved path.
ensure_worktree() {
	local repo="$1" branch="$2" mode="${3:-}"

	local main_wt existing
	main_wt=$(find_main_worktree "$repo")

	# Already checked out somewhere? Use that worktree, whatever it is named.
	existing=$(git -C "$main_wt" worktree list --porcelain |
		awk -v b="refs/heads/$branch" '/^worktree /{p=substr($0,10)} /^branch /{if($2==b){print p; exit}}')
	if [[ -n "$existing" ]]; then
		echo "$existing"
		return 0
	fi

	# Conventional path under WT_ROOT.
	local target_path="$WT_ROOT/$repo/$branch"
	if [[ -d "$target_path" ]]; then
		echo "$target_path"
		return 0
	fi

	if [[ "$mode" == "interactive" ]]; then
		local answer
		read -rp "Branch '$branch' not found for $repo. Create? [y/N] " answer
		[[ "$answer" =~ ^[Yy]$ ]] || return 1
	fi
	create_branch_worktree "$main_wt" "$target_path" "$branch" >&2
	echo "$target_path"
}

server_alive() {
	local server="$1"
	tmux -L "$server" list-sessions &>/dev/null
}

ensure_trusted() {
	# Pre-accept claude's per-directory workspace-trust dialog for $1, so a
	# freshly created worktree doesn't leave the agent blocked at the trust
	# prompt (there's no CLI flag for it — it lives in ~/.claude.json). This is
	# exactly what clicking "Yes, I trust this folder" writes. AC_TRUST=0 skips.
	local dir="$1" cfg="$HOME/.claude.json" tmp
	[[ "${AC_TRUST:-1}" == "1" ]] || return 0
	[[ -f "$cfg" ]] || echo '{}' >"$cfg"

	# Skip (no write) if already trusted — avoids needlessly rewriting a file
	# claude also writes, shrinking any lost-update race to brand-new dirs only.
	if [[ "$(jq -r --arg d "$dir" '.projects[$d].hasTrustDialogAccepted // false' "$cfg" 2>/dev/null)" == "true" ]]; then
		return 0
	fi

	# Atomic same-dir temp + mv so a reader never sees a partial file.
	tmp="$(mktemp "${cfg}.XXXXXX")"
	if jq --arg d "$dir" '.projects[$d].hasTrustDialogAccepted = true' "$cfg" >"$tmp" 2>/dev/null; then
		mv "$tmp" "$cfg"
	else
		rm -f "$tmp"
	fi
}

# --- commands ---

create_session() {
	local server="$1" dir="$2" agent="$3" repo="$4" branch="$5"

	# Build display title: "repo/branch [agent]" or "repo [agent]"
	local agent_label
	case "$agent" in
	opencode) agent_label="oc" ;;
	claude) agent_label="cl" ;;
	*) agent_label="$agent" ;;
	esac

	local display
	if [[ -n "$branch" ]]; then
		display="$repo/$branch"
	else
		display="$repo"
	fi

	# Create server with agent window
	tmux -L "$server" new-session -d -s work -n agent -c "$dir"

	# Set terminal title so Ghostty tabs show something useful
	tmux -L "$server" set-option -g set-titles on
	tmux -L "$server" set-option -g set-titles-string "$display [$agent_label] #W"

	# Create terminal window
	tmux -L "$server" new-window -t work -n term -c "$dir"

	# Store metadata for listing
	tmux -L "$server" set-environment -t work AC_REPO "$repo"
	tmux -L "$server" set-environment -t work AC_BRANCH "$branch"
	tmux -L "$server" set-environment -t work AC_AGENT "$agent"
	tmux -L "$server" set-environment -t work AC_WORKDIR "$dir"

	# Launch agent in first window (shell survives if agent exits). For claude:
	# run with --dangerously-skip-permissions (no tool prompts), pre-trust the
	# dir (no trust prompt — a separate gate, pinned explicitly so it survives
	# claude behaviour drift), and enable Remote Control named
	# <host>-<repo>-<branch> so the session is also reachable from claude.ai /
	# the phone. AC_TRUST=0 / AC_REMOTE_CONTROL=0 opt out respectively.
	local launch="$agent"
	if [[ "$agent" == "claude" ]]; then
		ensure_trusted "$dir"
		launch="$agent --dangerously-skip-permissions"
		if [[ "${AC_REMOTE_CONTROL:-1}" == "1" ]]; then
			local rc_name
			rc_name="$(hostname -s)-${repo}"
			[[ -n "$branch" ]] && rc_name="${rc_name}-$(sanitize "$branch")"
			launch="$launch --remote-control $rc_name"
		fi
	fi
	tmux -L "$server" send-keys -t work:agent "$launch" Enter

	# Focus the agent window
	tmux -L "$server" select-window -t work:agent
}

attach_session() {
	local server="$1"
	# TMUX='' allows attaching from inside another tmux session
	# -d detaches other clients (phone takes over from laptop)
	TMUX='' tmux -L "$server" attach -d -t work
}

cmd_create_or_attach() {
	local repo="$1" branch="${2:-}" agent="${3:-$DEFAULT_AGENT}"

	local dir effective_branch server
	if [[ -n "$branch" ]]; then
		# Resolve to an existing worktree (creating on confirmation if none).
		dir=$(ensure_worktree "$repo" "$branch" interactive) || return 1
	else
		dir=$(resolve_path "$repo" "")
	fi
	effective_branch=$(resolve_branch "$repo" "$branch")
	server=$(server_name "$repo" "$effective_branch")

	if server_alive "$server"; then
		attach_session "$server"
	else
		# Clean up stale socket if present
		local sock
		sock="$(sock_dir)/$server"
		[[ -e "$sock" ]] && rm -f "$sock"

		create_session "$server" "$dir" "$agent" "$repo" "$effective_branch"
		attach_session "$server"
	fi
}

cmd_spawn() {
	# Headless create: like cmd_create_or_attach but never prompts and never
	# attaches. Used by ac-web to start a detached session from the phone; you
	# attach later with `ac <repo> [branch]`.
	local repo="$1" branch="${2:-}" agent="${3:-$DEFAULT_AGENT}"

	# Resolve to an existing worktree, creating it if missing (no prompt, unlike
	# the interactive path).
	local dir effective_branch server
	if [[ -n "$branch" ]]; then
		dir=$(ensure_worktree "$repo" "$branch") || return 1
	else
		dir=$(resolve_path "$repo" "")
	fi
	effective_branch=$(resolve_branch "$repo" "$branch")
	server=$(server_name "$repo" "$effective_branch")

	if server_alive "$server"; then
		echo "already running: $server"
		return 0
	fi

	# Clean up stale socket if present
	local sock
	sock="$(sock_dir)/$server"
	[[ -e "$sock" ]] && rm -f "$sock"

	create_session "$server" "$dir" "$agent" "$repo" "$effective_branch"
	echo "spawned: $server"
}

cmd_list() {
	local dir
	dir="$(sock_dir)"

	if [[ ! -d "$dir" ]]; then
		echo "no agent sessions"
		return 0
	fi

	local found=0 idx=0
	local sockets=()
	while IFS= read -r -d '' sock; do
		sockets+=("$sock")
	done < <(find "$dir" -maxdepth 1 -name "${SERVER_PREFIX}-*" -print0 2>/dev/null | sort -z)

	for sock in "${sockets[@]}"; do
		[[ -e "$sock" ]] || continue

		local server
		server=$(basename "$sock")

		if ! server_alive "$server"; then
			# Stale socket, clean up silently
			rm -f "$sock"
			continue
		fi

		idx=$((idx + 1))
		found=1

		# Read metadata from tmux environment
		local ac_repo ac_branch ac_agent
		ac_repo=$(tmux -L "$server" show-environment -t work AC_REPO 2>/dev/null | sed 's/^AC_REPO=//' || echo "?")
		ac_branch=$(tmux -L "$server" show-environment -t work AC_BRANCH 2>/dev/null | sed 's/^AC_BRANCH=//' || echo "")
		ac_agent=$(tmux -L "$server" show-environment -t work AC_AGENT 2>/dev/null | sed 's/^AC_AGENT=//' || echo "?")

		# Check if any client is attached
		local num_attached
		num_attached=$(tmux -L "$server" list-sessions -t work -F '#{session_attached}' 2>/dev/null | head -1 || echo "0")

		local marker=""
		if [[ "${num_attached:-0}" -gt 0 ]]; then
			marker=" *"
		fi

		# Short agent label
		local agent_label
		case "$ac_agent" in
		opencode) agent_label="oc" ;;
		claude) agent_label="cl" ;;
		*) agent_label="$ac_agent" ;;
		esac

		# Display name
		local display
		if [[ -n "$ac_branch" ]]; then
			display="$ac_repo/$ac_branch"
		else
			display="$ac_repo"
		fi

		printf "%d %s [%s]%s\n" "$idx" "$display" "$agent_label" "$marker"
	done

	if [[ "$found" -eq 0 ]]; then
		echo "no agent sessions"
	fi
}

cmd_list_porcelain() {
	# Machine-readable listing for ac-web. One live session per line, tab
	# separated: server<TAB>repo<TAB>branch<TAB>agent<TAB>attached(0|1)
	local dir
	dir="$(sock_dir)"
	[[ -d "$dir" ]] || return 0

	local sockets=()
	while IFS= read -r -d '' sock; do
		sockets+=("$sock")
	done < <(find "$dir" -maxdepth 1 -name "${SERVER_PREFIX}-*" -print0 2>/dev/null | sort -z)

	local sock server ac_repo ac_branch ac_agent num_attached attached
	for sock in "${sockets[@]}"; do
		[[ -e "$sock" ]] || continue
		server=$(basename "$sock")
		server_alive "$server" || continue

		ac_repo=$(tmux -L "$server" show-environment -t work AC_REPO 2>/dev/null | sed 's/^AC_REPO=//' || echo "")
		ac_branch=$(tmux -L "$server" show-environment -t work AC_BRANCH 2>/dev/null | sed 's/^AC_BRANCH=//' || echo "")
		ac_agent=$(tmux -L "$server" show-environment -t work AC_AGENT 2>/dev/null | sed 's/^AC_AGENT=//' || echo "")
		num_attached=$(tmux -L "$server" list-sessions -t work -F '#{session_attached}' 2>/dev/null | head -1 || echo "0")
		attached=0
		[[ "${num_attached:-0}" -gt 0 ]] && attached=1

		printf '%s\t%s\t%s\t%s\t%s\n' "$server" "$ac_repo" "$ac_branch" "$ac_agent" "$attached"
	done
}

# Resolve a target (name or index number) to a server name
resolve_target() {
	local target="$1"

	# If it's a number, resolve from listing order
	if [[ "$target" =~ ^[0-9]+$ ]]; then
		local dir
		dir="$(sock_dir)"
		[[ -d "$dir" ]] || die "no agent sessions"

		local idx=0
		local sockets=()
		while IFS= read -r -d '' sock; do
			sockets+=("$sock")
		done < <(find "$dir" -maxdepth 1 -name "${SERVER_PREFIX}-*" -print0 2>/dev/null | sort -z)

		for sock in "${sockets[@]}"; do
			[[ -e "$sock" ]] || continue
			local server
			server=$(basename "$sock")
			server_alive "$server" || continue
			idx=$((idx + 1))
			if [[ "$idx" -eq "$target" ]]; then
				echo "$server"
				return 0
			fi
		done
		die "no session at index $target"
	fi

	# Otherwise treat as server name (with or without prefix)
	local server="$target"
	if [[ ! "$server" =~ ^${SERVER_PREFIX}- ]]; then
		server="${SERVER_PREFIX}-${server}"
	fi

	if server_alive "$server"; then
		echo "$server"
		return 0
	fi

	die "no session found: $target"
}

cmd_remove() {
	local target="$1"
	local server
	server=$(resolve_target "$target")

	# Stop the agent gracefully: SIGTERM lets `claude remote-control` preserve
	# its environment and deregister cleanly. A forced kill orphaned it and
	# filled the claude.ai picker with dead duplicates. The agent runs as a
	# child of the pane's shell, so signal the shell's children. Fall back to
	# kill-server if it hasn't exited within the grace window.
	local pane_pid
	pane_pid=$(tmux -L "$server" list-panes -t work:agent -F '#{pane_pid}' 2>/dev/null | head -1)
	if [[ -n "$pane_pid" ]]; then
		pkill -TERM -P "$pane_pid" 2>/dev/null || true
		for _ in $(seq 1 20); do # ~10s grace
			pgrep -P "$pane_pid" >/dev/null 2>&1 || break
			sleep 0.5
		done
	fi

	tmux -L "$server" kill-server 2>/dev/null
	echo "killed: $server"
}

cmd_help() {
	cat <<'EOF'
Usage: ac [flags] [command|repo] [branch]

Agent code session manager — create, attach, and manage
coding agent sessions in isolated tmux servers.

Commands:
  (no args)              List all agent sessions
  <repo> [branch]        Create or attach to session
  <number>               Attach to session by index
  ls [--porcelain]       List all agent sessions (--porcelain: tab-separated)
  spawn <repo> [branch]  Create a detached session without attaching (for ac-web)
  rm <name|number>       Kill a session
  help                   Show this help

Flags:
  -o, --opencode         Use opencode instead of claude
  -c, --claude           Use claude (default)

If the branch worktree does not exist, you will be prompted to
create it. An existing branch is checked out as-is; a new branch
is based on the appropriate remote:
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

Each session opens two tmux windows:
  agent   Coding agent (opencode/claude), launched via send-keys
  term    Plain terminal in the same directory

claude sessions launch with --dangerously-skip-permissions (no tool prompts)
and Remote Control named <host>-<repo>-<branch>, so they are reachable from
claude.ai / the phone (AC_REMOTE_CONTROL=0 disables). The working dir is
pre-trusted so no trust prompt blocks the agent (AC_TRUST=0 disables).
EOF
}

# --- main ---

main() {
	local agent="$DEFAULT_AGENT"
	local porcelain=0
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
		-p | --porcelain)
			porcelain=1
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
		if [[ "$porcelain" == 1 ]]; then
			cmd_list_porcelain
		else
			cmd_list
		fi
		;;
	spawn)
		[[ ${#args[@]} -ge 2 ]] || die "usage: ac spawn <repo> [branch]"
		cmd_spawn "${args[1]}" "${args[2]:-}" "$agent"
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
			local server
			server=$(resolve_target "$first")
			attach_session "$server"
		else
			# repo [branch]: create or attach
			cmd_create_or_attach "$first" "${args[1]:-}" "$agent"
		fi
		;;
	esac
}

main "$@"
