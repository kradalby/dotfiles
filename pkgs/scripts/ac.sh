#!/usr/bin/env bash
set -euo pipefail

# Main repos live at $GIT_ROOT/<repo>; worktrees at $WT_ROOT/<repo>/<branch>.
# Mirrors the layout used by wt (default WT_ROOT: ~/worktrees).
GIT_ROOT="${GIT_ROOT:-$HOME/git}"
WT_ROOT="${WT_ROOT:-$HOME/worktrees}"
# A job (main checkout, role or branch) is one rex tab per agent, inside a
# session named after the repo unless -s says otherwise. Claude unless
# -c/-o/-x ask for others.
DEFAULT_AGENTS=(claude)

# A role pins long-lived agents to one repo for one job (deploy today, others
# later). It always opens the repo's main worktree -- never a branch worktree.
ROLE=""
# Overrides for the rex session and tab a job lands in.
SESSION=""
TAB=""

# --- helpers ---

die() {
  echo "error: $*" >&2
  exit 1
}

# display: human name for a job — "repo:role", "repo/branch", or "repo:main".
display() {
  local repo="$1" branch="$2"
  if [[ -n "$ROLE" ]]; then
    echo "$repo:$ROLE"
  elif [[ -n "$branch" ]]; then
    echo "$repo/$branch"
  else
    echo "$repo:main"
  fi
}

# slug folds a name into a rex-friendly label. printf (not echo): `tr -c`
# would fold a trailing newline into '-'.
slug() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '-'
  echo
}

# tab_name: the tab a job's agent gets. Claude carries the bare job name, so
# the common case reads "deploy"; other agents get a suffix.
tab_name() {
  local branch="$1" agent="$2" name
  if [[ -n "$TAB" ]]; then
    name="$TAB"
  elif [[ -n "$ROLE" ]]; then
    name="$ROLE"
  elif [[ -n "$branch" ]]; then
    name=$(slug "$branch")
  else
    name="main"
  fi
  case "$agent" in
    claude) echo "$name" ;;
    codex) echo "$name-cx" ;;
    opencode) echo "$name-oc" ;;
    *) echo "$name-$agent" ;;
  esac
}

# The pane label marks a tab as ac's and carries its job: tab names are free
# for the user to rename and share a session with hand-made tabs. A pane label
# survives the agent's own terminal title changes.
#   ac|<repo>|<branch>|<role>|<agent>
tab_meta() {
  printf 'ac|%s|%s|%s|%s\n' "$1" "$2" "$ROLE" "$3"
}

# ac_tabs lists every ac pane on the server, tab separated:
# session_id, session_label, window_id, block_id, meta.
ac_tabs() {
  local sid label
  while IFS=$'\t' read -r sid label; do
    rex --autostart=false session inspect "$sid" --json 2>/dev/null |
      jq -r --arg s "$sid" --arg l "$label" '.windows[]? | .window_id as $w
        | .layers[]?.blocks[]? | select(.label | startswith("ac|"))
        | [$s, $l, $w, .block_id, .label] | @tsv'
  done < <(rex --autostart=false ls --json 2>/dev/null | jq -r '.sessions[] | [.session_id, .label] | @tsv')
}

# find_tab echoes the ac_tabs row for a job's agent, wherever the tab has moved.
find_tab() {
  local meta
  meta=$(tab_meta "$1" "$2" "$3")
  ac_tabs | awk -F'\t' -v m="$meta" '$5 == m { print; exit }'
}

