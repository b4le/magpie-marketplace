# XML Output Format Migration Plan

> Goal: Migrate all archaeology workflow agent output formats from `KEY: value` line parsing to XML tags,
> for consistency with the conserve workflow, improved parse reliability, and elimination of delimiter
> collision risks (e.g. a summary sentence containing a colon breaking `extract_after()`).

---

## Background

The conserve workflow uses XML tags for structured agent output. The existing archaeology workflows
(survey, workstyle) use `KEY: value` line conventions with `extract_after()` as the parser. This
migration aligns all workflows on one convention.

Claude has native XML tag understanding — structured XML output is more reliable than line-based
parsing because it handles multi-line values, embedded colons, and whitespace naturally.

---

## Locations That Need Changing

### 1. Survey S5 — Unknown Detection agent prompt

**File:** `references/survey-workflow.md`
**Location:** Step S5 "Step 3 — Targeted LLM sampling for top unknowns", inside the `Agent({...})` prompt block

**Current format (agent is asked to output):**
```
THEME: [theme name]
SUMMARY: [one sentence]
```

**Current parsing code (immediately after Agent call):**
```javascript
theme = extract_after(agent_result, 'THEME:').trim();
summary = extract_after(agent_result, 'SUMMARY:').trim();
```

**Proposed agent output format:**
```
<theme>Async patterns</theme>
<summary>The user frequently used this tool to coordinate concurrent file operations.</summary>
```

**Proposed parsing code:**
```javascript
theme = extract_xml_field(agent_result, 'theme');
summary = extract_xml_field(agent_result, 'summary');
```

---

### 2. Workstyle W5 — Session deep-dive agent prompt

**File:** `references/workstyle-workflow.md`
**Location:** Step W5 "Sub-Agent Deep-Dives", inside the `Agent({...})` prompt block

**Current format (agent is asked to output):**
```
INSTRUCTION_STYLE: [short|medium|detailed] — [one sentence]
FEEDBACK_STYLE: [approve-quickly|review-carefully|redirect-often] — [one sentence]
SESSION_ARC: [linear|branching|exploratory] — [one sentence]
COMPLEXITY_APPROACH: [decompose|delegate|direct] — [one sentence]
NOTABLE_PATTERN: [any distinctive behaviour worth surfacing, or "none"]
```

**Current parsing code (immediately after agent loop):**
```javascript
deep_dive_results.push({
  instruction_style:   extract_after(result, 'INSTRUCTION_STYLE:'),
  feedback_style:      extract_after(result, 'FEEDBACK_STYLE:'),
  session_arc:         extract_after(result, 'SESSION_ARC:'),
  complexity_approach: extract_after(result, 'COMPLEXITY_APPROACH:'),
  notable_pattern:     extract_after(result, 'NOTABLE_PATTERN:')
});
```

**Proposed agent output format:**
```
<instruction_style>medium — The user gives clear but concise instructions with moderate specificity.</instruction_style>
<feedback_style>approve-quickly — The user rarely requests changes once output looks right.</feedback_style>
<session_arc>branching — Sessions explore options before committing to an implementation path.</session_arc>
<complexity_approach>delegate — Complex tasks are broken into sub-agent assignments.</complexity_approach>
<notable_pattern>Consistent use of plan mode before large refactors.</notable_pattern>
```

Note: The `—` delimiter within the value (e.g. `medium — one sentence`) is preserved as a value
convention — it is embedded in the XML content, not used for parsing. Keep it: the synthesis helpers
`synthesize_feedback_style()` and `synthesize_typical_arc()` already split on ` — ` to extract the
label portion. That split logic does NOT change.

**Proposed parsing code:**
```javascript
deep_dive_results.push({
  instruction_style:   extract_xml_field(result, 'instruction_style'),
  feedback_style:      extract_xml_field(result, 'feedback_style'),
  session_arc:         extract_xml_field(result, 'session_arc'),
  complexity_approach: extract_xml_field(result, 'complexity_approach'),
  notable_pattern:     extract_xml_field(result, 'notable_pattern')
});
```

---

### 3. `extract_after()` helper — replace with `extract_xml_field()`

**File:** `references/conversation-parser.md`
**Location:** "Utility Functions" section, `extract_after()` definition

**Current implementation:**
```javascript
function extract_after(text, label) {
  idx = text.indexOf(label);
  if (idx === -1) return null;
  remainder = text.slice(idx + label.length);
  first_line = remainder.split('\n').find(l => l.trim() !== '');
  return first_line ? first_line.trim() : null;
}
```

