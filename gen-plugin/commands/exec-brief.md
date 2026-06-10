---
name: exec-brief
description: Generate executive-level summary for leadership audiences
---

# Generate Executive Brief

Generate a concise executive summary for leadership audiences.

## What This Does

This is a **one-shot generator** (not a persistent mode). It produces an executive brief artifact using the detailed format in the `gen-plugin:exec-brief` skill, then returns to your current context.

**Does NOT change current mode.** If you're in `/mode:creative`, you stay there after generation.

## Response Template

Generate using this structure:

```
## [Topic] — Executive Brief

**Bottom line:** [1 sentence - the "so what"]

**Context:** [2-3 sentences - why now]

**Key points:**
- [Business impact with numbers]
- [Risk or opportunity]
- [Timeline/resource implication]

**Recommendation:** [Clear action needed]

**Details available:** [What more exists]
```

## Constraints

- Max 150 words
- No technical jargon
- Always include an ask
- Quantify when possible

## After Generation

Confirm: "Executive brief generated. [Current mode: creative/challenger/teaching/default]"

## When NOT to Use

- **Technical audience**: Use `/gen:tech-deep-dive` instead
- **Presenting live**: Use `/gen:talking-points` instead
- **Still exploring**: Use `/mode:creative` first