session_id() {
  rex ls --json 2>/dev/null | jq -r --arg l "$1" '[.sessions[] | select(.label == $l)][0].session_id // empty'
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

ensure_trusted_codex() {
  # Codex has the same per-directory trust gate as claude, and blocks on it at
  # startup — the tab sits at a dialog instead of a prompt. Its answer lives in
  # ~/.codex/config.toml as a [projects."<dir>"] table, and `-c` overrides do
  # NOT satisfy the check (verified: the flag reaches codex and the dialog
  # still appears), so the table has to be on disk. AC_TRUST=0 skips.
  [[ "${AC_TRUST:-1}" == "1" ]] || return 0
  # Use Codex's TOML editor: an existing table may be untrusted, quoted
  # differently, or inline. A textual append cannot safely update those forms.
  codex_connection "" codex_trust_project "$1"
}

claude_remote_control_enabled() {
  local host="$1"
  [[ "${AC_REMOTE_CONTROL:-1}" == "1" && "$host" != "kradalby-llm" ]]
}

# --- commands ---

# Initialize one connection, then run an operation with the matching-response
# request helper. Trust edits always use a standalone local server.
codex_connection() (
  local remote="$1" operation="$2"
  shift 2
  local transport=()
  case "$remote" in
    "")
      transport=(codex app-server --stdio)
      ;;
    unix://)
      transport=(websocat --text --exit-on-eof --ws-c-uri ws://localhost/ -
        "ws-c:unix-connect:${CODEX_HOME:-$HOME/.codex}/app-server-control/app-server-control.sock")
      ;;
    unix://*)
      transport=(websocat --text --exit-on-eof --ws-c-uri ws://localhost/ - "ws-c:unix-connect:${remote#unix://}")
      ;;
    ws://* | wss://*) transport=(websocat --text --exit-on-eof - "$remote") ;;
    *)
      echo "unsupported Codex endpoint: $remote" >&2
      return 1
      ;;
  esac

  coproc CODEX_CREATE { timeout 90s "${transport[@]}"; }
  local transport_pid=$CODEX_CREATE_PID
  local original_reader=${CODEX_CREATE[0]} original_writer=${CODEX_CREATE[1]}
  local reader writer
  exec {reader}<&"$original_reader" {writer}>&"$original_writer"
  exec {original_reader}<&- {original_writer}>&-
  trap 'exec {writer}>&-; exec {reader}<&-; wait "$transport_pid" || true' EXIT

  # Ignore notifications and only accept the matching response, including
  # explicit error handling so a failed name never opens an unnamed TUI.
  request() {
    local id="$1" method="$2" params="$3" response
    jq -nc --argjson id "$id" --arg method "$method" --argjson params "$params" \
      '{id:$id,method:$method,params:$params}' >&"$writer" || return 1
    while IFS= read -r -t 60 response <&"$reader"; do
      if jq -e --argjson id "$id" '.id == $id' <<<"$response" >/dev/null; then
        if jq -e 'has("error")' <<<"$response" >/dev/null; then
          jq -r '.error.message' <<<"$response" >&2
          return 1
        fi
        jq -e 'has("result")' <<<"$response" >/dev/null || return 1
        printf '%s\n' "$response"
        return 0
      fi
    done
    echo "Codex $method did not respond" >&2
    return 1
  }

  request 0 initialize '{"clientInfo":{"name":"ac","version":"1"},"capabilities":{"experimentalApi":true}}' >/dev/null || return 1
  printf '%s\n' '{"method":"initialized","params":{}}' >&"$writer" || return 1
  "$operation" "$@"
)

codex_trust_project() {
  # A quoted leaf update preserves unrelated projects' comments and formatting.
  request 1 config/value/write "$(jq -nc --arg dir "$1" \
    '{keyPath:("projects." + ($dir | tojson) + ".trust_level"),value:"trusted",mergeStrategy:"upsert"}')" >/dev/null
}

# Create and save a named thread before opening its TUI, using the shared
# server when available or a temporary standalone server otherwise.
codex_start_thread() {
  codex_connection "$3" codex_create_thread "$1" "$2"
}

