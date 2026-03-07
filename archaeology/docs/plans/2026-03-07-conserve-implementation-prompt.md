# Conserve Command Implementation Prompt

> Paste this into a fresh Claude Code session to execute the plan.

---

Implement `/archaeology conserve` using the plan at `~/.claude/skills/archaeology/docs/plans/2026-03-06-conserve-command-plan.md`.

Use `superpowers:executing-plans` to drive execution. Use `superpowers:dispatching-parallel-agents` for the Tasks 1-4 fan-out.

Key decisions already made (do NOT revisit):
- **XML tags** for C4 agent output (`<artifact>...</artifact>`), not `---ARTIFACT---` delimiters
- **Type-specific seed filtering** via `build_seed_context()` with `TYPE_SEED_MAP`
- **Anchored overlap** in `distribute_sessions()` — earliest + longest shared by all agents
- **One-shot example** in each C4 agent prompt (~300 tokens each)
- **Per-agent failure diagnostics** in C5 with 3/5 structural failure threshold
- **`validate_artifact()`** layer between raw output and C5 parsing

Agent routing (follow exactly):
- Tasks 1-4: `implementation-agent` (sonnet), all 4 in parallel background
- Task 5: `implementation-agent` (sonnet) + `superpowers:executing-plans`, foreground, blocked on Task 1
- Task 6: `implementation-agent` (sonnet) + `superpowers:verification-before-completion`, foreground, blocked on Task 5
- Task 7a: `Explore` (opus), foreground — read-only static validation
- Task 7b: Main session — ask me before running the live test
- Task 8: `shell-scripting:bash-pro` (sonnet) + `shell-scripting:bash-defensive-patterns`, foreground
- Post-review: `plugin-dev:skill-reviewer` (sonnet) + `skill-checklist`, foreground

Design doc with all gap fixes applied: `~/.claude/skills/archaeology/docs/plans/2026-03-06-conserve-command-design.md`

Start with Tasks 1-4 in parallel. Go.
