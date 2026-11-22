---
description: Run independent kreviews across Claude and OpenAI models and return one review
argument-hint: "[N agents] [for 2 hours] [review scope]"
---

Use `$ARGUMENTS` for scope, reviewer count, and duration. Route by the calling model:

| Caller | Upper right pane | Lower right pane | Native subagent                             |
| ------ | ---------------- | ---------------- | ------------------------------------------- |
| Claude | Astra            | Sol              | Opus if calling from Fable, otherwise Fable |
| OpenAI | Fable            | Opus             | Sol if calling from Astra, otherwise Astra  |

Resolve the latest available version of each family at launch. Give every reviewer at least high effort. Match higher caller effort where supported. Run Claude models in Claude Code. Launch Sol in Codex. For Astra's pane, prefer `opencode mini -m <provider/model>`. Fall back to Codex if Mini cannot run the selected Astra at the required effort.

Use `/rex` in the caller's worktree. Run `rex split` with `-s "$REX_SESSION" -b "$REX_BLOCK" --split=right -c "$PWD" --focus=false --json`. Take the new pane's `.block_ids[0]` as the anchor for `--split=below`. Start one reviewer in each pane and the same-vendor sibling through native fan-out.

Give each reviewer the same diff and scope. Ask for a full, read-only `/kreview` (`$kreview` in Codex) and a report back. With `N agents`, count the two pane reviewers and the sibling toward N. Divide the remaining slots among them before launch so nested `kreview` fan-out stays within budget. Give extra reviewers distinct angles on the full diff.

For a timed review, give everyone the same wall-clock deadline. Until then, track angles already covered and send finished reviewers back through `kreview` with fresh questions. Collect both pane reports by block ID and the subagent results. Verify findings against the diff, merge duplicates, and report any missing coverage.
