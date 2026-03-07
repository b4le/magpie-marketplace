---
domain: orchestration
status: active
maintainer: archaeology-skill
last_updated: 2026-02-26
version: 1.0.0
agent_count: 5

keywords:
  primary:
    - Task
    - subagent_type
    - TeamCreate
    - SendMessage
  secondary:
    - parallel
    - orchestrat
    - agent
    - team_name
    - run_in_background
    - TaskCreate
    - TaskUpdate
    - spawn
    - delegation
    - concurrent
    - coordinate
  exclusion: []

locations:
  - path: "~/.claude/projects/-Users-*-{PROJECT_PATH_PATTERN}/"
    purpose: "Conversation history and subagent folders"
    priority: high
  - path: "~/{PROJECT_ROOT}/.development/"
    purpose: "Workflow artifacts and state files"
    priority: medium
  - path: "~/.claude/teams/"
    purpose: "Team configurations"
    priority: high
  - path: "~/.claude/teams/*/inboxes/"
    purpose: "Team message logs (SendMessage calls)"
    priority: high
  - path: "~/.claude/plans/"
    purpose: "Plan documents"
    priority: low

outputs:
  - file: README.md
    required: true
    template: readme
  - file: subagent-prompts.md
    required: true
    template: prompts
  - file: team-prompts.md
    required: false
    template: prompts
  - file: patterns.md
    required: true
    template: patterns
  - file: timeline.md
    required: false
    template: timeline
  - file: cost-analysis.md
    required: false
    template: patterns
---

# Orchestration Domain

**Description:** Agent orchestration patterns (sub-agents, teams, parallel execution)

---

## Metadata

| Field | Value |
|-------|-------|
| Domain ID | orchestration |
| Version | 1.0.0 |
| Created | 2026-02-26 |
| Updated | 2026-02-26 |
| Maintainer | archaeology-skill |

## Search Keywords

**Primary keywords** (must appear):
- Task
- subagent_type
- TeamCreate

**Secondary keywords** (boost relevance):
- parallel
- orchestrat
- agent
- team_name
- run_in_background

**Exclusion keywords** (filter false positives):
- (none for this domain)

## Search Locations

| Agent | Location | Purpose | Priority |
|-------|----------|---------|----------|
| Explore-1 | `~/.claude/projects/-Users-*-{PROJECT_PATH_PATTERN}/` | Conversations, subagent folders | High |
| Explore-2 | `~/{PROJECT_ROOT}/.development/` | Workflow artifacts, state files | Medium |
| Explore-3 | `~/.claude/teams/` | Team configurations | High |
| Explore-4 | `~/.claude/teams/*/inboxes/` | Team message logs (SendMessage calls) | High |
| Explore-5 | `~/.claude/plans/` | Plan documents | Low |

## Extraction Pattern

For each instance found, extract:

1. **User request** (verbatim)
2. **Task parameters:**
   - `description`
   - `subagent_type`
   - `team_name`
   - `prompt`
   - `run_in_background`
3. **Tools invoked:**
   - Task (subagent creation)
   - TeamCreate (team initialization)
   - SendMessage (inter-agent communication)
   - TaskCreate (task delegation)
   - TaskUpdate (task status updates)
4. **Execution mode:**
   - Background execution (`run_in_background: true`)
   - Foreground execution (`run_in_background: false`)
5. **Agent topology:**
   - Sub-Agents (star pattern)
   - Agent Teams (mesh pattern)
6. **Outputs created:**
   - Files generated
   - Deliverables produced

## Output Files

| File | Content | Required |
|------|---------|----------|
| README.md | Index with pattern summary, decision tree | Yes |
| subagent-prompts.md | Verbatim prompts for sub-agent invocations | Yes |
| team-prompts.md | Verbatim prompts for agent teams (if found) | If found |
| patterns.md | Decision framework, topology diagrams (ASCII) | Yes |
| timeline.md | Execution timeline, before/after evidence | Optional |

**File frontmatter template:**
```yaml
---
generated: {DATE}
project: {PROJECT_NAME}
pattern_types: [subagent, agent-team]
source_count: {N}
---
```

## Validation Rules

**Pre-execution:**
- At least one search location exists
- Output directory is writable
- `.work/extraction/` directory created

**Post-execution:**
- Results found OR no-results file created
- All output files have frontmatter
- No placeholder text in output (no "TODO", "[FILL THIS IN]", etc.)
- README.md links all findings
- Cross-references between files work

## Success Criteria

Findings should answer:

1. **What patterns were used?**
   - Sub-Agents vs Teams vs Direct execution
   - Parallel vs sequential execution
   - Background vs foreground tasks

2. **Why was each pattern chosen?**
   - Decision criteria from conversation context
   - Tradeoffs mentioned
   - Problem being solved

3. **What were the results?**
   - Success/failure outcomes
   - Artifacts produced
   - Lessons learned

4. **What prompts made it work?**
   - Verbatim prompt text
   - Parameter values used
   - Effective patterns observed

5. **What failures occurred and why?**
   - Timeouts and error conditions
   - Coordination breakdowns
   - Failed tool invocations
   - Recovery strategies attempted

## Anti-Patterns

**Do NOT extract:**

- Incomplete Task calls (missing required params)
- Failed orchestrations without context or learnings
- Sensitive data in prompts (credentials, tokens, private URLs)
- Example code that wasn't actually executed
- Draft/abandoned attempts that were never run

## Quick Extraction Commands

For manual inspection:

### Find Task invocations in a session
```bash
grep '"name":"Task"' SESSION.jsonl | jq -r '.message.content[] | select(.name == "Task") | "Description: \(.input.description)\nSubagent: \(.input.subagent_type)\n"'
```

### Count agents used
```bash
grep -o '"name":"Task"' SESSION.jsonl | wc -l
```

### Find team configurations
```bash
find ~/.claude/teams -name "*.json" 2>/dev/null
```

### Extract all Task tool parameters
```bash
grep '"name":"Task"' SESSION.jsonl | jq -r '.message.content[] | select(.name == "Task") | .input'
```

### Find TeamCreate invocations
```bash
grep '"name":"TeamCreate"' SESSION.jsonl | jq -r '.message.content[] | select(.name == "TeamCreate") | .input'
```

### Search for parallel execution patterns
```bash
grep -i 'parallel\|concurrently\|simultaneously' SESSION.jsonl | grep -o '"content":"[^"]*"' | head -20
```

## If No Results Found

When no orchestration patterns are found:

1. **Create:** `{DOMAIN_OUTPUT_DIR}/no-patterns-found.md`
2. **Document:**
   - Locations searched (with absolute paths)
   - Patterns tried (keywords, file patterns)
   - Suggestions for where patterns might exist
   - Alternative search strategies
3. **Do NOT create empty template files** (no empty subagent-prompts.md, etc.)

## Completion Criteria

Done when:

- ✅ All 5 search locations checked
- ✅ All Task/TeamCreate/SendMessage invocations documented
- ✅ Output files created with no placeholder text
- ✅ README.md links all findings
- ✅ Patterns analysis completed
- ✅ Validation rules pass
