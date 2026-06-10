# Unicode Library

Curated, tested library of Unicode characters for CLI visual design. Reference standard for any agent creating skills, commands, agents, or branded terminal output in Claude Code.

## Contents

- `skills/unicode-library/SKILL.md` -- Main skill (triggered when agents create visual output)
- `skills/unicode-library/references/registry.md` -- Character registry (~70 approved characters)
- `skills/unicode-library/references/palettes.md` -- Semantic palettes for common patterns
- `skills/unicode-library/references/anti-patterns.md` -- Characters that MUST be avoided
- `skills/unicode-library/references/integration.md` -- How to use from other skills

## Design Principles

1. **Copy-paste safety is non-negotiable** -- if it looks like a functional operator when pasted, it's out
2. **Prescriptive, not encyclopaedic** -- ~70 curated characters, not every Unicode symbol
3. **One character, one role** -- every character has a single primary semantic meaning
4. **Tested, not assumed** -- all characters verified against clipboard, shell, JSON, and terminal rendering
5. **Width-aware** -- ambiguous-width characters flagged per-character, not per-block

## Quick Start

Reference this library from any skill's branding or output template:

```yaml
# In your skill's branding.md or output instructions:
# Reference: unicode-library/references/registry.md for approved characters
# Reference: unicode-library/references/palettes.md for pre-composed sets
```
