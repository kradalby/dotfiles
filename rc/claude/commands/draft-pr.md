---
description: Create a draft PR
---

Create a draft pull request for the current branch.

- Push all commits to origin first
- Follow golang commit style for the PR title (https://go.dev/wiki/CommitMessage)
  - The title should read like a commit subject line
- Write a concise PR description summarising the changes
  - Focus on the "why", not the "what"
  - Be short, terse, concise and lean into brevity
    - Cut every word that does not carry meaning
    - Prefer fragments over full sentences when the meaning is clear
    - No filler, no hedging, no restating the diff
  - Use proper markdown: backticks for code and identifiers, paragraphs separated by blank lines, lists where genuinely parallel
  - No section headings (`## Summary`, `## Test plan`, etc.) and no checklists
  - Prefer short paragraphs over bullet-heavy dumps
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