codex_create_thread() {
  local dir="$1" name="$2" response thread_id
  response=$(request 1 thread/start "$(jq -nc --arg cwd "$dir" \
    '{cwd:$cwd,permissions:":workspace",approvalPolicy:"on-request",approvalsReviewer:"auto_review",threadSource:"cli"}')") || return 1
  thread_id=$(jq -er '.result.thread.id' <<<"$response") || return 1
  request 2 thread/name/set "$(jq -nc --arg id "$thread_id" --arg name "$name" \
    '{threadId:$id,name:$name}')" >/dev/null || return 1
  # 0.159.1 saves empty threads lazily. Archive/unarchive materializes this
  # new thread without a model turn, so resume can read its saved history.
  local thread_params
  thread_params=$(jq -nc --arg id "$thread_id" '{threadId:$id}')
  request 3 thread/archive "$thread_params" >/dev/null || return 1
  request 4 thread/unarchive "$thread_params" >/dev/null || return 1
  # Empty threads have no saved turn context. Unarchive unloads the thread,
  # so restore permissions explicitly before the remote TUI's ID-only resume.
  request 5 thread/resume "$(jq -nc --arg id "$thread_id" --arg cwd "$dir" \
    '{threadId:$id,cwd:$cwd,permissions:":workspace",approvalPolicy:"on-request",approvalsReviewer:"auto_review"}')" >/dev/null || return 1
  printf '%s\n' "$thread_id"
}

# role_prompt echoes the opening briefing for a role, or nothing. It names the
# skill file explicitly, so the load is deterministic instead of depending on a
# description matching.
role_prompt() {
  local repo="$1" dir="$2"
  local skill=".agents/skills/$ROLE/SKILL.md" ready

  if [[ ! -f "$dir/$skill" ]]; then
    echo "warning: $repo has no $skill — starting the agent unbriefed" >&2
    return 0
  fi

  # The gate's verdict travels in the prompt rather than blocking creation: an
  # agent that says "main is 65 behind, fix me" beats a missing one.
  if ! ready=$(git-ready "$dir" 2>&1); then
    ready="FAILED — $ready"
  fi

  echo "You are the $ROLE agent for $repo on $(hostname -s).
Read $skill in this repo now and follow it.
git-ready: $ready
Change nothing until I say so. First report what a run would do, and anything
already broken."
}

# agent_argv echoes, NUL separated, the command line for one agent.
agent_argv() {
  local agent="$1" dir="$2" repo="$3" branch="$4"
  local prompt="" argv=() name
  [[ -z "$ROLE" ]] || prompt=$(role_prompt "$repo" "$dir")
  name="$(hostname -s)-$(slug "$(display "$repo" "$branch")")"

  # For claude: auto mode (a classifier gates risky tool calls), pre-trust the
  # dir (a separate gate, pinned explicitly so it survives claude behaviour
  # drift), and Remote Control named <host>-<repo>-<job> so the agent is also
  # reachable from claude.ai / the phone. kradalby-llm cannot reach the
  # Remote Control service, so omit that flag there. AC_TRUST=0 /
  # AC_REMOTE_CONTROL=0 opt out respectively.
  if [[ "$agent" == "claude" ]]; then
    ensure_trusted "$dir"
    # Prompt first: --remote-control takes an optional value and would eat it.
    [[ -z "$prompt" ]] || argv+=("$prompt")
    argv+=(--permission-mode auto)
    if claude_remote_control_enabled "$(hostname -s)"; then
      argv+=(--remote-control "$name")
    fi
  elif [[ "$agent" == "codex" ]]; then
    ensure_trusted_codex "$dir"
    local codex_remote=""
    if [[ "$(hostname -s)" == "dev" && "${AC_REMOTE_CONTROL:-1}" == "1" ]]; then
      codex_remote="${AC_CODEX_REMOTE:-}"
      if [[ -z "$codex_remote" && -S "${CODEX_HOME:-$HOME/.codex}/app-server-control/app-server-control.sock" ]]; then
        codex_remote="unix://"
      fi
    fi
    if [[ -n "$codex_remote" ]]; then
      # Pin the shared server so rex and the phone see the same thread.
      # Remote resume preserves the thread's permission profile and rejects
      # permission flags. --cd keeps the server's cwd out of this thread.
      argv+=(--remote "$codex_remote" --cd "$dir")
    else
      argv+=(--approve-for-me --no-daemon)
    fi
    local thread_id
    thread_id=$(codex_start_thread "$dir" "$name" "$codex_remote") || return 1
    argv+=(resume "$thread_id")
    [[ -z "$prompt" ]] || argv+=("$prompt")
  elif [[ "$agent" == "opencode" ]]; then
    [[ -z "$prompt" ]] || argv+=(--prompt "$prompt")
  fi

  # Rex runs commands in the login environment, which never reaches the
  # interactive direnv hook, so load the repo's dev env explicitly.
  local cmd=("$agent" "${argv[@]}")
  [[ ! -f "$dir/.envrc" ]] || cmd=(direnv exec "$dir" "${cmd[@]}")
  printf '%s\0' "${cmd[@]}"
}

