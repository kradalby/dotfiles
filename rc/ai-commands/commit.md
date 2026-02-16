---
description: Commit current work with Go-style messages
---

commit the current work

- Group it into logical chunks
  - Focus on making code easily reviewable, with an easy story to follow
- Follow golang commit style (https://go.dev/wiki/CommitMessage)
- Never commit plan documents
- Commit generated files in separate commits
- When working on a GitHub issue, tag every commit message with it:
  - Updates #1234 if not fixed, but related
  - Fixes #1234 if fixed
  - Look in your context or branch name for relevant commits. You can have more than one.
- Never use co-authored-by or generated
- Rebase/amend where appropriate
  - Evaluate using `git absorb --and-rebase`
- Do not push without permission
- NEVER use --no-verify, pre-commit hooks are mandatory
- NEVER use SKIP to skip a hook
