---
name: exec-brief
description: Generate executive-level summary for leadership audiences. Use when presenting to executives, summarizing for non-technical stakeholders, or creating decision memos.
version: 1.0.0
created: 2026-02-24
last_updated: 2026-02-24
---

# Executive Brief Generator

Generate concise executive summaries formatted for leadership decision-making.

## When to Use

- Summarizing technical work for non-technical stakeholders
- Preparing updates for leadership meetings
- Creating decision memos for executives
- Translating complex analysis into business impact

## When NOT to Use

- **Technical audience**: Use `/gen:tech-deep-dive` instead — engineers want implementation details
- **Exploration phase**: Use `/mode:creative` mode — briefs are for decisions, not ideation
- **Teaching context**: Use `/mode:teaching` mode — briefs assume knowledge, don't explain
- **Presenting live**: Consider `/gen:talking-points` — briefs are for reading, not speaking

## Output Format

**ALWAYS structure exec briefs like this:**

```
## [Topic] — Executive Brief

**Bottom line:** [1 sentence - the "so what" that matters to leadership]

**Context:** [2-3 sentences - why this matters now, what triggered this]

**Key points:**
- [Business impact point with quantification if possible]
- [Risk or opportunity framed in business terms]
- [Timeline or resource implication]

**Recommendation:** [Clear action or decision needed from reader]

**Details available:** [What deeper information exists if they want it]
```

## Constraints

- **Max 150 words** — executives skim, not read
- **No technical jargon** — translate all technical terms to business impact
- **Always include an ask** — what do you need from the reader?
- **Quantify when possible** — "saves 2 hours/week" not "improves efficiency"

## Example

```
## API Migration — Executive Brief

**Bottom line:** We need to migrate to the new API by March 15 or face $50K/month in fees.

**Context:** Our current API provider announced deprecation. The migration is straightforward but requires 2 weeks of engineering time. Delaying creates compliance risk.

**Key points:**
- Cost avoidance: $50K/month starting April 1
- Engineering effort: 2 weeks (1 engineer)
- Risk if delayed: Service disruption + compliance violation

**Recommendation:** Approve migration sprint starting next Monday.

**Details available:** Technical migration plan, risk assessment, rollback strategy
```

## Related Skills

| Skill | When to Use Instead |
|-------|---------------------|
| `/gen:tech-deep-dive` | Technical audience needs implementation details |
| `/gen:talking-points` | Preparing to present live rather than send document |
| `/mode:creative` mode | Still exploring options, not ready for summary |

Part of the **gen-plugin** output style system.

## Version History

### v1.0.0 (2026-02-24)
- Initial release with executive brief format
- Added "When NOT to Use" guidance
- Added related skills cross-references