# ensure_job opens a tab for every agent of a job that has none yet, and leaves
# running tabs alone. Echoes the first agent's "session_id<TAB>window_id".
ensure_job() {
  local dir="$1" repo="$2" branch="$3"
  shift 3
  local agent row sid wid bid tab session first="" cmd=() created
  session="${SESSION:-$repo}"

  for agent in "$@"; do
    row=$(find_tab "$repo" "$branch" "$agent")
    if [[ -n "$row" ]]; then
      IFS=$'\t' read -r sid _ wid _ _ <<<"$row"
    else
      if ! mapfile -d '' -t cmd < <(agent_argv "$agent" "$dir" "$repo" "$branch") || [[ ${#cmd[@]} -eq 0 ]]; then
        echo "warning: could not prepare $agent for $(display "$repo" "$branch")" >&2
        continue
      fi
      tab=$(tab_name "$branch" "$agent")
      sid=$(session_id "$session")
      # --focus=false so a headless spawn doesn't move a viewer's tab.
      if [[ -n "$sid" ]]; then
        created=$(rex window new -s "$sid" "$tab" -c "$dir" --focus=false --json -- "${cmd[@]}") || {
          echo "warning: $tab tab not created in $session" >&2
          continue
        }
        wid=$(jq -r '.window_id' <<<"$created")
        bid=$(jq -r '.block_ids[0]' <<<"$created")
      else
        created=$(rex new "$session" -c "$dir" --window "$tab" --json -- "${cmd[@]}") ||
          die "rex new $session failed"
        sid=$(jq -r '.session_id' <<<"$created")
        wid=$(jq -r '.initial_windows[0].window_id' <<<"$created")
        bid=$(jq -r '.initial_windows[0].block_ids[0]' <<<"$created")
      fi
      rex block rename -s "$sid" "$bid" "$(tab_meta "$repo" "$branch" "$agent")" >/dev/null ||
        echo "warning: could not tag $tab; ac will not find it again" >&2
    fi
    [[ -n "$first" ]] || first="$sid"$'\t'"$wid"
  done
  echo "$first"
}

cmd_create_or_attach() {
  local repo="$1" branch="${2:-}"
  shift 2

  # A role plus a branch would be two different jobs sharing one name.
  [[ -z "$ROLE" || -z "$branch" ]] || die "--role takes no branch"

  local dir
  if [[ -n "$branch" ]]; then
    # Resolve to an existing worktree (creating on confirmation if none).
    dir=$(ensure_worktree "$repo" "$branch" interactive) || return 1
  else
    dir=$(find_main_worktree "$repo")
  fi

  local target sid wid
  target=$(ensure_job "$dir" "$repo" "$branch" "$@")
  [[ -n "$target" ]] || die "no agent started for $(display "$repo" "$branch")"
  IFS=$'\t' read -r sid wid <<<"$target"

  # Rex has no terminal attach: focus the tab and ask the Rex app to show it.
  # With several apps connected, REX_CLIENT picks one.
  rex focus -s "$sid" "$wid" >/dev/null 2>&1 || true
  if rex "do" session.select session_id="$sid" window_id="$wid" >/dev/null 2>&1; then
    echo "switched to $(display "$repo" "$branch")"
  else
    echo "$(display "$repo" "$branch") ready; open it in Rex"
  fi
}

cmd_spawn() {
  # Headless create: like cmd_create_or_attach but never prompts and never
  # attaches. Used by ac-web and the standing-agent unit.
  local repo="$1" branch="${2:-}"
  shift 2

  local dir
  if [[ -n "$branch" ]]; then
    dir=$(ensure_worktree "$repo" "$branch") || return 1
  else
    dir=$(find_main_worktree "$repo")
  fi

  ensure_job "$dir" "$repo" "$branch" "$@" >/dev/null
  echo "ensured: $(display "$repo" "$branch")"
}

cmd_permagent() {
  local action="$1" repo="$2" role="$3"
  shift 3
  [[ "$action" == "ensure" ]] || die "usage: ac permagent ensure <repo> <role>"
  ROLE="$role"
  ensure_job "$(find_main_worktree "$repo")" "$repo" "" "$@" >/dev/null
  echo "ensured: $(display "$repo" "")"
}

cmd_list_porcelain() {
  # Machine-readable listing for ac-web. One ac tab per line, tab separated:
  # handle<TAB>repo<TAB>branch<TAB>agent<TAB>attached(0|1)<TAB>workdir.
  # The handle is the window ID without its "window:" prefix, which ac-web
  # hands back to `ac rm`. Main and roles read "repo:main" / "repo:deploy".
  # shortcut: attached is always 0, since rex does not say which tab an app
  # shows; read it from the client API if rex ever exposes that.
  local sid wid bid meta repo branch role agent workdir
  while IFS=$'\t' read -r sid _ wid bid meta; do
    IFS='|' read -r _ repo branch role agent <<<"$meta"
    if [[ -n "$role" ]]; then
      repo="$repo:$role"
    elif [[ -z "$branch" ]]; then
      repo="$repo:main"
    fi
    workdir=$(rex --autostart=false block call -s "$sid" -b "$bid" process 2>/dev/null | jq -r '.child.cwd // ""')
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${wid#window:}" "$repo" "$branch" "$agent" 0 "$workdir"
  done < <(ac_tabs)
}

cmd_list_human() {
  local sid label wid meta repo branch role agent rows=""
  while IFS=$'\t' read -r sid label wid _ meta; do
    IFS='|' read -r _ repo branch role agent <<<"$meta"
    ROLE="$role"
    rows+="$label"$'\t'"$(rex --autostart=false window ls -s "$sid" --json 2>/dev/null |
      jq -r --arg w "$wid" '.windows[] | select(.window_id == $w) | .label')"$'\t'"$(display "$repo" "$branch")"$'\t'"$agent"$'\n'
  done < <(ac_tabs)
  if [[ -z "$rows" ]]; then
    echo "no agent tabs"
    return 0
  fi
  { printf 'SESSION\tTAB\tJOB\tAGENT\n%s' "$rows"; } | column -t -s $'\t'
}

# matching_tabs prints the ac_tabs rows a target names: a handle from the
# porcelain listing, or a job ("repo:role", "repo:main", "repo/branch").
matching_tabs() {
  local target="$1" repo="" branch="" role=""
  if [[ "$target" == */* ]]; then
    repo="${target%%/*}" branch="${target#*/}"
  elif [[ "$target" == *:* ]]; then
    repo="${target%%:*}" role="${target#*:}"
    [[ "$role" != "main" ]] || role=""
  fi
  ac_tabs | awk -F'\t' -v h="window:$target" -v r="$repo" -v b="$branch" -v o="$role" '
    $3 == h { print; next }
    r != "" { split($5, m, "|"); if (m[2] == r && m[3] == b && m[4] == o) print }'
}

cmd_remove() {
  local rows
  rows=$(matching_tabs "$1")
  [[ -n "$rows" ]] || die "no ac tab found: $1"

  # Stop the agents gracefully before closing their tabs: SIGTERM lets
  # `claude remote-control` deregister cleanly (a forced kill orphaned it and
  # filled the claude.ai picker with dead duplicates). Signal every agent,
  # then wait once — they exit in parallel. `|| true`: goal state is a closed
  # tab; an agent that already exited must not abort us.
  local sid wid bid pid pids=()
  while IFS=$'\t' read -r sid _ wid bid _; do
    pid=$(rex block call -s "$sid" -b "$bid" process 2>/dev/null |
      jq -r '.foreground.pid // .child.pid // empty')
    [[ -n "$pid" ]] || continue
    kill -TERM "$pid" 2>/dev/null || true
    pids+=("$pid")
  done <<<"$rows"

  # ~10s grace for the agents to deregister and exit
  for _ in $(seq 1 20); do
    local alive=0
    for pid in ${pids[@]+"${pids[@]}"}; do
      kill -0 "$pid" 2>/dev/null && alive=1
    done
    [[ "$alive" == 1 ]] || break
    sleep 0.5
  done

  # Only ac's tabs close; the user's tabs stay. A session left with no tabs
  # would only clutter the app, so it goes too.
  while IFS=$'\t' read -r sid _ wid _ _; do
    rex window close -s "$sid" "$wid" >/dev/null 2>&1 || true
    echo "closed: ${wid#window:}"
    [[ -n "$(rex window ls -s "$sid" -q 2>/dev/null)" ]] || rex kill "$sid" >/dev/null 2>&1 || true
  done <<<"$rows"
}

cmd_selftest() {
  local fails=0
  check() {
    if [[ "$2" == "$3" ]]; then
      echo "ok   $1 -> '$2'"
    else
      echo "FAIL $1 -> '$2', want '$3'" >&2
      fails=$((fails + 1))
    fi
  }

  check "tab main" "$(tab_name "" claude)" "main"
  check "tab branch" "$(tab_name "kradalby/fix dns" claude)" "kradalby-fix-dns"
  check "tab codex" "$(tab_name "" codex)" "main-cx"
  check "tab role" "$(ROLE=deploy tab_name "" claude)" "deploy"
  check "tab override" "$(TAB=infra tab_name "" claude)" "infra"
  check "meta role" "$(ROLE=deploy tab_meta dotfiles "" claude)" "ac|dotfiles||deploy|claude"

  if AC_REMOTE_CONTROL=1 claude_remote_control_enabled kradalby-llm; then
    echo "FAIL remote control enabled on kradalby-llm" >&2
    fails=$((fails + 1))
  elif ! AC_REMOTE_CONTROL=1 claude_remote_control_enabled workstation; then
    echo "FAIL remote control disabled on another host" >&2
    fails=$((fails + 1))
  elif AC_REMOTE_CONTROL=0 claude_remote_control_enabled workstation; then
    echo "FAIL AC_REMOTE_CONTROL=0 ignored" >&2
    fails=$((fails + 1))
  else
    echo "ok   remote control host policy"
  fi

  [[ "$fails" -eq 0 ]] || die "$fails case(s) failed"
  echo "selftest passed"
}

cmd_help() {
  cat <<'EOF2'
Usage: ac [flags] [command|repo] [branch]

Agent code tab manager. A job — a repo's main checkout, a role, or a branch —
is one rex tab per agent, inside the rex session named after the repo (or -s).
Claude only, unless -c/-x/-o ask for others. ac tags its panes, so it finds
its tabs wherever they are and never opens one twice; your own tabs and
sessions are left alone.

Commands:
  <repo> [branch]        Open the job's tab if missing, then focus it and ask
                         the Rex app to show it
  ls                     List ac tabs (also: no arguments)
  ls --porcelain         Tab-separated listing (for ac-web)
  spawn <repo> [branch]  Open the job's tab without showing it
  rm <handle|job>        Gracefully stop the agents and close their tabs.
                         A job is "repo:main", "repo:<role>" or "repo/branch"
  permagent ensure <repo> <role>
                         Ensure the role's tab exists
  selftest               Check tab naming
  help                   Show this help

Flags:
  -c, --claude           Claude (the default)
  -x, --codex            Codex; with -c, both
  -o, --opencode         opencode
  -r, --role <name>      The repo's long-lived <name> job (see "Roles")
  -s, --session <name>   Rex session to open tabs in (default: the repo)
  -t, --tab <name>       Tab name (default: role, branch, or "main")

Tabs are named after the job: "main", the role ("deploy"), or the branch with
'/' as '-'. Codex and opencode tabs get "-cx" / "-oc" appended.

Roles:
  `ac -r deploy dotfiles` opens a durable agent pinned to a repo and a job.
  It always uses the repo's main worktree and is briefed at launch from
  <repo>/.agents/skills/<role>/SKILL.md — the Agent Skills path Codex and
  OpenCode already discover. The briefing carries the `git-ready` verdict, so
  the agent knows the repo's state before it does anything. A failing verdict
  does not block the agent: the deploy commands are gated themselves.

If the branch worktree does not exist, you will be prompted to create it. An
existing branch is checked out as-is; a new branch is based on the appropriate
remote:
  - Repos with an 'upstream' remote: fetches upstream, branches from
    upstream/main (e.g., headscale forks)
  - All other repos: fetches origin, branches from origin's default branch

The main repo lives at ~/git/<repo>; branch worktrees are created under
$WT_ROOT/<repo>/<branch> (default WT_ROOT: ~/worktrees).

Examples:
  ac headscale                   tab "main" in session "headscale"
  ac headscale kradalby/3049     tab "kradalby-3049" on that worktree
  ac -c -x sfiber planet-olt     tabs "planet-olt" and "planet-olt-cx"
  ac -r deploy sfiber            tab "deploy" in session "sfiber"
  ac -s dotfiles -t infra infrastructure
                                 tab "infra" in session "dotfiles"
  ac rm sfiber:deploy            close that tab

claude launches in auto mode (--permission-mode auto) and, except on
kradalby-llm, with Remote Control named <host>-<repo>-<job>, so it is reachable
from claude.ai / the phone (AC_REMOTE_CONTROL=0 disables). The working dir is
pre-trusted so no trust prompt blocks the agent (AC_TRUST=0 disables). Agents
run in the repo's direnv environment when it has an .envrc.
Codex uses Approve for me: the :workspace profile, with escalations sent to
auto review. Threads are created and named <host>-<repo>-<job> before the tab
opens, then attached with codex resume. On dev.ldn they connect to the shared
app server when its Unix socket exists, so remote clients see the same
threads. AC_CODEX_REMOTE overrides dev's endpoint; AC_REMOTE_CONTROL=0 runs
standalone.
EOF2
}

# --- main ---

main() {
  # Empty until a flag names one: an explicit -c/-o/-x means "just these",
  # while no flag means DEFAULT_AGENTS.
  local agents=()
  local porcelain=0
  local args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o | --opencode)
        agents+=(opencode)
        shift
        ;;
      -c | --claude)
        agents+=(claude)
        shift
        ;;
      -x | --codex)
        agents+=(codex)
        shift
        ;;
      -r | --role | -s | --session | -t | --tab)
        [[ $# -ge 2 ]] || die "$1 needs a name"
        case "$1" in
          -r | --role) ROLE="$2" ;;
          -s | --session) SESSION="$2" ;;
          *) TAB="$2" ;;
        esac
        shift 2
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

  if [[ ${#agents[@]} -eq 0 ]]; then
    agents=("${DEFAULT_AGENTS[@]}")
  fi

  if [[ ${#args[@]} -eq 0 ]]; then
    cmd_list_human
    return 0
  fi

  local first="${args[0]}"

  case "$first" in
    ls | list)
      if [[ "$porcelain" == 1 ]]; then
        cmd_list_porcelain
      else
        cmd_list_human
      fi
      ;;
    spawn)
      [[ ${#args[@]} -ge 2 ]] || die "usage: ac spawn <repo> [branch]"
      cmd_spawn "${args[1]}" "${args[2]:-}" "${agents[@]}"
      ;;
    permagent)
      [[ ${#args[@]} -ge 4 ]] || die "usage: ac permagent ensure <repo> <role>"
      cmd_permagent "${args[1]}" "${args[2]}" "${args[3]}" "${agents[@]}"
      ;;
    rm | remove | kill)
      [[ ${#args[@]} -ge 2 ]] || die "usage: ac rm <handle|job>"
      cmd_remove "${args[1]}"
      ;;
    selftest)
      cmd_selftest
      ;;
    help)
      cmd_help
      ;;
    *)
      cmd_create_or_attach "$first" "${args[1]:-}" "${agents[@]}"
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
