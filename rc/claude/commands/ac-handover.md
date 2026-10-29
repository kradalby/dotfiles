---
description: Fork related or unrelated work to a new agent on a new worktree via ac, then drive it with /herdr
argument-hint: <repo> <new-branch> [-c|-x|-o] [task]
---

Fork work to a new agent on a new branch worktree with `ac`. Hand it over with `/herdr`. Args: `$ARGUMENTS`.

## 1. Pick branch

Match the repo's naming. Read recent local branches and copy their prefix pattern (e.g. `<user>/<topic>`, bare `<topic>`):

```sh
git -C ~/git/<repo> for-each-ref --sort=-committerdate --count=15 --format='%(refname:lstrip=2)' refs/heads
```

Name must be new everywhere:

```sh
git -C ~/git/<repo> fetch --all --quiet
git -C ~/git/<repo> for-each-ref --format='%(refname)' 'refs/heads/<branch>' 'refs/remotes/*/<branch>'
```

Output non-empty → pick another name. ac reuses an existing branch's checkout and live agent; that is not new.

## 2. Pick base

- Unrelated work: skip. ac bases on `upstream/main` if repo has `upstream` remote, else origin's default branch.
- Related work, builds on current branch: `git -C <current-worktree> branch <branch> HEAD` first. ac checks out that branch. Only committed work carries over.

## 3. Spawn

```sh
ac spawn [-c] [-x] [-o] <repo> <branch>
```

Always `spawn`. Bare `ac <repo> <branch>` prompts `[y/N]` and moves the user's view.

| Flag   | Harness        | Launch                                                                    |
| ------ | -------------- | ------------------------------------------------------------------------- |
| (none) | claude + codex | one tab each, plus `terminal`                                             |
| `-c`   | claude         | `--dangerously-skip-permissions`; Remote Control `<host>-<repo>-<branch>` |
| `-x`   | codex          | full access, approvals never; thread `<host>-<repo>-<branch>`             |
| `-o`   | opencode       |                                                                           |

Any flag replaces the default set; flags combine (`-c -o`). Unsure → default.

ac then:

- Creates worktree `~/worktrees/<repo>/<branch>` from `~/git/<repo>`.
- Allows direnv, warms dev env, pre-trusts dir for claude and codex.
- Brings up `<repo>:main` if missing; new session nests under it.
- Takes minutes (fetch + direnv). Set a long timeout.

`spawned: <repo>/<branch>` → done. `already running:` → branch not new; back to step 1. Any `warning:` → harness may sit at a shell; check with `herdr agent get`.

## 4. Find agent

Handle comes from `<repo>/<branch>`: lowercase, chars outside `[a-z0-9_-]` → `-`, max 32. One harness: bare. Several: base cut to 28 + `-cl` / `-cx` / `-oc`.

| Spawn                                    | Handles                                                          |
| ---------------------------------------- | ---------------------------------------------------------------- |
| `ac spawn -x headscale kradalby/fix-dns` | `headscale-kradalby-fix-dns`                                     |
| `ac spawn headscale kradalby/fix-dns`    | `headscale-kradalby-fix-dns-cl`, `headscale-kradalby-fix-dns-cx` |

Confirm, never guess:

```sh
herdr agent list | jq -r --arg d ~/worktrees/<repo>/<branch> \
  '.result.agents[] | select(.cwd == $d) | [.name, .agent, .agent_status] | @tsv'
```

ac uses herdr session `ac`. `$HERDR_SESSION` not `ac` → add `--session ac` to every herdr call.

## 5. Hand over

Load `/herdr`. Drive agent by handle from step 4:

```sh
herdr agent prompt <handle> "<task>" --wait --timeout 600000
herdr agent read <handle> --source recent-unwrapped --lines 120
```

Task from `$ARGUMENTS` if given. Related work: brief names the parent branch and what it already does. Long brief → write a file; prompt points to it.

`HERDR_ENV` not `1` → `/herdr` cannot run. Spawn, report handle, stop.

## 6. Close

`ac rm <repo>/<branch>` stops agents gracefully (Remote Control deregisters) and closes the workspace. Worktree and branch stay. Close only sessions you spawned.
