---
description: Diagnose and plan resolution for a GitHub issue
argument-hint: "<issue-number>"
---

Deep-dive on this GitHub issue. Find the problem and generate a plan.
Do not write code. Explain the problem clearly and propose a comprehensive plan
to solve it.

Name this Claude session descriptively (e.g. `gh-<issue-number>-<short-description>`).

# Issue Details

!`gh issue view "$ARGUMENTS" --json author,title,number,body,comments`

## Your Tasks

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
5. Create a comprehensive plan to solve the issue. The plan MUST fix the
   root cause, not just mask the symptom. If a symptom-level workaround
   is proposed, justify why the root cause cannot or should not be fixed
   now. The plan should include:
   - Required code changes
   - Potential impacts on other parts of the system
   - Necessary tests to be written or updated
   - Documentation updates
   - Performance considerations
   - Security implications
   - Backwards compatibility (if applicable)
   - Include the reference link to the source issue and any related discussions
6. Think deeply about all aspects of the task. Consider edge cases, potential
   challenges, and best practices for addressing the issue. Review the plan
   with the oracle and adjust it based on its feedback.

**ONLY CREATE A PLAN. DO NOT WRITE ANY CODE.** Your task is to create
a thorough, comprehensive strategy for understanding and resolving the issue.
