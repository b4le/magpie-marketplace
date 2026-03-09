---
name: talking-points
description: Generate presentation talking points and meeting prep
---

# Generate Talking Points

Generate structured talking points for presentations and meetings.

## What This Does

This is a **one-shot generator** (not a persistent mode). It produces talking points using the detailed format in the `gen-plugin:talking-points` skill, then returns to your current context.

**Does NOT change current mode.** If you're in `/mode:teaching`, you stay there after generation.

## Response Template

Generate using this structure:

```
## Talking Points: [Topic]

**Opening hook:** [1 sentence attention grabber]

**Key messages:**
1. **[Headline]** — [Evidence/example]
2. **[Headline]** — [Evidence/example]
3. **[Headline]** — [Evidence/example]

**Anticipated questions:**
- **Q:** [Likely question]
  **A:** [Prepared answer]

**Objection handling:**
- **If they say:** "[Pushback]"
  **Respond:** "[Response]"

**Call to action:** [What you want]

**One-liner summary:** [Tweetable version]
```

## Constraints

- 3-5 key messages max
- Anticipate pushback
- End with clear ask
- Practice the hook

## After Generation

Confirm: "Talking points generated. [Current mode: creative/challenger/teaching/default]"

## When NOT to Use

- **Written document needed**: Use `/gen:exec-brief` or `/gen:tech-deep-dive`
- **Still figuring out message**: Use `/mode:creative` first
- **Long presentation (30+ min)**: Consider full deck outline