---
name: status
description: Show current active mode and style state
---

# Mode Status

Display the current interaction mode and recent style usage.

## Response Format

```
**Current mode:** [creative/challenger/teaching/none]
**Active since:** [X exchanges ago / not active]

**Recent generations:**
- [list of /gen: commands used this session, if any]

**Quick commands:**
- `/mode:creative` — brainstorming
- `/mode:challenger` — stress-test
- `/mode:teaching` — explain with why
- `/mode:exit` — return to default
```

## If No Mode Active

```
**Current mode:** none (default)

Responding with context-aware defaults. Use `/mode:` to enter a persistent mode.
```