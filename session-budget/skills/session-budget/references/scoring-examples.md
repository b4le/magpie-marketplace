# Session Budget: Scoring Examples

> This file is referenced from `SKILL.md`. It provides five worked examples of session budget scoring to calibrate task classification, front-loading, session splitting, stale task handling, and research-mode budgeting. Each example is self-contained and uses realistic plugin and skill development scenarios from the magpie-marketplace context.

---

## Example A — Simple session, well within budget

**Scenario:** Tidying up the `unicode-library` plugin after a 1.2.0 release. Four housekeeping tasks with no design decisions or unknowns.

**Tasks:**
1. Fix a broken link in `README.md` pointing to the old registry URL
2. Bump `version` field in `plugin.json` from `1.2.0` to `1.2.1`
3. Add `"unicode"` to the `keywords` array in `plugin.json`
4. Write a changelog entry for the 1.2.1 patch in `CHANGELOG.md`

```
| # | Task                                    | Complexity | Points | Cumulative |
|---|-----------------------------------------|------------|--------|------------|
| 1 | Fix README link (registry URL)          | simple     | 1      | 1          |
| 2 | Bump plugin.json version to 1.2.1       | simple     | 1      | 2          |
| 3 | Add keyword to plugin.json              | simple     | 1      | 3          |
| 4 | Write CHANGELOG entry for 1.2.1         | simple     | 1      | 4          |
```

**Session Budget: 4 / 8 points** (target: 7) [OK] within budget

**Recommendation:** Proceed in any order — all tasks are single-file edits with zero unknowns. No reordering needed. Remaining headroom (4 points) is available if the user wants to add related tasks such as updating the marketplace index entry or tagging the release.

---

## Example B — Session right at the cap

**Scenario:** Adding a new `validate-palette` skill to the existing `unicode-library` plugin. The plugin structure and conventions are already established; this is pure authoring work against known patterns.

**Tasks:**
1. Research existing skill structure in `unicode-library/skills/` (read SKILL.md, scan references)
2. Write `SKILL.md` for the new `validate-palette` skill
3. Write reference doc: `validation-rules.md`
4. Write reference doc: `error-catalogue.md`
5. Update `unicode-library/README.md` to document the new skill

```
| # | Task                                          | Complexity | Points | Cumulative |
|---|-----------------------------------------------|------------|--------|------------|
| 1 | Research existing skill structure              | simple     | 1      | 1          |
| 2 | Write validate-palette SKILL.md               | medium     | 2      | 3          |
| 3 | Write reference: validation-rules.md          | medium     | 2      | 5          |
| 4 | Write reference: error-catalogue.md           | medium     | 2      | 7          |
| 5 | Update unicode-library README.md              | simple     | 1      | 8          |
```

**Session Budget: 8 / 8 points** (target: 7) [OK] within budget

**Recommendation:** Proceed, but reorder to front-load the hardest work.

- Move task 2 (SKILL.md) to position 1 — this is the design-heavy task that anchors all downstream content. Do it first while attention is sharpest.
- Task 1 (research) folds naturally into the start of task 2 rather than being a separate step; treat it as warm-up within the same action.
- **Lost-in-the-middle risk:** Tasks 4 and 5 fall in the degraded-attention zone (positions 4-5). Both are mechanical and well-scoped, so this is acceptable — but verify `error-catalogue.md` against `validation-rules.md` before closing out.

---

## Example C — Over-budget session that needs splitting

**Scenario:** Launching a brand-new `token-counter` plugin from scratch. The plugin needs a `plugin.json`, two full skills each with reference docs, a README, a marketplace index entry, and an eval suite.

**Tasks:**
1. Design and write `plugin.json` (name, description, keywords, version)
2. Write Skill A — `count-tokens`: SKILL.md + 3 reference docs
3. Write Skill B — `estimate-cost`: SKILL.md + 2 reference docs
4. Write `README.md` for the plugin
5. Update `marketplace-index.json` to register the new plugin
6. Write evals for both skills in `evals/`

```
| # | Task                                          | Complexity | Points | Cumulative |
|---|-----------------------------------------------|------------|--------|------------|
| 1 | Design plugin.json                            | simple     | 1      | 1          |
| 2 | Write Skill A (count-tokens) + 3 refs         | complex    | 3      | 4          |
| 3 | Write Skill B (estimate-cost) + 2 refs        | complex    | 3      | 7          |
| 4 | Write README.md                               | medium     | 2      | 9          |
| 5 | Update marketplace-index.json                 | simple     | 1      | 10         |
| 6 | Write evals for both skills                   | complex    | 3      | 13         |
```

**Session Budget: 13 / 8 points** (target: 7) [OVER BUDGET] — needs splitting

**Recommended split:**

**Session 1 — Core plugin (7 pts)**

