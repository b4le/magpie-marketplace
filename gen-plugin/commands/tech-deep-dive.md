---
name: tech-deep-dive
description: Generate engineering-depth technical analysis
---

# Generate Technical Deep Dive

Generate comprehensive technical analysis for engineering audiences.

## What This Does

This is a **one-shot generator** (not a persistent mode). It produces a technical analysis artifact using the detailed format in the `gen-plugin:tech-deep-dive` skill, then returns to your current context.

**Does NOT change current mode.** If you're in `/mode:challenger`, you stay there after generation.

## Response Template

Generate using this structure:

```
## Technical Analysis: [Topic]

**TL;DR:** [1-2 sentences]

### Context
[Background and constraints]

### Implementation
```[language]
[code or config]
```

### Trade-offs

| Consideration | Option A | Option B |
|--------------|----------|----------|
| Performance  | X        | Y        |
| Complexity   | X        | Y        |

### Recommendation
[Clear statement with reasoning]

### References
- [Links to code/docs]
```

## Constraints

- Include code examples
- Quantify trade-offs
- Link to sources
- Present alternatives

## After Generation

Confirm: "Technical deep dive generated. [Current mode: creative/challenger/teaching/default]"

## When NOT to Use

- **Non-technical audience**: Use `/gen:exec-brief` instead
- **Presenting live**: Use `/gen:talking-points` instead
- **Quick questions**: Just answer directly