**Proposed replacement — add `extract_xml_field()`, keep `extract_after()` or deprecate:**
```javascript
// New canonical helper for XML-format agent output
function extract_xml_field(text, field_name) {
  open_tag  = `<${field_name}>`;
  close_tag = `</${field_name}>`;
  start = text.indexOf(open_tag);
  if (start === -1) return null;
  end = text.indexOf(close_tag, start);
  if (end === -1) return null;
  return text.slice(start + open_tag.length, end).trim();
}
```

Decision: either remove `extract_after()` once all callers are migrated, or keep it and mark it
deprecated. Recommend keeping it for one release cycle in case any inline prompts were missed.

---

## XML Convention to Use Consistently

| Case | Format |
|------|--------|
| Short single-line value | `<field_name>value</field_name>` |
| Value with embedded em-dash label | `<field_name>label — description</field_name>` |
| Multi-line prose body | `<body>paragraph text here...</body>` |
| Absent / not applicable | `<field_name>none</field_name>` (not empty tags, not omitted) |

Field names use `snake_case` to match the JavaScript variable names they map to.

Agent prompts should instruct: "Return ONLY the XML tags below — no prose, no headers, no
explanation outside the tags."

---

## What NOT to Change

- **JSONL file format** — structured JSON, not agent output
- **Markdown frontmatter** in domain files — YAML, not agent output
- **Shell script output** — `archaeology-excavation.sh` emits a JSON manifest, unrelated
- **Human-readable display templates** in `output-templates.md` — terminal display, not agent output
- **`survey.md` markdown table format** — file contract read by excavation, not agent output
- **`extract_after()` call sites** outside archaeology (if any) — check before removing
- **`synthesize_feedback_style()`, `synthesize_typical_arc()`, `synthesize_correction_frequency()`**
  in workstyle-workflow.md — these split on ` — ` within the *value* string, which is preserved
  inside the XML tag. No logic change needed there.

---

## Backward Compatibility

- **Existing `findings.json` files** — not affected. Domain extraction outputs are not agent-parsed.
- **Existing `workstyle.json` files** — not affected. The JSON structure is unchanged; only the
  *source* of parsed strings changes.
- **Existing `survey.md` files** — not affected. survey.md is written by the skill, not by a
  sub-agent returning KEY: value.
- **Re-generation not required.** Only the agent prompt templates and their corresponding
  `extract_xml_field()` parsing calls change. Existing output files remain valid.

---

## Scope Estimate

| File | Edit locations | Notes |
|------|---------------|-------|
| `references/survey-workflow.md` | 2 | Agent prompt block (S5 Step 3) + parsing code below it |
| `references/workstyle-workflow.md` | 2 | Agent prompt block (W5) + parsing code below it |
| `references/conversation-parser.md` | 1-2 | Add `extract_xml_field()`, optionally deprecate `extract_after()` |

**Total:** 3 files, 5-6 edit locations. **Complexity: Low.**

---

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Agent ignores XML format, reverts to KEY: value | Low-medium | Add "do NOT use KEY: value format" negative constraint to prompt |
| Agent wraps output in a markdown code block | Low | `extract_xml_field()` searches full text; fences don't contain the tags |
| Embedded `<` or `>` in a summary sentence | Very low | Claude prose rarely uses raw angle brackets |
| `synthesize_*` helpers break | None | Value format inside tags is identical — only the wrapper changes |
| Missed stale `extract_after()` call site | Low | Grep for `extract_after` across all skill files before closing |

**What needs testing after migration:**
1. Run `/archaeology survey` on a test project — verify S5 agent output parses correctly
2. Run `/archaeology workstyle` on a test project — verify W5 deep-dive populates all five fields
3. Verify `synthesize_feedback_style()` and `synthesize_typical_arc()` still return expected label strings
4. Grep for remaining `extract_after(` calls to confirm none were missed

---

## Implementation Checklist (for the migration session)

- [ ] Edit `references/survey-workflow.md` — update S5 agent prompt to XML output format
- [ ] Edit `references/survey-workflow.md` — replace `extract_after()` calls with `extract_xml_field()`
- [ ] Edit `references/workstyle-workflow.md` — update W5 agent prompt to XML output format
- [ ] Edit `references/workstyle-workflow.md` — replace `extract_after()` calls with `extract_xml_field()`
- [ ] Edit `references/conversation-parser.md` — add `extract_xml_field()` function definition
- [ ] Edit `references/conversation-parser.md` — deprecate or remove `extract_after()`
- [ ] Grep for any remaining `extract_after(` calls across all skill files
- [ ] Run live test: survey mode S5 agent output parses correctly
- [ ] Run live test: workstyle mode W5 deep-dive output populates all five fields
- [ ] Run live test: workstyle synthesis helpers still produce correct label strings
