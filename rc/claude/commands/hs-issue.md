---
description: Diagnose a headscale GitHub issue, create worktree, reproduce in test, and plan fix
argument-hint: "<issue-number>"
---

Diagnose a headscale GitHub issue, set up a development worktree,
reproduce the bug with a test, and create a fix plan.

# Issue Details

!`gh issue view $ARGUMENTS --repo juanfont/headscale --json author,title,number,body,comments,labels`

## Step 1: Create worktree

Set up a development worktree for this issue:

1. Fetch upstream: `git -C ~/git/headscale/main fetch upstream`
2. Derive a short description from the issue title (lowercase, hyphen-separated, 3-5 words max)
3. Create the worktree and branch:
   - Branch name: `kradalby/<issue-number>-<short-description>`
   - Worktree path: `~/git/headscale/kradalby/<issue-number>-<short-description>`
   - Command: `git -C ~/git/headscale/main worktree add ~/git/headscale/kradalby/<issue-number>-<short-description> -b kradalby/<issue-number>-<short-description> upstream/main`
4. Change into the new worktree directory and work from there

## Step 2: Diagnose

You are an experienced software developer tasked with diagnosing issues.

1. Review the issue context and details.
2. Examine the relevant parts of the codebase. Analyze the code thoroughly
   until you have a solid understanding of how it works.
3. **Root cause analysis (mandatory).** Do not stop at the first plausible
   explanation or the surface-level symptom. Trace the behaviour back to
   its true origin:
   - Ask "why" repeatedly until you hit a cause that, if changed, would
     actually prevent the bug — not merely hide it.
   - Distinguish symptoms (what the user observes) from proximate causes
     (the line that throws) from root causes (the design, invariant, or
     assumption that allowed the proximate cause to exist).
   - Consider whether the reported issue is one instance of a broader
     class of bugs. If so, identify the class.
   - Rule out alternative hypotheses with evidence from the code, tests,
     or issue history — do not guess.
   - If the root cause is unclear, say so explicitly rather than
     proposing a fix that only treats symptoms.
4. Explain the issue in detail: the observed symptom, the proximate
   cause, and the underlying root cause. Make the chain from root cause
   to symptom explicit.

## Step 3: Reproduce with a test

**MANDATORY**: Before planning any fix, reproduce the issue in a failing test.
Use the first test type that can demonstrate the bug:

1. **Unit test** (preferred) — when the bug is isolated to a single package
   and can be reproduced without a running server.
2. **Server test** — when a running headscale instance is needed but not
   multiple tailscale nodes.
3. **Integration test** — when multiple tailscale nodes or full network
   interaction is required. These live in `integration/`.

First type that works wins. The test MUST fail, confirming the bug exists.
Run it to verify the failure before proceeding.

The reproduction test should exercise the **root cause**, not merely the
surface symptom. If the only test you can write reproduces the symptom
but does not pin down the root cause, note that gap explicitly — the
fix plan must then include a test that locks the root-cause behaviour.

## Step 4: Plan the fix

Create a comprehensive plan to solve the issue. The plan MUST fix the
root cause identified in Step 2, not merely mask the symptom. If a
symptom-level workaround is proposed, justify explicitly why the root
cause cannot or should not be fixed now, and record what follow-up is
needed to address it later.

The plan should include:
  - Required code changes
  - Potential impacts on other parts of the system
  - Necessary tests to be written or updated (beyond the reproduction test)
  - Documentation updates
  - Performance considerations
  - Security implications
  - Backwards compatibility (if applicable)
  - Include the reference link to the source issue and any related discussions

Think deeply about all aspects of the task. Consider edge cases, potential
challenges, and best practices for addressing the issue.

**DO NOT WRITE THE FIX. Only create the reproduction test and the plan.**
