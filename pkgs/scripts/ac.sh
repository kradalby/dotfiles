#!/usr/bin/env bash
set -euo pipefail

# Main repos live at $GIT_ROOT/<repo>; worktrees at $WT_ROOT/<repo>/<branch>.
# Mirrors the layout used by wt.fish (default WT_ROOT: ~/worktrees).
GIT_ROOT="${GIT_ROOT:-$HOME/git}"
WT_ROOT="${WT_ROOT:-$HOME/worktrees}"
DEFAULT_AGENT="claude"

# All agent sessions live inside ONE herdr session, so they show up together in a
# single overview and a single `herdr` attach — one workspace per repo/branch.
# Everything below drives that session over herdr's socket API.
HERDR_SESSION="${HERDR_SESSION:-ac}"

# --- helpers ---

die() {
	echo "error: $*" >&2
	exit 1
}

# h: run a herdr control command against our session. Wrapping keeps the
# --session plumbing in one place and out of every call site.
h() {
	herdr --session "$HERDR_SESSION" "$@"
}

sanitize() {
	# Slashes are illegal in herdr agent names; branch names contain them.
	echo "$1" | tr '/' '-'
}

# display: human name for a session — "repo/branch" or just "repo".
display() {
	local repo="$1" branch="$2"
	if [[ -n "$branch" ]]; then echo "$repo/$branch"; else echo "$repo"; fi
}

agent_label() {
	case "$1" in
	opencode) echo "oc" ;;
	claude) echo "cl" ;;
	codex) echo "cx" ;;
	*) echo "$1" ;;
	esac
}

