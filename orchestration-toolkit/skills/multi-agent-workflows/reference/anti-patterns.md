# Anti-Patterns

## What NOT to Do

❌ **Don't read archived raw files** - Read phase-summary.md only (token efficiency)

❌ **Don't skip STATUS.yaml updates** - Orchestrator relies on this for coordination

❌ **Don't use vague workflow IDs** - "workflow1" will collide with future workflows

❌ **Don't archive incomplete phases** - All agents must finish before archival

❌ **Don't pass massive context** - Use phase summaries, not full outputs

❌ **Don't modify archived files** - They're historical record, not live workspace

❌ **Don't skip phase README.md** - Sub-agents need clear instructions

❌ **Don't hardcode paths** - Use workflow_id from protocol, not assumptions
