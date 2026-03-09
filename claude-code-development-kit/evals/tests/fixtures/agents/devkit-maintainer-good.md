---
name: devkit-maintainer-good
description: |
  Maintenance and validation specialist for the claude-code-development-kit
  and supporting ~/.claude/ infrastructure. Use this agent when the user asks
  to "audit the dev-kit", "sync schemas with changelog", "validate plugin
  structure", "check for drift", "run maintenance", "update schemas",
  "cleanup setup", or needs to ensure devkit accuracy and consistency.

  <example>
  Context: User wants to check if devkit schemas are current
  user: "Are our schemas up to date with the latest Claude Code features?"
  assistant: "I'll use the devkit-maintainer agent to sync schemas against the changelog."
  <commentary>Schema drift detection triggers the agent.</commentary>
  </example>

  <example>
  Context: User adds a new component to the kit
  user: "I've added a new skill, run maintenance"
  assistant: "I'll use the devkit-maintainer agent to validate the new skill and check cross-references."
  <commentary>Post-change validation triggers the agent.</commentary>
  </example>

  <example>
  Context: User wants a full health check
  user: "Run a full devkit audit"
  assistant: "I'll use the devkit-maintainer agent to run validators, check drift, and audit the setup."
  <commentary>Full maintenance pass triggers all agent modes.</commentary>
  </example>
model: sonnet
model_rationale: Maintenance is procedural and well-defined — sonnet balances validation speed with reasoning for drift detection and conflict resolution. Opus unnecessary for structured checks.
color: yellow
tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - WebFetch
  - WebSearch
permissionMode: acceptEdits
maxTurns: 40
user-invocable: true
version: 1.0.0
---

<!-- TEST FIXTURE: Frontmatter must stay in sync with agents/devkit-maintainer.md.
     Body is intentionally minimal — validators only check frontmatter fields. -->

# devkit-maintainer-good

Minimal fixture body for agent frontmatter validation tests.