```
| # | Task                                | Complexity | Points | Cumulative |
|---|-------------------------------------|------------|--------|------------|
| 1 | Write Skill A (count-tokens) + refs | complex    | 3      | 3          |
| 2 | Write Skill B (estimate-cost) + refs| complex    | 3      | 6          |
| 3 | Design plugin.json                  | simple     | 1      | 7          |
```

**Session 2 — Packaging and quality (6 pts)**

```
| # | Task                          | Complexity | Points | Cumulative |
|---|-------------------------------|------------|--------|------------|
| 1 | Write evals for both skills   | complex    | 3      | 3          |
| 2 | Write README.md               | medium     | 2      | 5          |
| 3 | Update marketplace-index.json | simple     | 1      | 6          |
```

End Session 1 by writing a handoff file to `~/.claude/handoffs/` capturing: skills authored, plugin.json fields settled, open decisions (eval harness format, README scope). See `references/handoff-template.md` for the exact handoff format.

---

## Example D — Session with a stale task

**Scenario:** The user is planning a session that includes a "refactor auth module" task. Scanning `~/.claude/todos.md` shows this exact item has appeared in three prior handoff files (2026-01-14, 2026-02-03, 2026-02-27) and remains incomplete each time.

**Current proposed session:**

```
| # | Task                                          | Complexity | Points | Cumulative |
|---|-----------------------------------------------|------------|--------|------------|
| 1 | Refactor auth module in marketplace-tools     | complex    | 3      | 3          |
| 2 | Write session-budget scoring-examples.md ref  | medium     | 2      | 5          |
| 3 | Add plugin.json validation to CI hook         | medium     | 2      | 7          |
```

**Session Budget: 7 / 8 points** (target: 7) [OK] within budget

**Stale task detected:** "Refactor auth module" — attempted in 3+ prior sessions without completion.

This task cannot be attempted again in its current form. Attempting a third retry without decomposition has a high probability of another incomplete outcome.

**Required action before proceeding:** Decompose into sub-tasks with blockers identified.

**Decomposed replacement:**

```
| # | Sub-task                                          | Complexity | Points | Blocker                              |
|---|---------------------------------------------------|------------|--------|--------------------------------------|
| A | Audit current auth module — map all call sites    | simple     | 1      | None — read-only reconnaissance      |
| B | Extract token-refresh logic into separate module  | medium     | 2      | Depends on A's call-site map         |
| C | Update dependent plugins to use new module path   | medium     | 2      | Depends on B; requires plugin list   |
```

Sub-task A should be scheduled first in the current session to unblock B and C. B and C can slot into a follow-on session once the call-site map is in hand. If sub-task A completes and the picture is more complex than expected, stop and reassess before proceeding to B.

**Revised budget with decomposed task A only:**

```
| # | Task                                          | Complexity | Points | Cumulative |
|---|-----------------------------------------------|------------|--------|------------|
| 1 | Audit auth module — map all call sites        | simple     | 1      | 1          |
| 2 | Write session-budget scoring-examples.md ref  | medium     | 2      | 3          |
| 3 | Add plugin.json validation to CI hook         | medium     | 2      | 5          |
```

**Session Budget: 5 / 8 points** (target: 7) [OK] within budget

---

## Example E — Research-only session

**Scenario:** Before building a shared `trigger-matching` utility for magpie plugins, the user wants to understand how three existing plugins (`archaeology`, `unicode-library`, `session-budget`) each handle trigger phrase detection, then draft a decision memo on the right shared approach.

**Tasks:**
1. Read and summarise trigger handling in `archaeology` SKILL.md
2. Read and summarise trigger handling in `unicode-library` SKILL.md
3. Read and summarise trigger handling in `session-budget` SKILL.md
4. Synthesise findings into a decision memo: `trigger-matching-options.md`

```
| # | Task                                               | Complexity | Points | Cumulative |
|---|----------------------------------------------------|------------|--------|------------|
| 1 | Research trigger handling — archaeology            | simple     | 1      | 1          |
| 2 | Research trigger handling — unicode-library        | simple     | 1      | 2          |
| 3 | Research trigger handling — session-budget         | simple     | 1      | 3          |
| 4 | Synthesise into decision memo (trigger-matching)   | medium     | 2      | 5          |
```

**Session Budget: 5 / 8 points** (target: 7) [OK] within budget

**Research-mode note:** Read-only research sessions have a higher effective budget ceiling — up to 12 points — because research tasks are lower-risk (no writes, easy to course-correct) and context accumulation is the primary cost. This session is well within even the standard 8-point cap.

**Agent delegation note:** Tasks 1-3 are independent and can be parallelised. Delegate each to a separate sub-agent (use `subagent_type: explore`, model: `haiku`) rather than running them sequentially in the main session. Each sub-agent reads its plugin and returns a 200-word summary. The main session receives the three summaries and performs task 4 (synthesis) directly. This keeps the main context window clean and cuts wall-clock time by ~60%.
