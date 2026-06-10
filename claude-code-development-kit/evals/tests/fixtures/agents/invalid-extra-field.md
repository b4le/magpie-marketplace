---
name: invalid-extra-field
description: Agent with an unknown field that should be rejected by additionalProperties false
tools:
  - Read
  - Grep
customSetting: true
---

This agent has an unknown field that should fail validation.
