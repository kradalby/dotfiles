---
name: herdr
description: Control herdr panes, tabs, workspaces, and agents when the user explicitly asks to use herdr. Supports Codex running in a pane or on a shared server with a herdr frontend.
---

# Herdr

Use `herdr-codex` for every herdr command. It uses inherited pane context for a
local agent, or resolves `CODEX_THREAD_ID` against the live agent session IDs
reported by `ac`. It refuses missing or ambiguous matches. Never substitute the
focused pane, working directory, or conversation title for thread identity.

First verify the binding with this read-only command:

```bash
herdr-codex --context
```

If resolution fails, stop and explain that this thread has no unique live herdr
frontend. Sessions started before `ac` reported thread IDs need their identity
registered or a new session started with the updated `ac`.

Read [the upstream herdr instructions](reference.md) for CLI discovery, layout,
agent coordination, and safety. Its `HERDR_ENV` check describes local pane
execution; `herdr-codex` performs that context check for remote execution too.
Replace `herdr` with `herdr-codex` in its commands, including `--help`.

For commands that use caller variables such as `$HERDR_PANE_ID`, resolve and
export context in the same shell invocation:

```bash
context=$(herdr-codex --context) || exit 1
eval "$context"
herdr-codex pane current --current
```

Exports do not persist across tool calls. The wrapper resolves context each
time, including requests made from the phone. Use explicit targets or
`--current`, and preserve user focus with `--no-focus` for background work.
