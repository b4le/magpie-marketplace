# Design: Archaeology Workstyle Mode

> Analysed and validated 2026-03-04 | Approved for implementation

## Summary

Add a `workstyle` mode to the archaeology skill that analyses **how** a user works with Claude — tool preferences, session shapes, delegation patterns, communication style — rather than code content. Produces `workstyle.md` (narrative) + `workstyle.json` (structured) locally and in the central work-log.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Architecture | Parallel built-in mode (like survey) | 3-agent investigation: unanimous recommendation. Shares project resolution, own pipeline in reference file. |
| Primary consumer | Both human reflection + machine-readable | `workstyle.md` for reading, `workstyle.json` for future sessions to adapt |
| Scope | Per-project default + `--global` flag | Per-project is consistent with existing UX; `--global` aggregates across all projects |
| Output sections | Always all sections (consistent contract) | Thin sections say "Not enough data" rather than being absent |
| Parse depth | Metadata + sampling + on-demand sub-agents | Fast metadata pass on all sessions, deep-dive on 3-5 representative sessions |
| Structured output | `workstyle.json` companion file | Separate schema from findings.json — different data shape |
| Parser location | Separate `references/conversation-parser.md` | Designed for reuse by future modes (deep-dive, enhanced survey) |
| JSON vs Grep for W2 | Full JSON parsing | Only 1.5x slower than Grep but 100% accurate. Regex gets false positives from tool input fields. |

## Plugin Extraction Criteria

Workstyle is the 4th mode (ceiling). Extract archaeology to a plugin when **any 2** of:
1. SKILL.md exceeds ~400 lines
2. User wants `/workstyle` as standalone command
3. Conversation parser reused outside archaeology
4. Executable code enters the picture

## File Changes

### New Files
| File | Purpose |
|------|---------|
| `references/workstyle-workflow.md` | Full W1-W7 step specification |
| `references/conversation-parser.md` | Shared JSONL parser specification |

### Modified Files
| File | Change |
|------|--------|
| `SKILL.md` | Add routing case, invocation patterns, stub section, updated description/argument-hint (~15-20 lines) |
| `SCHEMA.md` | Add Workstyle Object Schema (v1) section |
| `references/output-templates.md` | Add `{#workstyle}` template; update `{#summary}` with optional Workstyle Overview |
| `references/consumption-spec.md` | Add workstyle to reading levels |

### No Changes
| File | Why |
|------|-----|
| `references/domains/registry.yaml` | Workstyle is a built-in mode, not a domain |
| `references/survey-workflow.md` | Independent pipeline, no coupling |
| Domain definition files | Not affected |

## Conversation Parser Spec (`references/conversation-parser.md`)

### JSONL Message Types

| Type | Workstyle Signal | Edge Cases |
|------|-----------------|------------|
| `user` | Instruction length, prompt specificity | **CRITICAL:** `type: "user"` includes tool results. Only `isinstance(content, str)` = human input. Without filtering, counts inflate ~6x. |
| `assistant` | Tool choices, response patterns | tool_use blocks at `.message.content[].type === "tool_use"` |
| `progress` | Hook activity, session lifecycle | Includes hook_progress and agent_progress |
| `system` | Context/reminders | Not useful for workstyle |
| `file-history-snapshot` | Edit frequency | **No timestamps or sessionId.** Skip in duration calculations. |

### Per-Session Metadata

```javascript
session_meta = {
  // Identity
  session_id: string,           // from .sessionId (always present)
  slug: string | null,          // from .slug (OPTIONAL — appears between line 8-175, absent in some sessions)
  timestamp_start: ISO_string,  // first non-snapshot message timestamp
  timestamp_end: ISO_string,    // last non-snapshot message timestamp
  duration_minutes: number,     // end - start
  cwd: string,                  // working directory
  version: string,              // Claude Code version

  // Message counts
  user_message_count: number,      // ONLY messages where isinstance(content, str) — NOT tool results
  assistant_message_count: number,
  total_exchanges: number,         // = user_message_count (actual human inputs)

  // User message analysis
  user_msg_lengths: number[],   // character lengths of each human message
  avg_user_msg_length: number,

  // Tool usage (from assistant tool_use blocks)
  tool_counts: { [tool_name]: number },
  skill_invocations: string[],     // Skill tool .input.skill values
  agent_types: string[],           // Task tool .input.subagent_type values

  // Delegation signals
  agent_spawn_count: number,       // Task tool calls with subagent_type in input
  team_operations: number,         // TeamCreate + SendMessage + SendBroadcast tool calls
  plan_mode_exits: number,         // ExitPlanMode tool calls (no reliable entry signal)
}
```

