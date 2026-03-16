# Archaeology Plugin Roadmap

> Backlog items identified from v1.4.0 review (2026-03-10). Prioritised as P3 — consider later.

## P3 — Enhancements

### Conservation + Dig cross-mode data flow
**Source:** Architecture review

Dig tracks `prior_outputs.artifacts` but the rig operator doesn't receive artifact content as seed context. Conservation's C2 doesn't consume dig nuggets either. Currently one-way flow only (survey → dig). Adding bidirectional flow would make conservation benefit from deep investigations and vice versa.

**Suggested approach:** Have the rig operator's `init` mode receive a `conservation_artifacts_summary` parameter when `prior_outputs.artifacts` is true. Have conservation's C2 check for `spelunk/*/nuggets/` as additional narrative seeds alongside `findings.json`.

---

### Register planned domains in registry.yaml
**Source:** Architecture review

`python-practices.md` references two sibling domains — `testing-patterns` and `api-design` — as planned but neither appears in `registry.yaml` even with `status: planned`. Adding them with `status: planned` would make `check-registry-sync.sh` aware of their existence and surface them in `/archaeology list` output.

---

### Explicit trove.md regeneration step in D7
**Source:** Architecture review

The state model correctly states trove.md is "regenerated from nuggets + veins each cycle — never appended to directly", but no numbered step in D7 shows the actual write logic. Adding an explicit D7b sub-step with the regeneration algorithm would remove ambiguity.

---

### Router: unknown command handling
**Source:** Skill review

`/archaeology typo` falls through to domain extraction silently, producing "Domain 'typo' not found". Adding a fuzzy match or "did you mean?" suggestion before the domain fallback would improve UX. Alternatively, an explicit catch-all with a helpful error listing valid commands.

---

### Acknowledge `dig list` in router
**Source:** Skill review

`/archaeology dig list` works because `"list"` is passed as the subject to `execute_dig()`, which handles it internally. But the main router reads as if this case is unhandled. Adding a comment or an explicit `args.subject === 'list'` early return in the router would clarify intent.

---

### Guard `--global` flag at router level
**Source:** Skill review

`argument-hint` implies `--global` works everywhere but it's only valid for `workstyle`. Passing `--global` to survey, conserve, or dig silently does nothing. Adding a router-level guard that warns "—global is only supported for workstyle" would prevent confusion.

---

### System-wide dependency reporting
**Source:** Dependency chain analysis (2026-03-11)

Full tracing of archaeology's dependency chain revealed that we can map every primitive the tool touches — from Layer 1 (Unix tools, JSONL history) through Layer 4 (structured outputs). This capability is valuable beyond documentation: archaeology could generate its own health/dependency reports automatically.

**Why this matters:** Being able to check across the entire system — what's installed, what's connected, what's missing — turns archaeology from a conversation analysis tool into a self-aware platform diagnostic. A `/archaeology status` or `/archaeology health` command could verify: all scripts executable, jq/jaq available, symlinks intact, domain registry in sync, output directories writable, central work-log structure valid, and report the full primitive chain (skills, plugins, agents, tools, scripts, domains) with versions and status.

**Suggested approach:** A `scripts/arch-health.sh` that validates the Layer 1-3 chain (binaries exist, symlinks resolve, scripts executable, validators pass, registry in sync) and a skill-level `/archaeology status` command that runs it plus reports Layer 4 state (output freshness, domain counts, artifact totals). Could reuse existing validators (`validate-domains.sh`, `check-registry-sync.sh`, `validate-conserve.sh`, `validate-dig.sh`) as sub-checks.

---

### Cross-system archaeology report
**Source:** Operational evidence (2026-03-11) — Slack post synthesis across 6+ projects, 574 conversations

A single-command report that synthesises findings across every scanned project into a unified view. This emerged from manually pulling evidence across multiple `.archaeology/` directories to draft a Slack post about system-wide patterns. The process exposed four capabilities that only exist at the cross-project level and cannot be surfaced by any per-project mode:

1. **Convergent pattern detection.** The same patterns ("Do agents need to discuss?", context rotation at 75%, file ownership boundaries) were invented independently across 4+ projects. No per-project scan shows this — it only appears when comparing findings side-by-side across projects.

2. **Repeated failure class discovery.** The MCP background agent bug was independently discovered in at least 3 projects (talent-snapshots, team-skills-workshop, content-management-strategy) and re-solved each time. A cross-system report would surface these as a single named failure class rather than isolated notes scattered across `.archaeology/` directories.

3. **Abandoned pipeline detection.** An 18-agent personas workflow (pa-themes-analysis) was found pending since Dec 2025. Per-project scans show it as "in progress"; cross-project context shows everything else moved on. The delta is only visible at system scope.

4. **Effort distribution meta-insight.** Prompting patterns dominated (110,956 score) over orchestration (71,968) across 574 conversations. This kind of effort-allocation signal is invisible inside any single project — it requires aggregating domain scores across the entire workspace.

This is a distinct capability from the existing survey/extraction/conserve/dig workflow, which all operate within a single project scope. The output would be a synthesised `cross-system-report.md` (written to `~/.claude/archaeology/` or a configurable output path) covering: convergent patterns ranked by project count, named failure classes with occurrence lists, stale/abandoned work, and effort distribution by domain category.

**Suggested approach:** Add a new top-level command — `/archaeology cross-system` (or `--system-report`) — that reads all `~/.claude/archaeology/*/findings.json` files (and optionally `survey.md` / `trove.md` files), runs a synthesis agent that groups entries by semantic similarity, and emits the unified report. The synthesis step maps naturally to a dig-style agent with a cross-project stitch spec analogous to `dig-stitch-spec.md`. No new per-project scanning infrastructure is needed; this consumes existing archaeology output as input.

---

*Last updated: 2026-03-11*
