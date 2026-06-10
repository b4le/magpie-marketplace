# Workstyle Workflow Reference

> This file is referenced from `SKILL.md`. It defines the full workstyle workflow (Steps W1-W7).
> Context variables (`PROJECT_NAME`, `PROJECT_SLUG`, `ARCHAEOLOGY_DIR`, `CENTRAL_BASE`, etc.) are set by SKILL.md Step 1 / routing logic before this workflow executes.

## Workstyle Workflow

When workstyle mode is triggered, execute these steps instead of the domain extraction workflow.

### Workstyle Step W1: Resolve Project Context

Standard project resolution (shared with survey/domain). Additional flags for workstyle:

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
  if (user_provided_project_name) {
    PROJECT_NAME = user_provided_project_name;
    PROJECT_PATH_PATTERN = `**/${PROJECT_NAME}/**`;
    matching_paths = Glob(pattern: PROJECT_PATH_PATTERN, path: ~/Developer);
    if (matching_paths.length === 0) {
      error("Project not found in ~/Developer");
    }
    PROJECT_ROOT = matching_paths[0];
    HISTORY_DIR = `~/.claude/projects/-Users-*-${PROJECT_PATH_PATTERN}/`;
  } else {
    PROJECT_ROOT = cwd;
    PROJECT_NAME = basename(PROJECT_ROOT);
    encoded_path = PROJECT_ROOT.replace(/\//g, '-');
    HISTORY_DIR = `~/.claude/projects/${encoded_path}/`;
  }

  PROJECT_SLUG = PROJECT_NAME.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  ARCHAEOLOGY_DIR = `${PROJECT_ROOT}/.claude/archaeology`;
  WORKSTYLE_LOCAL_PATH = `${ARCHAEOLOGY_DIR}/workstyle.md`;
  WORKSTYLE_JSON_PATH = `${ARCHAEOLOGY_DIR}/workstyle.json`;
  CENTRAL_PROJECT_DIR = `${CENTRAL_BASE}/${PROJECT_SLUG}`;
}

// Ensure directories exist
if (!GLOBAL_MODE) {
  mkdir -p ${ARCHAEOLOGY_DIR}
  if (!NO_EXPORT) mkdir -p ${CENTRAL_PROJECT_DIR}
}
```

**`--global` project discovery:**
Scan `~/.claude/projects/` for encoded project paths. Each directory maps to a project via its encoding (e.g., `-Users-username-Projects-myproject` → `/Users/username/Projects/myproject`). Aggregate sessions across all discovered projects.

### Workstyle Step W2: Metadata Pass (Fast — All Sessions)

Parse all JSONL files using **full JSON parsing** (not Grep). Extract `session_meta` per the conversation-parser spec.

> See `references/conversation-parser.md` for JSONL parsing specification and the `session_meta` object definition.

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

**Performance:** ~540 top-level sessions across all projects parses in ~3.6 seconds. No batching needed.

### Workstyle Step W3: Dimension Scoring

Compute each workstyle dimension from aggregated metadata.

> See `references/conversation-parser.md` for aggregation function definitions.

**Session pattern classification:**

| Pattern | Detection Rule |
|---------|---------------|
| Plan-first | `ExitPlanMode` in session's tool list (plan mode was entered and exited) |
| Iterative refinement | `user_message_count / total_tool_calls > 0.3` (high back-and-forth ratio) |
| Deep exploration | `(Read + Grep + Glob count) / (Edit + Write count) > 3` (more reading than writing) |
| Delegation-heavy | `agent_spawn_count > 3` per session |
| Direct execution | `user_message_count < 5` AND `total_tool_calls > 10` (short instructions, lots of action) |

Each session gets classified into its primary pattern. Sessions can match multiple patterns — take the strongest signal.

```javascript
function classify_session_pattern(session) {
  scores = {};
  tc = session.tool_counts;

  // Plan-first
  if (tc['ExitPlanMode'] > 0) scores['plan_first'] = 3;

  // Iterative refinement
  total_tools = Object.values(tc).reduce((a, b) => a + b, 0);
  if (total_tools > 0 && session.user_message_count / total_tools > 0.3) {
    scores['iterative_refinement'] = 2;
  }

  // Deep exploration
  read_ops = (tc['Read'] || 0) + (tc['Grep'] || 0) + (tc['Glob'] || 0);
  write_ops = (tc['Edit'] || 0) + (tc['Write'] || 0);
  if (write_ops > 0 && read_ops / write_ops > 3) scores['deep_exploration'] = 2;
  if (write_ops === 0 && read_ops > 5) scores['deep_exploration'] = 3;

  // Delegation-heavy
  if (session.agent_spawn_count > 3) scores['delegation_heavy'] = 2;

  // Direct execution
  if (session.user_message_count < 5 && total_tools > 10) scores['direct_execution'] = 2;

  // Return pattern with highest score, default to iterative_refinement
  if (Object.keys(scores).length === 0) return 'iterative_refinement';
  return Object.entries(scores).sort((a, b) => b[1] - a[1])[0][0];
}