**Critical implementation notes:**
1. Agent spawning uses `Task` tool (not `Agent`). Detect via `tool_use.name === "Task"` with `"subagent_type" in input`.
2. Skip `file-history-snapshot` messages when computing timestamps.
3. `slug` requires scanning multiple lines — not guaranteed on line 1. Default to `null` if absent.
4. Corrupt JSONL: skip malformed lines, log count of skipped lines.
5. Scan only top-level files (`{project-dir}/{uuid}.jsonl`), exclude `{uuid}/subagents/` directories.

### Aggregation Functions

| Function | Input | Output |
|----------|-------|--------|
| `aggregate_tool_counts(sessions[])` | All sessions | Merged `{ tool: total_count }` sorted desc |
| `aggregate_session_shapes(sessions[])` | All sessions | `{ avg_duration, avg_exchanges, avg_tool_diversity, median_user_msg_length }` |
| `compute_delegation_ratio(sessions[])` | All sessions | `{ solo_pct, delegated_pct, team_pct }` where solo = 0 agents, delegated = 1+ agents, team = 1+ TeamCreate |
| `compute_instruction_profile(sessions[])` | All sessions | `{ style: "short"|"medium"|"detailed", avg_length, distribution }` based on avg_user_msg_length thresholds |
| `compute_evolution(sessions[])` | All sessions sorted by date | Sessions split into time windows; compare early vs recent metrics |

## Workstyle Workflow (`references/workstyle-workflow.md`)

### W1: Resolve Project Context

Standard project resolution (shared with survey/domain). Additional:

```javascript
GLOBAL_MODE = args.includes('--global');
NO_EXPORT = args.includes('--no-export');

if (GLOBAL_MODE) {
  // Scan ALL project directories
  ALL_PROJECT_DIRS = Glob('~/.claude/projects/-Users-*');
  // Filter to directories containing .jsonl files
  ALL_PROJECT_DIRS = ALL_PROJECT_DIRS.filter(dir =>
    Glob(`${dir}/*.jsonl`).length > 0
  );

  if (ALL_PROJECT_DIRS.length === 0) {
    error("No projects with session history found. Run /archaeology survey on individual projects first.");
  }

  // Global output paths
  WORKSTYLE_LOCAL_PATH = null;  // No local output for global mode
  CENTRAL_GLOBAL_PATH = `${CENTRAL_BASE}/workstyle-global.md`;
  CENTRAL_GLOBAL_JSON = `${CENTRAL_BASE}/workstyle-global.json`;
} else {
  // Standard single-project resolution (same as survey S1)
  // ...existing project resolution logic...

  WORKSTYLE_LOCAL_PATH = `${ARCHAEOLOGY_DIR}/workstyle.md`;
  WORKSTYLE_JSON_PATH = `${ARCHAEOLOGY_DIR}/workstyle.json`;
  CENTRAL_PROJECT_DIR = `${CENTRAL_BASE}/${PROJECT_SLUG}`;
}
```

**`--global` project discovery:**
Scan `~/.claude/projects/` for encoded project paths. Each directory maps to a project via its encoding (e.g., `-Users-benpurslow-Spotify-myproject` → `/Users/benpurslow/Spotify/myproject`). Aggregate sessions across all discovered projects.

### W2: Metadata Pass (Fast — All Sessions)

Parse all JSONL files using **full JSON parsing** (not Grep). Extract `session_meta` per the conversation-parser spec.

```javascript
all_sessions = [];
conversation_files = GLOBAL_MODE
  ? ALL_PROJECT_DIRS.flatMap(dir => Glob(`${dir}/*.jsonl`))
  : Glob(`${HISTORY_DIR}/*.jsonl`);

// Minimum data threshold
MIN_SESSIONS = 3;
if (conversation_files.length < MIN_SESSIONS) {
  confidence_override = 'low';
  warn(`Only ${conversation_files.length} sessions found. Recommend at least 5 for reliable analysis. Proceeding with low confidence.`);
}

for (file of conversation_files) {
  meta = extract_session_metadata(file);  // per conversation-parser.md
  all_sessions.push(meta);
}

// Sort by timestamp for evolution analysis
all_sessions.sort((a, b) => a.timestamp_start - b.timestamp_start);
```

**Performance:** 540 top-level sessions across all projects parses in ~3.6 seconds. No batching needed.

### W3: Dimension Scoring

Compute each workstyle dimension from aggregated metadata.

**Session pattern classification:**

| Pattern | Detection Rule |
|---------|---------------|
| Plan-first | `ExitPlanMode` in session's tool list (plan mode was entered and exited) |
| Iterative refinement | `user_message_count / total_tool_calls > 0.3` (high back-and-forth ratio) |
| Deep exploration | `(Read + Grep + Glob count) / (Edit + Write count) > 3` (more reading than writing) |
| Delegation-heavy | `agent_spawn_count > 3` per session |
| Direct execution | `user_message_count < 5` AND `total_tool_calls > 10` (short instructions, lots of action) |

Each session gets classified into its primary pattern. Sessions can match multiple patterns — take the strongest signal.

**Preference detection:**
Cross-reference observed patterns with `~/.claude/CLAUDE.md` rules and `~/.claude/settings.json` config. Three categories:
- **Confirmed preferences**: pattern matches a CLAUDE.md rule (e.g., CLAUDE.md says "always use worktrees" → sessions show worktree usage)
- **Detected preferences**: consistent pattern NOT in CLAUDE.md (candidate for CLAUDE.md recommendation)
- **Contradicted preferences**: CLAUDE.md rule exists but sessions show the opposite

### W4: Sampling Selection

Select 3-5 representative sessions for deeper sub-agent analysis:

```javascript
sampled_sessions = [];

// 1. Longest session (most data — richest for communication style)
sampled_sessions.push(max_by(all_sessions, s => s.total_exchanges));

// 2. Most delegation-heavy (best for delegation pattern analysis)
sampled_sessions.push(max_by(all_sessions, s => s.agent_spawn_count));

// 3. Most recent (current habits, most relevant)
sampled_sessions.push(max_by(all_sessions, s => s.timestamp_end));

// 4. Most diverse tool usage (broadest working style signal)
sampled_sessions.push(max_by(all_sessions, s => Object.keys(s.tool_counts).length));

// 5. Shortest productive session (different working mode)
productive = all_sessions.filter(s => s.total_exchanges >= 3);
if (productive.length > 0) {
  sampled_sessions.push(min_by(productive, s => s.duration_minutes));
}

// Deduplicate by session_id
sampled_sessions = unique_by(sampled_sessions, s => s.session_id);
```

### W5: Sub-Agent Deep-Dives

Spawn Explore agents for sampled sessions. **Sampling budget per agent:**
- Read the JSONL file
- Focus on `user` messages (where `isinstance(content, str)`) and `assistant` tool_use blocks
- **Output contract:** Return ONLY the structured format below. Do NOT return raw session content.

```javascript
for (session of sampled_sessions) {
  Agent({
    subagent_type: "Explore",
    prompt: `You are analysing a Claude Code session for workstyle patterns.

SESSION FILE: ${session.file_path}

Focus on STRUCTURE and METADATA, not conversation content. Read the file and analyse:

1. INSTRUCTION STYLE: How does the user give instructions?
   - Detailed specs vs quick commands vs iterative refinement
   - Average specificity (vague "fix this" vs precise "change X to Y")

2. FEEDBACK PATTERNS: How does the user respond to output?
   - Approve-and-move-on vs detailed review vs request changes
   - How quickly do they redirect when output is wrong?

3. SESSION ARC: What's the overall flow?
   - Linear (start→finish) vs branching (explore→decide→implement)
   - Where are the decision points?

4. COMPLEXITY HANDLING: How does the user handle complex tasks?
   - Break down into steps vs delegate to agents vs tackle head-on

Return ONLY this format — no prose, no raw content:
INSTRUCTION_STYLE: [short|medium|detailed] — [one sentence]
FEEDBACK_STYLE: [approve-quickly|review-carefully|redirect-often] — [one sentence]
SESSION_ARC: [linear|branching|exploratory] — [one sentence]
COMPLEXITY_APPROACH: [decompose|delegate|direct] — [one sentence]
NOTABLE_PATTERN: [any distinctive behaviour worth surfacing, or "none"]`
  });
}

// ADDITIONAL sub-agents may be spawned if W3 dimension scoring reveals
// areas needing investigation (e.g., unusual tool usage spikes, unexpected
// delegation ratios). This is responsive to data, not a fixed count.
```

### W6: Generate Outputs

Assemble all data into `workstyle.md` and `workstyle.json`.

**Always-present sections in `workstyle.md`:**

| Section | Source | Content |
|---------|--------|---------|
| Working Style Summary | W3 + W5 synthesis | 2-3 sentence characterisation |
| Session Patterns | W3 classification | Pattern frequency table with examples |
| Tool Usage Profile | W2 aggregation | Tool/count/context table, top 15 tools |
| Delegation Patterns | W3 delegation ratio | Solo vs delegated vs team percentages, preferred agent types |
| Communication Style | W5 deep-dives | Instruction length, feedback style, correction patterns |
| Session Shape | W2 aggregation | Average length, typical arc, breakpoints |
| Preferences Detected | W3 preference detection | Confirmed, detected, and contradicted preferences |
| Evolution Over Time | W3 evolution | How workstyle has changed across time windows |

**`workstyle.json` top-level structure:**

```json
{
  "version": "1.0",
  "generated_at": "ISO timestamp",
  "project": "Project Name",
  "project_slug": "project-slug",
  "scope": "project" | "global",
  "session_count": 42,
  "session_range": { "earliest": "ISO", "latest": "ISO" },
  "confidence": "high" | "medium" | "low",

  "summary": "2-3 sentence working style characterisation",

  "session_patterns": {
    "plan_first_pct": 0.60,
    "iterative_pct": 0.30,
    "exploratory_pct": 0.10,
    "delegation_heavy_pct": 0.15,
    "direct_execution_pct": 0.05,
    "dominant_pattern": "plan_first"
  },

  "tool_usage": {
    "total_tool_calls": 1250,
    "unique_tools": 18,
    "top_tools": [
      { "name": "Read", "count": 320, "pct": 0.256 },
      { "name": "Edit", "count": 210, "pct": 0.168 }
    ],
    "skill_usage": [
      { "name": "brainstorming", "count": 12 }
    ],
    "agent_types": [
      { "type": "Explore", "count": 45 },
      { "type": "general-purpose", "count": 20 }
    ]
  },

  "delegation": {
    "solo_pct": 0.65,
    "delegated_pct": 0.25,
    "team_pct": 0.10,
    "avg_agents_per_delegated_session": 3.2
  },

  "communication": {
    "instruction_style": "detailed",
    "avg_instruction_length": 245,
    "feedback_style": "review-carefully",
    "correction_frequency": "moderate"
  },

  "session_shape": {
    "avg_duration_minutes": 35,
    "avg_exchanges": 12,
    "avg_tool_calls_per_session": 28,
    "typical_arc": "context → plan → implement → test → commit"
  },

  "preferences": {
    "confirmed": ["Uses worktrees for features", "Plan-first approach"],
    "detected": ["Prefers agent teams for multi-file changes"],
    "contradicted": []
  },

  "evolution": {
    "trend": "increasingly structured",
    "early_dominant_pattern": "exploratory",
    "recent_dominant_pattern": "plan_first",
    "delegation_trend": "increasing"
  }
}
```

**Confidence scoring:**
- `high`: 10+ sessions with diverse patterns
- `medium`: 5-9 sessions
- `low`: 3-4 sessions (or override from W2 threshold check)

### W7: Export + Index Updates

```javascript
if (!NO_EXPORT) {
  if (GLOBAL_MODE) {
    Write(CENTRAL_GLOBAL_PATH, workstyle_md_content);
    Write(CENTRAL_GLOBAL_JSON, workstyle_json_content);
  } else {
    // Write to central project directory (sibling to survey.md and SUMMARY.md)
    Write(`${CENTRAL_PROJECT_DIR}/workstyle.md`, workstyle_md_content);
    Write(`${CENTRAL_PROJECT_DIR}/workstyle.json`, workstyle_json_content);
  }

  // Update central INDEX.md
  update_central_index();  // Existing function (SKILL.md Step 5c) — needs extension to detect workstyle
}

// Always write local outputs (unless --global, which has no local project)
if (!GLOBAL_MODE) {
  Write(WORKSTYLE_LOCAL_PATH, workstyle_md_content);
  Write(WORKSTYLE_JSON_PATH, workstyle_json_content);
  update_local_archaeology_index();  // Existing function — needs extension for workstyle
}
```

### Completion Criteria

Workstyle run is complete when:
- [ ] Project context resolved (W1)
- [ ] **(If --global)** All project directories discovered and validated
- [ ] Metadata pass completed — all sessions parsed with JSON parsing (W2)
- [ ] All dimensions scored with evidence (W3)
- [ ] Representative sessions sampled (W4)
- [ ] Sub-agent deep-dives completed with structured output (W5)
- [ ] `workstyle.md` and `workstyle.json` written locally (W6)
- [ ] All 8 sections present in `workstyle.md`
- [ ] Local `INDEX.md` updated with workstyle entry
- [ ] **(Unless --no-export)** Outputs exported to central work-log
- [ ] **(Unless --no-export)** Central `INDEX.md` updated
- [ ] Completion summary displayed with file locations

### Completion Display

```
Archaeology Workstyle Complete

Analysed {N} sessions | {date range} | {confidence} confidence

Dominant pattern: {pattern} ({pct}%)
Top tools: {tool1} ({count}), {tool2} ({count}), {tool3} ({count})
Delegation: {solo_pct}% solo, {delegated_pct}% delegated, {team_pct}% team

Local:   .claude/archaeology/workstyle.md
         .claude/archaeology/workstyle.json
Central: ~/.claude/data/visibility-toolkit/work-log/archaeology/{slug}/workstyle.md
         ~/.claude/data/visibility-toolkit/work-log/archaeology/{slug}/workstyle.json
```

**If --global:**
```
Archaeology Workstyle Complete (global)

Analysed {N} sessions across {P} projects | {date range}
[same stats]

Central: ~/.claude/data/visibility-toolkit/work-log/archaeology/workstyle-global.md
         ~/.claude/data/visibility-toolkit/work-log/archaeology/workstyle-global.json
```

**If --no-export:**
```
Archaeology Workstyle Complete (export skipped)
[same stats]
Local: .claude/archaeology/workstyle.md
       .claude/archaeology/workstyle.json
```

## SCHEMA.md Addition

### Workstyle Object Schema (v1)

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Schema version, `"1.0"` |
| `generated_at` | ISO string | When the analysis ran |
| `project` | string | Project name (or `"global"` for --global) |
| `project_slug` | string | URL-safe project identifier |
| `scope` | enum | `"project"` or `"global"` |
| `session_count` | integer | Number of sessions analysed |
| `session_range` | object | `{ earliest, latest }` ISO timestamps |
| `confidence` | enum | `"high"` (10+), `"medium"` (5-9), `"low"` (3-4) |
| `summary` | string | 2-3 sentence working style characterisation |
| `session_patterns` | object | Pattern percentages + dominant pattern |
| `tool_usage` | object | Tool counts, skill usage, agent types |
| `delegation` | object | Solo/delegated/team percentages |
| `communication` | object | Instruction style, feedback style |
| `session_shape` | object | Duration, exchanges, typical arc |
| `preferences` | object | Confirmed, detected, contradicted arrays |
| `evolution` | object | Trend description, pattern shifts |

## Error Handling

| Scenario | Behaviour |
|----------|-----------|
| < 3 sessions | Warn, proceed with `confidence: "low"`, all sections marked as low-confidence |
| 0 sessions | Error: "No session history found for {project}. Verify the project has Claude Code conversation history." |
| Corrupt JSONL lines | Skip, log count in completion display: "Skipped {N} malformed lines" |
| `--global` with no projects | Error: "No projects with session history found." |
| `--global` + `--no-export` | Valid: analyse all projects but only display results, no central export |

## Trigger Phrase Updates

Add to SKILL.md description:
```
"how do I use Claude", "my working style", "tool usage patterns", "session analysis",
"workstyle", "communication patterns", "delegation patterns"
```

## Integration Points

### `update_central_index()` (SKILL.md Step 5c)
Extend to detect `workstyle.md` / `workstyle.json` at project level and `workstyle-global.*` at top level. Add "Workstyle" indicator to project entries in INDEX.md.

### SUMMARY.md template (`output-templates.md` `{#summary}`)
Add optional "Workstyle Overview" section that pulls the summary string and dominant pattern from `workstyle.json` if it exists.

### `consumption-spec.md`
Add workstyle reading path:
```
5. Read({project}/workstyle.md)    → only if you need to understand the user's working style
6. Parse({project}/workstyle.json) → only if adapting behaviour to user preferences
```

### `update_local_archaeology_index()` (survey-workflow.md)
Extend to detect `workstyle.md` in the archaeology directory and add a link.
