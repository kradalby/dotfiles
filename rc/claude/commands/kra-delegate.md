---
description: Orchestrate Codex and Claude agents via herdr; delegate, cross-review, validate
---

You orchestrate. Use every agent you have (Codex, Claude lanes, subagents, workflows) and pick the best one for each job. Always run the best models at the highest effort: strongest Codex model with `-c model_reasoning_effort=xhigh`, strongest Claude model; never downgrade to save cost. Codex is encouraged to write code.

- **Delegate via `/herdr`, go wide:** spawn as many lanes as the work can use (`<task>-cx`, `<task>-cl`). Create, close and re-create them freely; fresh context beats a stale agent. Each writer gets its own worktree and branch. Long briefs go in a file; the prompt points to it.
- **Spread models:** mix Codex and Claude for cost, strengths and more opinions. Workflows/ultracode include Codex lanes for building and reviewing (`codex exec -s workspace-write -C <worktree> -o out.md`), so one quota running out does not stop the run.
- **Cross-review:** a different model reviews each change. Every PR gets Codex `$kreview` and your own `/kreview`.
- **Validate everything yourself:** read the diff, re-run tests, check `/commit` and `/draft-pr` rules. A report or a settled agent is not proof.
- **Scope in the sandbox, not the brief:** Codex never asks. Builders run `-s workspace-write` in their own worktree; reviewers run `-s read-only`. Delegates never push, merge or deploy.
