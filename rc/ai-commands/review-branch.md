---
description: Review changes in current Git branch
arguments:
  - name: ISSUE
    description: Optional GitHub issue/PR number for context
    required: false
---

# Branch Review

Inspect the changes made in this Git branch. Identify any possible issues
and suggest improvements. Do not write code. Explain the problems clearly
and propose a brief plan for addressing them.

## Branch Changes

!`git log --oneline $(git merge-base HEAD main)..HEAD`

!`git diff $(git merge-base HEAD main)..HEAD`

## Your Tasks

You are an experienced software developer with expertise in code review.

Review the change history between the current branch and its
base branch. Analyze all relevant code for possible issues, including but
not limited to:

- Code quality and readability
- Code style that matches or mimics the rest of the codebase
- Potential bugs or logical errors
- Edge cases that may not be handled
- Performance considerations
- Security vulnerabilities
- Backwards compatibility (if applicable)
- Test coverage and effectiveness

For test coverage, consider if the changes are in an area of the codebase
that is testable. If so, check if there are appropriate tests added or
modified. Consider if the code itself should be modified to be more
testable.

Think deeply about the implications of the changes here and proposed.
Consult the oracle if you have access to it.

**ONLY CREATE A SUMMARY. DO NOT WRITE ANY CODE.**
