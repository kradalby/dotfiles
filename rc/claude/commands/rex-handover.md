---
description: Hand work to a new claude or codex agent on a new worktree, in a new tab of this Rex session
argument-hint: <repo> <new-branch> [claude|codex] [task]
---

Fork work to a new agent on a new branch worktree, as a tab in your own Rex session. Args: `$ARGUMENTS`.

Harness: the one the user names. None named → your own.

## 1. Pick branch

Copy prefix pattern of recent branches (`<user>/<topic>`, bare `<topic>`):

```sh
git -C ~/git/<repo> for-each-ref --sort=-committerdate --count=15 --format='%(refname:lstrip=2)' refs/heads
```

Name must be new everywhere. Output non-empty → pick another:

```sh
git -C ~/git/<repo> fetch --all --quiet
git -C ~/git/<repo> for-each-ref --format='%(refname)' 'refs/heads/<branch>' 'refs/remotes/*/<branch>'
```

`<slug>` = `<repo>-<branch>`, `/` → `-`. Names the tab, brief file and Remote Control.

## 2. Worktree

Base: unrelated → `upstream/main` if remote `upstream` exists, else `origin/HEAD`. Related → `git rev-parse HEAD` in your worktree; only committed work carries over.

`wt` creates `~/worktrees/<repo>/<branch>`, allows direnv, prints the path:

```sh
dir=$(cd ~/git/<repo> && wt create <branch> <base>)
```

## 3. Launch

Brief = task from `$ARGUMENTS`. Related work: name parent branch and what it already does. Long brief → write `~/.cache/handover/<slug>.md`; brief says read it.

```sh
rex window new -s "$REX_SESSION" <slug> -c "$dir" --focus=false --json -- \
  direnv exec "$dir" <argv> "<brief>"
```

| Harness | argv                                                                                                            |
| ------- | --------------------------------------------------------------------------------------------------------------- |
| claude  | `claude --permission-mode auto --remote-control $(hostname -s)-<slug>`; no `--remote-control` on `kradalby-llm` |
| codex   | `codex --approve-for-me`                                                                                        |

Save `.block_ids[0]` and `.window_id`. `REX_SESSION` unset → load `/rex`.

## 4. Verify

```sh
rex capture -s "$REX_SESSION" -b <block> --trim | tail -40
```

Trust prompt → `rex send-key -s "$REX_SESSION" -b <block> enter`, capture again. Agent working on brief → report tab and block. Drive later: `rex send` + `rex send-key enter`; read with `rex capture`.

## 5. Close

Only tabs you opened: `rex window close -s "$REX_SESSION" <window_id>`. Worktree and branch stay.