// Classify all sessions
session_patterns = {};
for (session of all_sessions) {
  pattern = classify_session_pattern(session);
  session_patterns[pattern] = (session_patterns[pattern] || 0) + 1;
}

// Compute percentages
total = all_sessions.length;
pattern_pcts = {};
for ([pattern, count] of Object.entries(session_patterns)) {
  pattern_pcts[pattern] = round(count / total * 100);
}
dominant_pattern = Object.entries(session_patterns).sort((a, b) => b[1] - a[1])[0][0];
```

**Preference detection:**

Cross-reference observed patterns with `~/.claude/CLAUDE.md` rules and `~/.claude/settings.json` config:

```javascript
function detect_preferences(all_sessions, claude_md_content) {
  confirmed = [];   // pattern matches a CLAUDE.md rule
  detected = [];    // consistent pattern NOT in CLAUDE.md
  contradicted = []; // CLAUDE.md rule exists but sessions show the opposite

  // Example detection rules:
  // - If CLAUDE.md mentions "worktree" and sessions show EnterWorktree usage → confirmed
  // - If sessions consistently use Plan-first but CLAUDE.md doesn't mention it → detected
  // - If CLAUDE.md says "never auto-commit" but sessions show frequent commit tool calls → contradicted

  return { confirmed, detected, contradicted };
}
```

**Aggregate dimension scores:**

```javascript
// Use aggregation functions from conversation-parser.md
tool_agg = aggregate_tool_counts(all_sessions);
shapes = aggregate_session_shapes(all_sessions);
delegation = compute_delegation_ratio(all_sessions);
instruction = compute_instruction_profile(all_sessions);
evolution = compute_evolution(all_sessions);

// Confidence scoring
confidence = confidence_override
  || (all_sessions.length >= 10 ? 'high'
    : all_sessions.length >= 5 ? 'medium'
    : 'low');
```

### Workstyle Step W4: Sampling Selection

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

### Workstyle Step W5: Sub-Agent Deep-Dives

Spawn Explore agents for sampled sessions. Each agent reads one JSONL file and returns structured analysis.

**Output contract:** Agents return ONLY the structured format below. No raw session content.

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

Return ONLY the XML tags below — no prose, no headers, no explanation outside the tags. Do NOT use KEY: value format.
<instruction_style>[short|medium|detailed] — [one sentence]</instruction_style>
<feedback_style>[approve-quickly|review-carefully|redirect-often] — [one sentence]</feedback_style>
<session_arc>[linear|branching|exploratory] — [one sentence]</session_arc>
<complexity_approach>[decompose|delegate|direct] — [one sentence]</complexity_approach>
<notable_pattern>[any distinctive behaviour worth surfacing, or "none"]</notable_pattern>`
  });
}

