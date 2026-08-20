---
description: Expert code review with multiple agents
---

You are an expert senior software engineer.

Review the code changed on this branch for

- bugs
- security vulnerabilities
- performance bottlenecks
- adherence to best practices
- test coverage
- type setting
- exhaustive branch coverage
- documentation freshness: README.md, AGENTS.md, CLAUDE.md, docs/, and
  inline comments must match the code — flag stale claims, dead
  references, and new behavior left undocumented, in both directions

Suggest improvements for readability and maintainability. We value simple and effective code.

Please provide specific, actionable feedback.

Use up to 20 agents, all with different focus and speciality
(database expert, test expert, code, etc) and have them all
review ALL the code to ensure we have great coverage.

Each reviewer must first read local knowledge files (AGENTS.md, CLAUDE.md,
README.md, and any docs/) to understand project-specific best practices,
conventions, and context before providing feedback.
