# Conversation Parser Reference

> This file defines how to read and parse Claude Code JSONL conversation history files.
> Referenced by: `workstyle-workflow.md`, `survey-workflow.md`. Designed for reuse by future modes.

## JSONL Message Types

| Type | Workstyle Signal | Edge Cases |
|------|-----------------|------------|
| `user` | Instruction length, prompt specificity | **CRITICAL:** `type: "user"` includes tool results. Only `isinstance(content, str)` = human input. Without filtering, counts inflate ~6x. |
| `assistant` | Tool choices, response patterns | tool_use blocks at `.message.content[].type === "tool_use"` with `.name` |
| `progress` | Hook activity, session lifecycle | Includes hook_progress and agent_progress |
| `system` | Context/reminders | Not useful for workstyle |
| `file-history-snapshot` | Edit frequency | **No timestamps or sessionId.** Skip in duration calculations. |

## Per-Session Metadata Extraction

Parse each JSONL file and extract the following `session_meta` object:

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

## Implementation Notes

1. Agent spawning uses `Task` tool (NOT `Agent`). Detect: `tool_use.name === "Task"` with `"subagent_type" in input`.
2. Skip `file-history-snapshot` messages when computing timestamps — they have no timestamps or sessionId.
3. `slug` requires scanning multiple lines — not guaranteed on line 1. Default to `null` if absent.
4. Corrupt JSONL: skip malformed lines, log count of skipped lines.
5. Scan only top-level files (`{project-dir}/{uuid}.jsonl`), exclude `{uuid}/subagents/` directories.
6. Use full JSON parsing (not Grep) — only 1.5x slower but 100% accurate. Regex gets false positives from tool input fields.

## Aggregation Functions

These functions operate on an array of `session_meta` objects.

### `aggregate_tool_counts(sessions[])`

Merge all `tool_counts` across sessions into a single `{ tool_name: total_count }` map, sorted descending by count.

```javascript
function aggregate_tool_counts(sessions) {
  merged = {};
  for (session of sessions) {
    for ([tool, count] of Object.entries(session.tool_counts)) {
      merged[tool] = (merged[tool] || 0) + count;
    }
  }
  return Object.entries(merged)
    .sort((a, b) => b[1] - a[1])
    .reduce((obj, [k, v]) => ({ ...obj, [k]: v }), {});
}
```

### `aggregate_session_shapes(sessions[])`

Compute aggregate session shape metrics.

```javascript
function aggregate_session_shapes(sessions) {
  return {
    avg_duration: mean(sessions.map(s => s.duration_minutes)),
    avg_exchanges: mean(sessions.map(s => s.total_exchanges)),
    avg_tool_diversity: mean(sessions.map(s => Object.keys(s.tool_counts).length)),
    median_user_msg_length: median(sessions.flatMap(s => s.user_msg_lengths))
  };
}
```

### `compute_delegation_ratio(sessions[])`

Classify sessions by delegation level and compute percentages.

```javascript
function compute_delegation_ratio(sessions) {
  solo = sessions.filter(s => s.agent_spawn_count === 0 && s.team_operations === 0);
  delegated = sessions.filter(s => s.agent_spawn_count > 0 && s.team_operations === 0);
  team = sessions.filter(s => s.team_operations > 0);

  total = sessions.length;
  return {
    solo_pct: round(solo.length / total * 100),
    delegated_pct: round(delegated.length / total * 100),
    team_pct: round(team.length / total * 100),
    avg_agents_per_delegated_session: delegated.length > 0
      ? round(mean(delegated.map(s => s.agent_spawn_count)), 1)
      : 0
  };
}
```

### `compute_instruction_profile(sessions[])`

Characterise instruction style based on average message length.

```javascript
function compute_instruction_profile(sessions) {
  all_lengths = sessions.flatMap(s => s.user_msg_lengths);
  avg = mean(all_lengths);

  // Thresholds based on observed distributions
  style = avg < 100 ? 'short'
        : avg < 300 ? 'medium'
        : 'detailed';

  return {
    style: style,
    avg_length: round(avg),
    distribution: {
      short: round(all_lengths.filter(l => l < 100).length / all_lengths.length * 100),
      medium: round(all_lengths.filter(l => l >= 100 && l < 300).length / all_lengths.length * 100),
      detailed: round(all_lengths.filter(l => l >= 300).length / all_lengths.length * 100)
    }
  };
}
```

### `compute_evolution(sessions[])`

Split sessions into time windows and compare early vs recent metrics.