// ADDITIONAL sub-agents may be spawned if W3 dimension scoring reveals
// areas needing investigation (e.g., unusual tool usage spikes, unexpected
// delegation ratios). This is responsive to data, not a fixed count.
```

**Parse sub-agent responses:**

```javascript
deep_dive_results = [];
for (result of agent_results) {
  deep_dive_results.push({
    instruction_style: extract_xml_field(result, 'instruction_style'),
    feedback_style: extract_xml_field(result, 'feedback_style'),
    session_arc: extract_xml_field(result, 'session_arc'),
    complexity_approach: extract_xml_field(result, 'complexity_approach'),
    notable_pattern: extract_xml_field(result, 'notable_pattern')
  });
}
```

### Workstyle Step W6: Generate Outputs

Assemble all data into `workstyle.md` and `workstyle.json`.

> See `output-templates.md#workstyle` for `workstyle.md` template.
> See `SCHEMA.md` "Workstyle Object Schema (v1)" for `workstyle.json` structure.

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

**Build `workstyle.json`:**

```javascript
workstyle_json = {
  version: "1.0",
  generated_at: new Date().toISOString(),
  project: GLOBAL_MODE ? "global" : PROJECT_NAME,
  project_slug: GLOBAL_MODE ? "global" : PROJECT_SLUG,
  scope: GLOBAL_MODE ? "global" : "project",
  session_count: all_sessions.length,
  session_range: {
    earliest: all_sessions[0].timestamp_start,
    latest: all_sessions[all_sessions.length - 1].timestamp_end
  },
  confidence: confidence,
  summary: "", // Synthesized from W3 + W5

  session_patterns: {
    ...Object.fromEntries(
      Object.entries(pattern_pcts).map(([k, v]) => [`${k}_pct`, v / 100])
    ),
    dominant_pattern: dominant_pattern
  },

  tool_usage: {
    total_tool_calls: Object.values(tool_agg).reduce((a, b) => a + b, 0),
    unique_tools: Object.keys(tool_agg).length,
    top_tools: Object.entries(tool_agg).slice(0, 15).map(([name, count]) => ({
      name, count,
      pct: round(count / Object.values(tool_agg).reduce((a, b) => a + b, 0), 3)
    })),
    skill_usage: aggregate_skill_usage(all_sessions),
    agent_types: aggregate_agent_types(all_sessions)
  },

  delegation: delegation,

  communication: {
    instruction_style: instruction.style,
    avg_instruction_length: instruction.avg_length,
    feedback_style: synthesize_feedback_style(deep_dive_results),
    correction_frequency: synthesize_correction_frequency(deep_dive_results)
  },

  session_shape: {
    avg_duration_minutes: round(shapes.avg_duration),
    avg_exchanges: round(shapes.avg_exchanges),
    avg_tool_calls_per_session: round(
      Object.values(tool_agg).reduce((a, b) => a + b, 0) / all_sessions.length
    ),
    typical_arc: synthesize_typical_arc(deep_dive_results)
  },

  preferences: detect_preferences(all_sessions, claude_md_content),

  evolution: evolution
};
```

#### Synthesis Helper Functions