# The workspace label is the single source of truth for repo/branch/agent:
#   "<repo>[/<branch>] [<al>]"   e.g. "headscale/kradalby/3049 [cl]"
# It stays human-readable in herdr's sidebar and parses back unambiguously
# (repo has no '/', so the first '/' splits repo from branch; the trailing
# "[al]" is the agent). Workdir is read separately from the pane's real cwd, so
# a worktree checked out off-convention is still reported correctly.
make_label() {
	local repo="$1" branch="$2" agent="$3"
	echo "$(display "$repo" "$branch") [$(agent_label "$agent")]"
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

# --- herdr server / lookup ---

server_running() {
	h status server 2>/dev/null | grep -q '^status: running'
}

ensure_server() {
	# Control commands do not auto-start the server (attaching to a dead socket
	# errors), so make sure it's up. On the deployed box a systemd user unit owns
	# it; fall back to spawning a detached server for anywhere that unit isn't
	# running (first boot, a mac, a throwaway shell).
	server_running && return 0
	systemctl --user start herdr 2>/dev/null || true
	if ! server_running; then
		nohup herdr --session "$HERDR_SESSION" server >/dev/null 2>&1 &
	fi
	# Socket appears a beat after the process; wait briefly.
	for _ in $(seq 1 20); do
		server_running && return 0
		sleep 0.25
	done
	die "herdr server for session '$HERDR_SESSION' did not come up"
}

# find_workspace echoes the workspace_id whose session (repo/branch) matches,
# or nothing. Match is on the display part of the label (agent-agnostic, so
# `ac repo` and `ac -o repo` share one workspace — mirrors the old server name).
find_workspace() {
	local repo="$1" branch="$2" want
	want="$(display "$repo" "$branch")"
	h workspace list 2>/dev/null |
		jq -r --arg w "$want" '
			.result.workspaces[]
			| select((.label | sub(" \\[[^]]*\\]$"; "")) == $w)
			| .workspace_id' | head -1
}

# --- commands ---

create_session() {
	# Create the workspace + agent pane for a repo/branch. Echoes agent name.
	local dir="$1" agent="$2" repo="$3" branch="$4"

	local label name wid
	label="$(make_label "$repo" "$branch" "$agent")"
	name="$(sanitize "$(display "$repo" "$branch")")" # unique agent handle

	# Workspace holds two panes in one tab: the root shell (the old `term`
	# window) and the agent pane started next. --no-focus so a headless spawn
	# doesn't steal the attached client's view.
	wid=$(h workspace create --cwd "$dir" --label "$label" --no-focus |
		jq -r '.result.workspace.workspace_id')
	[[ -n "$wid" && "$wid" != "null" ]] || die "workspace create failed"

	# Launch the agent. For claude: --dangerously-skip-permissions (no tool
	# prompts), pre-trust the dir (a separate gate, pinned explicitly so it
	# survives claude behaviour drift), and Remote Control named
	# <host>-<repo>-<branch> so the session is also reachable from claude.ai /
	# the phone. AC_TRUST=0 / AC_REMOTE_CONTROL=0 opt out respectively. argv goes
	# straight to herdr after `--`, no shell in between.
	local argv=("$agent")
	if [[ "$agent" == "claude" ]]; then
		ensure_trusted "$dir"
		argv=("$agent" --dangerously-skip-permissions)
		if [[ "${AC_REMOTE_CONTROL:-1}" == "1" ]]; then
			local rc_name
			rc_name="$(hostname -s)-${repo}"
			[[ -n "$branch" ]] && rc_name="${rc_name}-$(sanitize "$branch")"
			argv+=(--remote-control "$rc_name")
		fi
	fi
	h agent start "$name" --workspace "$wid" --cwd "$dir" --no-focus -- "${argv[@]}" >/dev/null

	echo "$name"
}

# attach_herd hands off to the herdr TUI so `ac`/`ac ls` land you in the one
# session's overview. When already inside herdr (HERDR_ENV=1) the client is
# attached to this very session, so exec'ing the TUI would nest herdr inside the
# current pane — just say so and return instead.
attach_herd() {
	if [[ "${HERDR_ENV:-}" == "1" ]]; then
		echo "already attached to herd (session: $HERDR_SESSION)"
		return 0
	fi
	exec herdr --session "$HERDR_SESSION"
}

# attach focuses the workspace (and its agent pane) then hands off to the herdr
# TUI, so `ac <repo>` always lands you in the one session on the right pane.
# Inside herdr the focus calls already move the attached client's view to the
# target, so we skip the exec (which would nest herdr in the current pane) and
# just hand the prompt back — the view has already switched.
attach_workspace() {
	local wid="$1" name="$2" repo="${3:-}" branch="${4:-}"
	h workspace focus "$wid" >/dev/null 2>&1 || true
	h agent focus "$name" >/dev/null 2>&1 || true
	if [[ "${HERDR_ENV:-}" == "1" ]]; then
		echo "switched to $(display "$repo" "$branch")"
		return 0
	fi
	exec herdr --session "$HERDR_SESSION"
}

cmd_create_or_attach() {
	local repo="$1" branch="${2:-}" agent="${3:-$DEFAULT_AGENT}"

	local dir
	if [[ -n "$branch" ]]; then
		# Resolve to an existing worktree (creating on confirmation if none).
		dir=$(ensure_worktree "$repo" "$branch" interactive) || return 1
	else
		dir=$(find_main_worktree "$repo")
	fi

	ensure_server

	local wid name
	wid=$(find_workspace "$repo" "$branch")
	if [[ -n "$wid" ]]; then
		name="$(sanitize "$(display "$repo" "$branch")")"
	else
		name=$(create_session "$dir" "$agent" "$repo" "$branch")
		wid=$(find_workspace "$repo" "$branch")
	fi
	attach_workspace "$wid" "$name" "$repo" "$branch"
}

cmd_spawn() {
	# Headless create: like cmd_create_or_attach but never prompts and never
	# attaches. Used by ac-web to start a detached session from the phone; you
	# attach later with `ac <repo> [branch]`.
	local repo="$1" branch="${2:-}" agent="${3:-$DEFAULT_AGENT}"

	local dir
	if [[ -n "$branch" ]]; then
		dir=$(ensure_worktree "$repo" "$branch") || return 1
	else
		dir=$(find_main_worktree "$repo")
	fi

	ensure_server

	if [[ -n "$(find_workspace "$repo" "$branch")" ]]; then
		echo "already running: $(display "$repo" "$branch")"
		return 0
	fi

	create_session "$dir" "$agent" "$repo" "$branch" >/dev/null
	echo "spawned: $(display "$repo" "$branch")"
}

# workdir_of echoes the real cwd of a workspace (its root pane), so ac-web can
# refuse deleting a worktree that backs a live session.
workdir_of() {
	h pane list --workspace "$1" 2>/dev/null |
		jq -r '.result.panes[0].cwd // ""'
}

cmd_list_porcelain() {
	# Machine-readable listing for ac-web. One live session per line, tab
	# separated: workspace<TAB>repo<TAB>branch<TAB>agent<TAB>attached(0|1)<TAB>workdir.
	# repo/branch/agent come from the label; workdir from the pane's real cwd;
	# attached(=focused) marks the workspace the TUI is currently showing.
	server_running || return 0

	local wid label focused
	while IFS=$'\t' read -r wid label focused; do
		[[ -n "$wid" ]] || continue

		local agent_l disp repo branch agent workdir attached
		# label = "DISPLAY [al]" — split off the trailing agent tag.
		agent_l="${label##*\[}"
		agent_l="${agent_l%\]}"
		disp="${label% \[*\]}"
		case "$agent_l" in
		cl) agent="claude" ;;
		oc) agent="opencode" ;;
		cx) agent="codex" ;;
		*) agent="$agent_l" ;;
		esac
		# repo has no '/', so the first '/' splits repo from branch.
		if [[ "$disp" == */* ]]; then
			repo="${disp%%/*}"
			branch="${disp#*/}"
		else
			repo="$disp"
			branch=""
		fi
		workdir=$(workdir_of "$wid")
		attached=0
		[[ "$focused" == "true" ]] && attached=1

		printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$wid" "$repo" "$branch" "$agent" "$attached" "$workdir"
	done < <(h workspace list 2>/dev/null |
		jq -r '.result.workspaces[] | [.workspace_id, .label, .focused] | @tsv')
}