```javascript
function compute_evolution(sessions) {
  // sessions must be sorted by timestamp_start (ascending)
  if (sessions.length < 4) {
    return { trend: 'insufficient data', early_dominant_pattern: null, recent_dominant_pattern: null, delegation_trend: null };
  }

  midpoint = Math.floor(sessions.length / 2);
  early = sessions.slice(0, midpoint);
  recent = sessions.slice(midpoint);

  early_patterns = classify_dominant_pattern(early);
  recent_patterns = classify_dominant_pattern(recent);
  early_delegation = compute_delegation_ratio(early);
  recent_delegation = compute_delegation_ratio(recent);

  delegation_trend = recent_delegation.delegated_pct > early_delegation.delegated_pct + 10 ? 'increasing'
                   : recent_delegation.delegated_pct < early_delegation.delegated_pct - 10 ? 'decreasing'
                   : 'stable';

  trend = early_patterns.dominant !== recent_patterns.dominant
    ? `shifted from ${early_patterns.dominant} to ${recent_patterns.dominant}`
    : `consistently ${recent_patterns.dominant}`;

  return {
    trend: trend,
    early_dominant_pattern: early_patterns.dominant,
    recent_dominant_pattern: recent_patterns.dominant,
    delegation_trend: delegation_trend
  };
}
```

### `aggregate_skill_usage(sessions[])`

Collects all `skill_invocations` across sessions, counts frequency, returns sorted array of `{ name, count }`.

```javascript
function aggregate_skill_usage(sessions) {
  counts = {};
  for (session of sessions) {
    for (skill of session.skill_invocations) {
      counts[skill] = (counts[skill] || 0) + 1;
    }
  }
  return Object.entries(counts)
    .sort((a, b) => b[1] - a[1])
    .map(([name, count]) => ({ name, count }));
}
```

### `aggregate_agent_types(sessions[])`

Collects all `agent_types` across sessions, counts frequency, returns sorted array of `{ type, count }`.

```javascript
function aggregate_agent_types(sessions) {
  counts = {};
  for (session of sessions) {
    for (agent_type of session.agent_types) {
      counts[agent_type] = (counts[agent_type] || 0) + 1;
    }
  }
  return Object.entries(counts)
    .sort((a, b) => b[1] - a[1])
    .map(([type, count]) => ({ type, count }));
}
```

> `classify_session_pattern()` is defined in `references/workstyle-workflow.md` Step W3.

### `classify_dominant_pattern(sessions[])`

Called by `compute_evolution()` — wraps the per-session pattern classifier to find the dominant pattern across a group of sessions. Note: `classify_session_pattern()` is defined in `workstyle-workflow.md` — reference it, don't redefine.

```javascript
// Requires classify_session_pattern() from workstyle-workflow.md
function classify_dominant_pattern(sessions) {
  pattern_counts = {};
  for (session of sessions) {
    pattern = classify_session_pattern(session);  // defined in workstyle-workflow.md
    pattern_counts[pattern] = (pattern_counts[pattern] || 0) + 1;
  }
  dominant = Object.entries(pattern_counts).sort((a, b) => b[1] - a[1])[0];
  return { dominant: dominant[0], counts: pattern_counts };
}
```

## Agent Output Format Convention

All sub-agent prompts that return structured data for programmatic parsing MUST use XML tags. This convention applies to any `Agent()` call where the orchestrator extracts fields from the response.

### When to use XML tags

| Use XML | Do NOT use XML |
|---------|----------------|
| Sub-agent returns structured fields parsed by `extract_xml_field()` | JSON object output (e.g. S2 sub-agent returning `{ "keyword": count }`) |
| | JSONL conversation files |
| | YAML frontmatter in domain definitions |
| | Markdown table contracts (survey.md) |
| | Shell script output (excavation manifest) |
| | Human-readable display templates (output-templates.md) |

### Format rules

| Case | Format |
|------|--------|
| Short single-line value | `<field_name>value</field_name>` |
| Value with embedded label | `<field_name>label — description</field_name>` |
| Multi-line prose body | `<body>paragraph text here...</body>` |
| Absent / not applicable | `<field_name>none</field_name>` (not empty tags, not omitted) |

- Field names use `snake_case` to match the JavaScript variable names they map to.
- Parse with `extract_xml_field()` defined below in Utility Functions.

### Agent prompt template

Include this instruction block at the end of every agent prompt that expects structured output:

```
Return ONLY the XML tags below — no prose, no headers, no explanation outside the tags. Do NOT use KEY: value format.
<field_one>[description]</field_one>
<field_two>[description]</field_two>
```

### Active usages

- **Survey S5** (`survey-workflow.md`): `<theme>`, `<summary>`
- **Workstyle W5** (`workstyle-workflow.md`): `<instruction_style>`, `<feedback_style>`, `<session_arc>`, `<complexity_approach>`, `<notable_pattern>`
- **Dig D5** (`dig-workflow.md`): `<nugget>` containing `<what>`, `<why>`, `<confidence>`, `<weight>`, `<tags>`, `<source_session>`, `<source_range>`
- **Dig D6** (`dig-workflow.md`): `<vein>` containing `<nugget_a>`, `<nugget_b>`, `<link_type>`, `<direction>`, `<bridge>`, `<narrative>`, `<confidence>`

## Utility Functions

### `extract_session_metadata(file)`