```javascript
function synthesize_feedback_style(deep_dive_results) {
  // Tally feedback styles from sub-agent deep-dives
  style_counts = {};
  for (result of deep_dive_results) {
    style = result.feedback_style.split(' — ')[0].trim();  // e.g. "review-carefully"
    style_counts[style] = (style_counts[style] || 0) + 1;
  }
  // Return the most common style
  return Object.entries(style_counts).sort((a, b) => b[1] - a[1])[0]?.[0] || 'unknown';
}

function synthesize_correction_frequency(deep_dive_results) {
  // Derive from feedback style distribution
  redirect_count = deep_dive_results.filter(r =>
    r.feedback_style.includes('redirect-often')
  ).length;
  ratio = redirect_count / deep_dive_results.length;
  return ratio > 0.5 ? 'frequent' : ratio > 0.2 ? 'moderate' : 'rare';
}

function synthesize_typical_arc(deep_dive_results) {
  // Tally session arcs from sub-agent deep-dives
  arc_counts = {};
  for (result of deep_dive_results) {
    arc = result.session_arc.split(' — ')[0].trim();  // e.g. "branching"
    arc_counts[arc] = (arc_counts[arc] || 0) + 1;
  }
  dominant_arc = Object.entries(arc_counts).sort((a, b) => b[1] - a[1])[0]?.[0] || 'linear';

  // Map to descriptive arc string
  ARC_DESCRIPTIONS = {
    'linear': 'context → implement → verify',
    'branching': 'context → explore options → decide → implement → verify',
    'exploratory': 'explore → discover → refine → sometimes implement'
  };
  return ARC_DESCRIPTIONS[dominant_arc] || dominant_arc;
}
```

**Generate `workstyle.md`** using the `{#workstyle}` template from `output-templates.md`, filling in all fields from `workstyle_json` and `deep_dive_results`.

```javascript
// Write local outputs (unless --global, which has no local project)
if (!GLOBAL_MODE) {
  Write(WORKSTYLE_LOCAL_PATH, workstyle_md_content);
  Write(WORKSTYLE_JSON_PATH, JSON.stringify(workstyle_json, null, 2));
}
```

### Workstyle Step W7: Export + Index Updates

> `update_central_index()` — see SKILL.md Step 5c (do not redefine here).
> `update_local_archaeology_index()` — see `references/survey-workflow.md` (do not redefine here).

```javascript
if (!NO_EXPORT) {
  if (GLOBAL_MODE) {
    Write(CENTRAL_GLOBAL_PATH, workstyle_md_content);
    Write(CENTRAL_GLOBAL_JSON, JSON.stringify(workstyle_json, null, 2));
  } else {
    // Write to central project directory (sibling to survey.md and SUMMARY.md)
    Write(`${CENTRAL_PROJECT_DIR}/workstyle.md`, workstyle_md_content);
    Write(`${CENTRAL_PROJECT_DIR}/workstyle.json`, JSON.stringify(workstyle_json, null, 2));
  }

  // Update central INDEX.md
  update_central_index();  // Existing function (SKILL.md Step 5c)
}

// Always update local index (unless --global, which has no local project)
if (!GLOBAL_MODE) {
  update_local_archaeology_index();  // Existing function (survey-workflow.md)
}
```

### Workstyle Error Handling

| Scenario | Behaviour |
|----------|-----------|
| < 3 sessions | Warn, proceed with `confidence: "low"`, all sections marked as low-confidence |
| 0 sessions | Error: "No session history found for {project}. Verify the project has Claude Code conversation history." |
| Corrupt JSONL lines | Skip, log count in completion display: "Skipped {N} malformed lines" |
| `--global` with no projects | Error: "No projects with session history found." |
| `--global` + `--no-export` | Valid: analyse all projects but only display results, no central export |

### Workstyle Completion Criteria

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

### Workstyle Completion Display

**MUST use the exact template from `output-templates.md#workstyle-completion`.** Do not reformat, add tables, add emoji, or alter the structure.

Key variable mappings:
- `{session_count}` — from W2 metadata pass
- `{date_range}` — `{earliest_date} → {latest_date}` from session metadata
- `{confidence}` — from session count thresholds (10+ = high, 5-9 = medium, 3-4 = low)
- `{dominant_pattern}`, `{dominant_pct}` — from W3 session_patterns.dominant_pattern
- Top tools — from W3 tool_usage, top 3 by count
- Delegation — from W3 delegation_patterns percentages
- `{PROJECT_SLUG}` — from W1

See `output-templates.md#workstyle-completion` for `--no-export` and `--global` variant rules.
