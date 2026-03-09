---
name: invalid-snake-case-field
description: Agent using snake_case field name instead of camelCase — should fail additionalProperties check
tools:
  - Read
  - Grep
max_turns: 10
---

This agent uses snake_case max_turns which should be rejected.
