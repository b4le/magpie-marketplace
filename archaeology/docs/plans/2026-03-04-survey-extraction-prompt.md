# Archaeology Skill: Extract Survey Workflow

## Context

The archaeology skill at `~/.claude/skills/archaeology/SKILL.md` is currently ~1,243 lines (~5,500 words), well over the 3,000-word ceiling. The survey workflow (lines 668-1243, Survey Steps S1-S7) was added recently and accounts for ~575 lines.

A previous session implemented progressive disclosure for the export pipeline (Steps 5-6) and applied targeted bug fixes (C1-C3, M1, M2, M4 from a skill review). The remaining structural fix is extracting the survey workflow.

## Task

Extract the survey workflow from SKILL.md into a separate reference file, keeping SKILL.md under 3,000 words.

### Steps

1. **Read the current state:**
   - `~/.claude/skills/archaeology/SKILL.md` — full file, focus on lines 668-1243 (survey workflow)
   - Note the routing logic near the top of SKILL.md that dispatches to survey vs domain extraction

2. **Create `~/.claude/skills/archaeology/references/survey-workflow.md`:**
   - Copy the entire survey workflow (## Survey Workflow through Survey Step S7 and its completion criteria) into this new file
   - Preserve all pseudocode, tables, and structure exactly as-is
   - Add a brief header noting this is referenced from SKILL.md

3. **Replace the survey section in SKILL.md with a pointer:**
   ```markdown
   ## Survey Workflow

   When invoked with no arguments or `survey`, execute the survey workflow.

   Read and follow the full specification in `references/survey-workflow.md`.

   Survey produces `survey.md` locally and in the central work-log, then updates INDEX.md files.
   ```

4. **Update the routing logic** (near the top of SKILL.md where it dispatches survey vs domain) to reference `references/survey-workflow.md` instead of inline steps.

5. **Verify SKILL.md word count is under 3,000:**
   ```bash
   wc -w ~/.claude/skills/archaeology/SKILL.md
   ```

6. **Verify the survey workflow file is self-contained:**
   - All variable references (PROJECT_NAME, PROJECT_SLUG, ARCHAEOLOGY_DIR, CENTRAL_BASE, etc.) should either be defined in the file or clearly noted as "set by SKILL.md Step 1"
   - The file should be followable without reading SKILL.md first (except for the context variables)

### Constraints

- Do NOT modify the survey workflow logic — this is a pure extraction, not a refactor
- The `--no-export` flag behaviour must be preserved in the extracted file
- Keep the survey completion criteria in the extracted file
- The local INDEX.md update function (`update_local_archaeology_index()`) appears in BOTH the domain workflow and survey workflow — leave the domain version in SKILL.md, move the survey version to the new file, and add a comment noting the shared function
