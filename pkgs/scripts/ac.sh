#!/usr/bin/env bash
set -euo pipefail

GIT_ROOT="$HOME/git"
DEFAULT_AGENT="opencode"
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

	if [[ -n "$branch" ]]; then
		local path="$GIT_ROOT/$repo/$branch"
		if [[ -d "$path" ]]; then
			echo "$path"
			return 0
		fi
		die "worktree not found: $path"
	fi

	# No branch specified — try to resolve
	local repo_path="$GIT_ROOT/$repo"

	# Direct repo (non-worktree): has .git file or directory
	if [[ -e "$repo_path/.git" ]]; then
		echo "$repo_path"
		return 0
	fi

	# Worktree container: try main, then master
	if [[ -d "$repo_path/main" ]]; then
		echo "$repo_path/main"
		return 0
	fi
	if [[ -d "$repo_path/master" ]]; then
		echo "$repo_path/master"
		return 0
	fi

	die "cannot resolve repo '$repo': $repo_path is not a git repo and has no main/master worktree"
}

resolve_branch() {
	# Given repo and optional branch, return the effective branch name
	local repo="$1" branch="${2:-}"

	if [[ -n "$branch" ]]; then
		echo "$branch"
		return 0
	fi

	local repo_path="$GIT_ROOT/$repo"

	if [[ -e "$repo_path/.git" ]]; then
		# Non-worktree repo — no branch component
		echo ""
		return 0
	fi

	if [[ -d "$repo_path/main" ]]; then
		echo "main"
		return 0
	fi
	if [[ -d "$repo_path/master" ]]; then
		echo "master"
		return 0
	fi

	echo ""
}

server_alive() {
	local server="$1"
	tmux -L "$server" list-sessions &>/dev/null
}

# --- commands ---

create_session() {
	local server="$1" dir="$2" agent="$3" repo="$4" branch="$5"

	# Create server with agent window
	tmux -L "$server" new-session -d -s work -n agent -c "$dir"

	# Create terminal window
	tmux -L "$server" new-window -t work -n term -c "$dir"

	# Store metadata for listing
	tmux -L "$server" set-environment -t work AC_REPO "$repo"
	tmux -L "$server" set-environment -t work AC_BRANCH "$branch"
	tmux -L "$server" set-environment -t work AC_AGENT "$agent"
	tmux -L "$server" set-environment -t work AC_WORKDIR "$dir"

	# Launch agent in first window (shell survives if agent exits)
	tmux -L "$server" send-keys -t work:agent "$agent" Enter

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
	dir=$(resolve_path "$repo" "$branch")
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
	tmux -L "$server" kill-server
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
  ls                     List all agent sessions
  rm <name|number>       Kill a session
  help                   Show this help

Flags:
  -c, --claude           Use claude instead of opencode

Examples:
  ac                             List sessions
  ac headscale main              opencode on ~/git/headscale/main
  ac headscale kradalby/3049     opencode on ~/git/headscale/kradalby/3049
  ac dotfiles                    opencode on ~/git/dotfiles
  ac headscale main -c           claude on ~/git/headscale/main
  ac 2                           Attach to session #2
  ac rm 2                        Kill session #2
  ac rm headscale-main           Kill by name

Each session opens two tmux windows:
  agent   Coding agent (opencode/claude), launched via send-keys
  term    Plain terminal in the same directory
EOF
}

# --- main ---

main() {
	local agent="$DEFAULT_AGENT"
	local args=()

	# Parse flags
	while [[ $# -gt 0 ]]; do
		case "$1" in
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
