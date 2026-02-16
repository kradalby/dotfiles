---
description: Diagnose and plan resolution for a GitHub issue
arguments:
  - name: ISSUE
    description: GitHub issue number or URL
    required: true
---

Deep-dive on this GitHub issue. Find the problem and generate a plan.
Do not write code. Explain the problem clearly and propose a comprehensive plan
to solve it.

# Issue Details

!`gh issue view $ISSUE --json author,title,number,body,comments`

## Your Tasks

You are an experienced software developer tasked with diagnosing issues.

1. Review the issue context and details.
2. Examine the relevant parts of the codebase. Analyze the code thoroughly
   until you have a solid understanding of how it works.
3. Explain the issue in detail, including the problem and its root cause.
4. Create a comprehensive plan to solve the issue. The plan should include:
   - Required code changes
   - Potential impacts on other parts of the system
   - Necessary tests to be written or updated
   - Documentation updates
   - Performance considerations
   - Security implications
   - Backwards compatibility (if applicable)
   - Include the reference link to the source issue and any related discussions
5. Think deeply about all aspects of the task. Consider edge cases, potential
   challenges, and best practices for addressing the issue. Review the plan
   with the oracle and adjust it based on its feedback.

**ONLY CREATE A PLAN. DO NOT WRITE ANY CODE.** Your task is to create
a thorough, comprehensive strategy for understanding and resolving the issue.