# Resolve a target (workspace_id or repo[/branch] display name) to a workspace_id.
resolve_target() {
	local target="$1"

	local ids
	ids=$(h workspace list 2>/dev/null | jq -r '.result.workspaces[].workspace_id')

	# Exact workspace_id (what ac-web passes back from the porcelain listing).
	if grep -qxF "$target" <<<"$ids"; then
		echo "$target"
		return 0
	fi

	# Otherwise treat it as a repo[/branch] display name.
	local wid
	wid=$(h workspace list 2>/dev/null |
		jq -r --arg w "$target" '
			.result.workspaces[]
			| select((.label | sub(" \\[[^]]*\\]$"; "")) == $w)
			| .workspace_id' | head -1)
	[[ -n "$wid" ]] && {
		echo "$wid"
		return 0
	}

	die "no session found: $target"
}

cmd_remove() {
	local target="$1"
	local wid
	wid=$(resolve_target "$target")

	# Stop the agent gracefully before tearing the workspace down: SIGTERM lets
	# `claude remote-control` deregister cleanly (a forced kill orphaned it and
	# filled the claude.ai picker with dead duplicates). herdr runs the agent
	# argv directly as the pane process, so its shell_pid IS the agent — signal
	# it, wait out a grace window, then close the workspace (which also disposes
	# the term pane). `|| true`: goal state is a closed workspace; if the agent
	# already exited, the missing pid/pane must not abort us before close.
	local pane pid
	pane=$(h agent list 2>/dev/null |
		jq -r --arg w "$wid" '.result.agents[] | select(.workspace_id==$w) | .pane_id' | head -1)
	if [[ -n "$pane" && "$pane" != "null" ]]; then
		pid=$(h pane process-info --pane "$pane" 2>/dev/null |
			jq -r '.result.process_info.shell_pid // empty')
		if [[ -n "$pid" ]]; then
			kill -TERM "$pid" 2>/dev/null || true
			# ~10s grace for the agent to deregister and exit
			for _ in $(seq 1 20); do
				kill -0 "$pid" 2>/dev/null || break
				sleep 0.5
			done
		fi
	fi

	h workspace close "$wid" 2>/dev/null || true
	echo "killed: $wid"
}

cmd_help() {
	cat <<'EOF'
Usage: ac [flags] [command|repo] [branch]

Agent code session manager — one herdr session ("ac") holds every coding-agent
session as a workspace, so they share a single overview and a single attach.

Commands:
  <repo> [branch]        Create the workspace if needed, then attach the herdr
                         session focused on that repo/branch's agent pane
  ls --porcelain         Tab-separated listing (for ac-web)
  spawn <repo> [branch]  Create a detached workspace without attaching (for ac-web)
  rm <workspace|name>    Gracefully stop the agent and close the workspace
  help                   Show this help

Flags:
  -o, --opencode         Use opencode instead of claude
  -c, --claude           Use claude (default)
  -x, --codex            Use codex

To list, switch, or split sessions interactively, attach the herd with `herdr`
(or `herdr --session ac`) and use its TUI — that's the single overview.

If the branch worktree does not exist, you will be prompted to create it. An
existing branch is checked out as-is; a new branch is based on the appropriate
remote:
  - Repos with an 'upstream' remote: fetches upstream, branches from
    upstream/main (e.g., headscale forks)
  - All other repos: fetches origin, branches from origin's default branch

The main repo lives at ~/git/<repo>; branch worktrees are created under
$WT_ROOT/<repo>/<branch> (default WT_ROOT: ~/worktrees).

Examples:
  ac headscale                   claude on ~/git/headscale (main repo)
  ac headscale kradalby/3049     claude on ~/worktrees/headscale/kradalby/3049
  ac headscale kradalby/new      prompts to create branch from upstream/main
  ac sfiber planet-olt -o        opencode on ~/worktrees/sfiber/planet-olt
  ac rm headscale/kradalby/3049  Gracefully close that workspace

Each workspace opens two herdr panes in one tab:
  agent   Coding agent (claude/opencode/codex), launched directly (argv, no shell)
  shell   Plain terminal in the same directory (the workspace root pane)

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
		-x | --codex)
			agent="codex"
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

	# No args: point at the herd. Listing/switching is herdr's job now.
	if [[ ${#args[@]} -eq 0 ]]; then
		if server_running; then
			attach_herd
			return 0
		fi
		echo "no agent sessions (herdr server not running)"
		return 0
	fi

	local first="${args[0]}"

	# Subcommands
	case "$first" in
	ls | list)
		if [[ "$porcelain" == 1 ]]; then
			cmd_list_porcelain
		else
			# Human listing is the herdr TUI; a bare `ac ls` just attaches it.
			if server_running; then
				attach_herd
			else
				echo "no agent sessions (herdr server not running)"
			fi
		fi
		;;
	spawn)
		[[ ${#args[@]} -ge 2 ]] || die "usage: ac spawn <repo> [branch]"
		cmd_spawn "${args[1]}" "${args[2]:-}" "$agent"
		;;
	rm | remove | kill)
		[[ ${#args[@]} -ge 2 ]] || die "usage: ac rm <workspace|name>"
		ensure_server
		cmd_remove "${args[1]}"
		;;
	help)
		cmd_help
		;;
	*)
		# repo [branch]: create or attach
		cmd_create_or_attach "$first" "${args[1]:-}" "$agent"
		;;
	esac
}

main "$@"
