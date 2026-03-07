# Fix Archaeology Survey Scoring Bugs

## Goal

Fix 3 confirmed bugs in the archaeology survey workflow that produce unreliable domain scoring. These bugs block audit mode (cross-project portfolio scan) which depends on accurate, consistent survey output.

## Context

The archaeology skill (`~/.claude/skills/archaeology/SKILL.md`) extracts patterns from Claude Code session history. Its **survey mode** scans a project's JSONL conversation files, counts domain keyword occurrences, and produces a scored recommendation table in `survey.md`.

Three bugs make survey output unreliable:

### Bug 1: System prompt noise inflates all scores (CRITICAL)

**Root cause:** JSONL conversation files contain system prompts, tool definitions, and skill listings embedded *inside* user/assistant JSON records. The survey's Grep-based keyword counting hits this boilerplate, creating a false baseline of 70+ score for every domain in every project.

**Evidence:** A project with 1 session and 2 files showed "strong" signal on all 4 domains. Measured inflation: 2-7x depending on keyword. The `toolUseResult` top-level field (redundant raw tool output) is the biggest noise source, followed by `isMeta: true` user messages (skill/CLAUDE.md injections).

**Key finding from investigation:** Grep line-level filtering cannot work because noise lives *inside* the same JSON lines as signal. A `jq` pre-processing filter is required. A working filter has already been created and tested.

**Location of existing fix:** `~/.claude/skills/archaeology/references/jsonl-filter.jq` — extracts only real conversation text (user typed text, assistant text responses), excludes system records, isMeta messages, toolUseResult fields, tool_use command strings, and thinking blocks. Performance: 42ms per file, <1s per typical project.

**What needs to happen:** The scoring loop in `survey-workflow.md` Step S3 (lines 123-132) must be restructured to use this jq filter instead of raw Grep. The new flow should be:
1. For each JSONL file, pipe through `jq -r -f jsonl-filter.jq` to extract conversation text
2. Count keyword occurrences in the filtered output
3. Track which files (sessions) produced matches for session diversity scoring

The same change applies to the LARGE_PROJECT batching path (S3 lines 102-107) and the unknown detection tool frequency extraction (S5 lines 316-332).

### Bug 2: Signal labels ignore session count (SIMPLE)

**Root cause:** Signal classification in S3 (lines 141-144) is purely score-based with no session gate:
```javascript
signal = final_score >= 20 ? 'strong'
       : final_score >= 8  ? 'moderate'
       : final_score >= 2  ? 'weak'
       : 'none';
```

A project with 1 session can show "strong" signal regardless of score. This contradicts the meaning of "strong" ("High-value domain, run extraction first").

**Fix:** Add session-based cap after score classification:
- `session_set.size === 0` → force signal to `'none'`
- `session_set.size === 1` → cap signal at `'moderate'`
- Update the Signal Scale contract table to document this invariant

### Bug 3: Output format inconsistency (SIMPLE)

**Root cause:** The survey.md template in S6 defines a markdown table, but the LLM sometimes generates ASCII tables (`┌────┐`) or indented plain text instead. The S6 template and the Completion Display section coexist in the same file, and the agent conflates them.

**Fix:**
- Add explicit "Output Contract" callout at top of S6 stating format is a stable contract
- Separate the `survey.md` file-write template from the terminal completion display more clearly
- Optionally: add a validation step in S7 that re-reads written survey.md and checks for expected table headers

## Files to Read First

Read all of these before making any changes:

```
~/.claude/skills/archaeology/references/survey-workflow.md    # THE FILE TO MODIFY — full survey workflow S1-S7
~/.claude/skills/archaeology/references/jsonl-filter.jq       # Already-built jq filter for JSONL noise removal
~/.claude/skills/archaeology/SKILL.md                         # Parent skill (routing, domain extraction workflow)
~/.claude/skills/archaeology/SCHEMA.md                        # Domain file schema + finding object schema
~/.claude/skills/archaeology/references/domains/registry.yaml # Active domains list
~/.claude/projects/-Users-benpurslow/memory/archaeology-restructure-todos.md  # Bug documentation + test history
```

Also sample a real JSONL file to understand the format:
```
~/.claude/projects/-Users-benpurslow-Spotify-talent-snapshots/  # Has 14 JSONL files from a real project
```