Reads a single JSONL conversation file and returns a `session_meta` object. Referenced in `workstyle-workflow.md` W2 as the canonical per-file parse step.

```javascript
TEAM_TOOLS = ['TeamCreate', 'SendMessage', 'SendBroadcast'];

function extract_session_metadata(file) {
  lines = readFileLines(file);
  messages = [];
  skipped = 0;

  for (line of lines) {
    try {
      msg = JSON.parse(line);
      if (msg.type === 'file-history-snapshot') continue;  // no timestamps or sessionId
      messages.push(msg);
    } catch {
      skipped++;
    }
  }

  // Identity — slug is optional, scan all messages
  session_id = messages.find(m => m.sessionId)?.sessionId ?? null;
  slug       = messages.find(m => m.slug)?.slug ?? null;
  cwd        = messages.find(m => m.cwd)?.cwd ?? null;
  version    = messages.find(m => m.version)?.version ?? null;

  // Timestamps — use non-snapshot messages only (already filtered above)
  timestamps = messages.map(m => m.timestamp).filter(Boolean).sort();
  timestamp_start = timestamps[0] ?? null;
  timestamp_end   = timestamps[timestamps.length - 1] ?? null;
  duration_minutes = (timestamp_start && timestamp_end)
    ? (new Date(timestamp_end) - new Date(timestamp_start)) / 60000
    : 0;

  // Human messages: content must be a plain string (not an array of tool results)
  human_messages = messages.filter(m => m.type === 'user' && typeof m.message?.content === 'string');
  user_msg_lengths = human_messages.map(m => m.message.content.length);
  user_message_count = human_messages.length;
  avg_user_msg_length = user_message_count > 0 ? mean(user_msg_lengths) : 0;

  // Assistant messages and tool_use blocks
  assistant_messages = messages.filter(m => m.type === 'assistant');
  assistant_message_count = assistant_messages.length;

  tool_counts = {};
  skill_invocations = [];
  agent_types = [];
  agent_spawn_count = 0;
  team_operations = 0;
  plan_mode_exits = 0;

  for (msg of assistant_messages) {
    content_blocks = msg.message?.content ?? [];
    for (block of content_blocks) {
      if (block.type !== 'tool_use') continue;
      tool_counts[block.name] = (tool_counts[block.name] || 0) + 1;

      if (block.name === 'Skill' && block.input?.skill) {
        skill_invocations.push(block.input.skill);
      }
      if (block.name === 'Task' && block.input?.subagent_type) {
        agent_types.push(block.input.subagent_type);
        agent_spawn_count++;
      }
      if (TEAM_TOOLS.includes(block.name)) {
        team_operations++;
      }
      if (block.name === 'ExitPlanMode') {
        plan_mode_exits++;
      }
    }
  }

  return {
    session_id,
    slug,
    cwd,
    version,
    timestamp_start,
    timestamp_end,
    duration_minutes,
    user_message_count,
    assistant_message_count,
    total_exchanges: user_message_count,
    user_msg_lengths,
    avg_user_msg_length,
    tool_counts,
    skill_invocations,
    agent_types,
    agent_spawn_count,
    team_operations,
    plan_mode_exits,
    file_path: file
  };
}
```

### `extract_xml_field(text, field_name)`

Extracts the content between `<field_name>` and `</field_name>` XML tags in agent output. Canonical helper for parsing structured sub-agent responses. Returns `null` if the tag is not found.

```javascript
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

### `extract_after(text, label)` *(deprecated)*

> **Deprecated:** Use `extract_xml_field()` instead. All agent prompts now use XML output format. This function is retained for one release cycle in case any inline prompts were missed.

Returns the remainder of `text` after the first occurrence of `label`, trimmed to the first non-empty line.

```javascript
function extract_after(text, label) {
  idx = text.indexOf(label);
  if (idx === -1) return null;
  remainder = text.slice(idx + label.length);
  first_line = remainder.split('\n').find(l => l.trim() !== '');
  return first_line ? first_line.trim() : null;
}
```

### `max_by(array, fn)`

Returns the element of `array` that maximises `fn(element)`. Returns `undefined` for empty arrays.

```javascript
function max_by(array, fn) {
  if (array.length === 0) return undefined;
  return array.reduce((best, el) => fn(el) > fn(best) ? el : best, array[0]);
}
```

### `min_by(array, fn)`

Returns the element of `array` that minimises `fn(element)`. Returns `undefined` for empty arrays.

```javascript
function min_by(array, fn) {
  if (array.length === 0) return undefined;
  return array.reduce((best, el) => fn(el) < fn(best) ? el : best, array[0]);
}
```

### `unique_by(array, fn)`

Deduplicates `array`, keeping the first occurrence of each distinct `fn(element)` value.

```javascript
function unique_by(array, fn) {
  seen = new Set();
  result = [];
  for (el of array) {
    key = fn(el);
    if (!seen.has(key)) {
      seen.add(key);
      result.push(el);
    }
  }
  return result;
}
```
