---
description: Create a draft PR
---

Create a draft pull request for the current branch.

- Push all commits to origin first
- Follow golang commit style for the PR title (https://go.dev/wiki/CommitMessage)
  - The title should read like a commit subject line
- Write a concise PR description summarising the changes
  - Focus on the "why", not the "what"
  - Plain text only, no markdown headings or sections (no ## Summary, ## Test plan, etc.)
  - No bullet lists, no checklists, just a short paragraph
  - When working on a GitHub issue, reference it:
    - Fixes #1234 if it resolves the issue
    - Updates #1234 if related but not a full fix
    - Look in your context or branch name for relevant issues. You can have more than one.
- For the headscale repo (kradalby/headscale):
  - Create the PR from `origin` (kradalby/headscale) to `upstream` (juanfont/headscale)
  - Use `gh pr create --repo juanfont/headscale --head kradalby:<branch>`
- Always create the PR as a draft (`--draft`)
- Add a model attribution line at the very end of the PR body:

  > Generated with the help of an AI assistant