## Skills and Plugins to Use

- **`/simplify`** — after each bug fix, review the changed code for quality
- Use **`shell-scripting:bash-pro`** sub-agents for jq filter integration and bash command testing
- Use **`superpowers:verification-before-completion`** before claiming each fix is done

## Sub-Agent Strategy

Use `/dispatching-parallel-agents` or manual Agent tool calls to parallelise:

### Agent 1: jq Integration Architect (Bug 1)
- **Type:** `shell-scripting:bash-pro`
- **Task:** Design the new scoring loop that replaces raw Grep with jq-filtered counting. Produce:
  - A bash function `count_keywords_filtered()` that takes a HISTORY_DIR, a keyword list, and the jq filter path, and returns per-keyword counts + per-file session tracking
  - Test it on `~/.claude/projects/-Users-benpurslow-Spotify-talent-snapshots/` comparing raw vs filtered counts for orchestration domain keywords (`Task`, `subagent_type`, `TeamCreate`, `SendMessage`)
  - Test it on a small project (`~/.claude/projects/-Users-benpurslow-Personal-docs/`) to verify the false-positive elimination
- **Owns:** The bash/jq integration pattern. Does NOT modify survey-workflow.md.

### Agent 2: Survey Workflow Updater (All 3 bugs)
- **Type:** `implementation-agent`
- **Task:** After Agent 1 delivers the counting function design, update `survey-workflow.md`:
  - **S3:** Replace the Grep scoring loop with pseudocode that uses the jq filter. Keep the same scoring formula but change the data source. Update both the normal and LARGE_PROJECT paths.
  - **S3:** Add session-count cap to signal classification (Bug 2 fix)
  - **S5:** Update tool frequency extraction to use jq-filtered content
  - **S6:** Add Output Contract callout, separate file-write from completion display (Bug 3 fix)
  - **S6:** Update the Signal Scale contract table with session-count invariant
- **Owns:** `survey-workflow.md` exclusively.

### Agent 3: Validation Tester
- **Type:** `general-purpose`
- **Task:** After Agent 2 completes, validate:
  - Read the updated `survey-workflow.md` and check logical consistency
  - Verify jq filter path references are correct
  - Verify Signal Scale contract table includes session-count cap
  - Check survey.md output template has explicit format contract
  - Run `wc -w` on SKILL.md to verify it's still under 3,000 words
  - Verify the scoring formula hasn't changed (only the data source)
- **Owns:** Nothing. Read-only validation.

## Test Plan

After implementation, test in a live Claude session:

1. **Strong signal project:** `cd ~/Spotify/talent-snapshots && /archaeology survey`
   - Expected: scores dramatically lower than previous (was 82-3721, should be ~10-100 range)
   - Expected: orchestration still shows strongest signal (real usage exists)

2. **Weak signal project:** `cd ~/Personal/docs && /archaeology survey`
   - Expected: most domains show `none` or `weak` (was falsely showing `strong`)
   - Expected: session count = 1, so no domain can exceed `moderate`

3. **Format check:** Both runs should produce identical markdown table format in survey.md

4. **No-regression:** `cd ~/Spotify/talent-snapshots && /archaeology orchestration --no-export`
   - Domain extraction should still work (it doesn't use the scoring loop)

## Constraints

- `survey-workflow.md` is the ONLY file that needs editing for bugs 1-3
- `jsonl-filter.jq` already exists and is tested — do not recreate it
- SKILL.md must stay under 3,000 words — do not add audit mode content yet
- The Signal Scale thresholds (20/8/2) are a contract — do not change the numbers
- The Confidence Scale (3+/2/1/0 sessions) is a contract — do not change
- `jq` is available on macOS (verify with `which jq` first)
- After fixing, update `~/.claude/projects/-Users-benpurslow/memory/archaeology-restructure-todos.md` to check off the resolved bugs

## Success Criteria

- [ ] Bug 1: Survey scoring uses jq-filtered content, not raw Grep on JSONL
- [ ] Bug 2: Signal label capped at `moderate` for single-session projects
- [ ] Bug 3: survey.md output uses stable markdown table format with explicit contract
- [ ] Existing domain extraction workflow unaffected
- [ ] All test scenarios pass
- [ ] Restructure todos updated
