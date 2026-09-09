---
description: Create a draft PR
---

Create a draft pull request for the current branch.

- Push all commits to origin first
- Follow golang commit style for the PR title (https://go.dev/wiki/CommitMessage)
  - The title should read like a commit subject line
- Write the PR description
  - HARD LIMIT: three sentences. Five only if the change is genuinely subtle.
    A description longer than the title plus three lines is a bug, rewrite it.
  - Only the "why". The diff already says the "what", never restate it.
  - Cut every word that does not carry meaning. Fragments over sentences.
    No filler, no hedging, no summary of the changes.
  - Backticks for code and identifiers. Blank line between paragraphs.
  - No section headings (`## Summary`, `## Test plan`, etc.), no checklists,
    no bullet lists unless the items are genuinely parallel.
  - The whole body should read like this:

    ```
    `tailscaled` restarts sever colmena's own connection, so new units never
    start. Deploy with `apply boot` and reboot instead.

    Fixes #1234
    ```
  - When working on a GitHub issue, reference it:
    - Fixes #1234 if it resolves the issue
    - Updates #1234 if related but not a full fix
    - Look in your context or branch name for relevant issues. You can have more than one.
- For the headscale repo (kradalby/headscale):
  - Create the PR from `origin` (kradalby/headscale) to `upstream` (juanfont/headscale)
  - Use `gh pr create --repo juanfont/headscale --head kradalby:<branch>`
- Always create the PR as a draft (`--draft`)
- Always watch the PR checks until they all pass
- Add a model attribution line at the very end of the PR body:

  > Generated with the help of an AI assistant
