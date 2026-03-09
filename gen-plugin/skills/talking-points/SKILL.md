---
name: talking-points
description: Generate presentation talking points and meeting prep. Use when preparing for stakeholder meetings, creating pitch notes, or structuring difficult conversations.
version: 1.0.0
created: 2026-02-24
last_updated: 2026-02-24
---

# Talking Points Generator

Generate structured talking points for presentations and meetings.

## When to Use

- Preparing for stakeholder presentations
- Creating pitch deck speaker notes
- Preparing for difficult conversations
- Structuring meeting agendas with key messages

## When NOT to Use

- **Written document needed**: Use `/gen:exec-brief` or `/gen:tech-deep-dive` — talking points are for speaking
- **Technical deep dive**: Use `/gen:tech-deep-dive` — talking points are high-level, not detailed
- **Just exploring ideas**: Use `/mode:creative` mode — talking points require clear message
- **Long presentation (30+ min)**: Consider creating full deck outline instead

## Output Format

**ALWAYS structure talking points like this:**

```
## Talking Points: [Topic]

**Opening hook:** [1 sentence to grab attention and set context]

**Key messages:**
1. **[Message headline]** — [Supporting evidence or example]
2. **[Message headline]** — [Supporting evidence or example]
3. **[Message headline]** — [Supporting evidence or example]

**Anticipated questions:**
- **Q:** [Likely question from audience]
  **A:** [Concise, prepared answer]

- **Q:** [Likely question from audience]
  **A:** [Concise, prepared answer]

**Objection handling:**
- **If they say:** "[Likely pushback]"
  **Respond:** "[How to address it]"

**Call to action:** [What you want from the audience]

**One-liner summary:** [Tweetable version for memory]
```

## Constraints

- **3-5 key messages max** — more is overwhelming
- **Anticipate pushback** — prepare for hard questions
- **End with clear ask** — what should the audience do?
- **Practice the hook** — first 30 seconds set the tone

## Example

```
## Talking Points: Q1 Platform Investment

**Opening hook:** We have a window to reduce operational costs by 30% — but we need to act this quarter.

**Key messages:**
1. **Platform debt is costing us $200K/month** — incident response, slow deploys, manual ops
2. **3-month investment pays back in 6 months** — concrete ROI, not speculative
3. **Low risk, high certainty** — proven patterns from industry leaders

**Anticipated questions:**
- **Q:** Can we do this incrementally?
  **A:** Yes, the plan phases work over 3 sprints with value at each checkpoint.

- **Q:** What if we delay until Q2?
  **A:** We lose $600K in operational costs and the team we need may not be available.

**Objection handling:**
- **If they say:** "We can't afford the headcount"
  **Respond:** "This is reallocation, not new headcount. We're trading ops burden for platform capability."

**Call to action:** Approve the Q1 platform sprint allocation.

**One-liner summary:** "Invest 3 months, save $200K/month forever."
```

## Related Skills

| Skill | When to Use Instead |
|-------|---------------------|
| `/gen:exec-brief` | Creating written summary for async reading |
| `/gen:tech-deep-dive` | Technical audience needs detailed analysis |
| `/mode:creative` mode | Still figuring out the message before structuring |

Part of the **gen-plugin** output style system.

## Version History

### v1.0.0 (2026-02-24)
- Initial release with talking points format
- Added "When NOT to Use" guidance
- Added related skills cross-references
