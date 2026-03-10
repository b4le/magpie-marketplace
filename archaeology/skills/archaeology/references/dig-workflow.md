# Dig Workflow Reference

> Version: 1.0
> Deep investigation of a specific subject across project session history.
> Referenced by: `SKILL.md` command router (`dig` branch). Executed when `/archaeology dig "subject"` is invoked.
> Context variables (`PROJECT_NAME`, `PROJECT_SLUG`, `ARCHAEOLOGY_DIR`, `CENTRAL_OUTPUT_DIR`, etc.) are set by SKILL.md Step 1 / routing logic before this workflow executes.
> Path variables `SKILL_DIR` and `PLUGIN_ROOT` are set by SKILL.md Path Resolution before this workflow executes.

---

## State Model

### Path Variables

```javascript
STATE_DIR    = `${ARCHAEOLOGY_DIR}/spelunk/${subject_slug}`;
CAVERN_MAP   = `${STATE_DIR}/cavern-map.json`;
NUGGETS_DIR  = `${STATE_DIR}/nuggets`;
LOCK_FILE    = `${STATE_DIR}/.lock`;
```

`subject_slug` is derived from the user-provided subject string: lowercase, non-alphanumeric runs replaced with hyphens, leading and trailing hyphens stripped.

```javascript
subject_slug = subject.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
```

### Files

| File | Description |
|------|-------------|
| `cavern-map.json` | Tree structure and decision log. Primary state file. |
| `nuggets/nug-NNN.md` | Individual findings with YAML frontmatter and markdown body. Written once, never mutated. |
| `veins.json` | All connections between nuggets, as a flat array. |
| `trove.md` | Human-readable accumulated treasure. Regenerated from nuggets + veins each cycle -- never appended to directly. Treat as a read artefact, not a source of truth. |

### Initialization

On first dig for a subject, create the state directory and seed files:

```bash
mkdir -p ${STATE_DIR}/nuggets
echo '[]' > ${STATE_DIR}/veins.json
```

### Concurrency Lock Lifecycle

The `.lock` file guards against two sessions writing state simultaneously. Write the lock **before** the init/resume branch point -- both paths must be protected.

```javascript
// Write lock before init/resume branch
mkdir -p ${STATE_DIR}
echo "locked $(date -u +%Y-%m-%dT%H:%M:%SZ)" > ${LOCK_FILE}

// D5-D7 wrapped in try/finally for cleanup
try {
  // ... D5, D6, D7 ...
} finally {
  remove(LOCK_FILE);
}
```

If the lock file exists at invocation start, warn:

```
Warning: A lock file exists at spelunk/{subject-slug}/.lock.
Another session may be active. If not, delete the lock file and retry.
```

Do not auto-remove stale locks. Manual removal is required.

### Resumption Logic

When `/archaeology dig "subject"` is invoked, resolve the subject slug and check for an existing cavern map before doing anything else.

If `cavern-map.json` exists:
- **Resume mode** -- load the existing cavern map, display orientation, skip to D4 resume.

If `cavern-map.json` does not exist:
- **Init mode** -- run the full reconnaissance pipeline (D2-D3), then present in D4.

The `--fresh` flag discards existing state before the existence check and proceeds as init mode. If `total_nuggets > 0`, prompt the user for confirmation before discarding.

### Atomic Writes

Write `cavern-map.json` and `veins.json` atomically: output goes to a `.tmp` file first, then rename into place. Mid-write corruption would make the entire dig unresumable.

```bash
# Pattern for all JSON state files
write_to  "${FILE_PATH}.tmp"
mv        "${FILE_PATH}.tmp" "${FILE_PATH}"
```

Nugget files (`nug-NNN.md`) are written once and never mutated -- atomic write is not required.

### Selective Reads on Resume

To avoid inflating the session context on every resume, reads are selective:

| What | When |
|------|------|
| `cavern-map.json` | Always -- on every invocation |
| Nuggets for the active tunnel only | On resume, before dispatching spelunkers |
| First 50 lines of `trove.md` | On resume, for orientation |
| Full nugget set | Only when user explicitly requests synthesis or `--done` flag |

### Size Guards

| Condition | Action |
|-----------|--------|
| > 20 open tunnels | Warn: "The cavern map has more than 20 open tunnels. Consider closing low-priority branches before continuing." |
| > 100 total nuggets | Warn: "100 nuggets reached. Consider running `--done` to seal and archive this dig, or review whether tunnels are too broad." |
| 2 consecutive cycles with 0 new nuggets from a tunnel | Automatically mark tunnel as `exhausted`. Log the transition in the decision log. |

---

## Dig Step D1: Resolve Context and Check State

Reuses the standard project resolution logic shared by all archaeology modes (survey S1, conservation C1). Sets `PROJECT_ROOT`, `PROJECT_SLUG`, `ARCHAEOLOGY_DIR`, and `CENTRAL_OUTPUT_DIR`. Then checks for existing dig state to select the execution path.

### Project resolution

```javascript
NO_EXPORT = args.includes('--no-export');

// Standard project resolution (same as S1, C1, W1)
if (user_provided_project_name) {
  PROJECT_NAME = user_provided_project_name;
  PROJECT_PATH_PATTERN = `**/${PROJECT_NAME}/**`;
  matching_paths = Glob(pattern: PROJECT_PATH_PATTERN, path: ~/Developer);
  if (matching_paths.length === 0) error("Project not found in ~/Developer");
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
CENTRAL_BASE = `~/.claude/data/visibility-toolkit/work-log/archaeology`;
CENTRAL_OUTPUT_DIR = `${CENTRAL_BASE}/${PROJECT_SLUG}`;
```

**Sandbox detection** -- same pattern as S1. Test write access to `CENTRAL_BASE`; if blocked, set `NO_EXPORT = true` and warn:

```javascript
if (!NO_EXPORT) {
  try {
    Bash(`mkdir -p ${CENTRAL_BASE}/.sandbox-test && rmdir ${CENTRAL_BASE}/.sandbox-test`);
  } catch (e) {
    NO_EXPORT = true;
    display("Sandbox mode detected -- central export is not available.");
    display("Running in local-only mode (equivalent to --no-export).");
  }
}
```

### State path variables

Set path variables using the subject slug:

```javascript
subject_slug = subject.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

STATE_DIR    = `${ARCHAEOLOGY_DIR}/spelunk/${subject_slug}`;
CAVERN_MAP   = `${STATE_DIR}/cavern-map.json`;
NUGGETS_DIR  = `${STATE_DIR}/nuggets`;
LOCK_FILE    = `${STATE_DIR}/.lock`;
```

### Execution path selection

Evaluate flags and existing state in this order:

```javascript
flag_fresh  = args.includes('--fresh');
flag_done   = args.includes('--done');
flag_export = args.includes('--export');

existing_state = exists(CAVERN_MAP);
lock_present   = exists(LOCK_FILE);

// 1. Lock warning (warn only -- do not abort)
if (lock_present) {
  warn(`Lock file found at ${LOCK_FILE}. A concurrent dig session may be active.`);
  warn(`Remove the lock manually if this is stale, or use a different terminal.`);
}

// 2. Flag-driven shortcuts
if (flag_done) {
  // Skip to D-final -- export and wrap up
  goto D_FINAL;
}
if (flag_export) {
  // Export current state to central, then done
  goto D_FINAL;
}

// 3. Write lock BEFORE init/resume branch -- both paths are protected
mkdir -p ${STATE_DIR}
echo "locked $(date -u +%Y-%m-%dT%H:%M:%SZ)" > ${LOCK_FILE}

// 4. Resume path
if (existing_state && !flag_fresh) {
  cavern_map = JSON.parse(Read(CAVERN_MAP));

  // Schema version check -- must be "1.0"
  if (cavern_map.schema_version !== "1.0") {
    remove(LOCK_FILE);
    error(`Unsupported schema version: ${cavern_map.schema_version}. Expected "1.0".`);
  }

  goto D4_RESUME;
}

// 5. Init path -- fresh start (no existing state, or --fresh was passed)
if (flag_fresh && existing_state) {
  // --fresh confirmation guard
  cavern_map_temp = JSON.parse(Read(CAVERN_MAP));
  if (cavern_map_temp.total_nuggets > 0) {
    confirm(`Existing dig has ${cavern_map_temp.total_nuggets} nuggets. Discard and start fresh?`);
  }
  // Discard prior state
  remove(LOCK_FILE);
  Bash(`rm -rf ${STATE_DIR}`);
  display(`Discarded existing state for subject: ${subject}`);
  // Re-create state dir and lock
  mkdir -p ${STATE_DIR}
  echo "locked $(date -u +%Y-%m-%dT%H:%M:%SZ)" > ${LOCK_FILE}
}

// 6. Initialize nuggets directory and veins.json
mkdir -p ${NUGGETS_DIR}
echo '[]' > ${STATE_DIR}/veins.json

// Proceed to D2
```

**Verification checkpoint:** `HISTORY_DIR` must resolve to at least one `.jsonl` file. If 0 conversation files are found, remove the lock and exit with:

```
No session history found for '{PROJECT_NAME}'. Run /archaeology survey first.
```

Verify output directories exist:

```bash
mkdir -p ${ARCHAEOLOGY_DIR}
if (!NO_EXPORT) {
  mkdir -p ${CENTRAL_OUTPUT_DIR}
}
```

---

## Dig Step D2: Subject Expansion and Session Scanning

Lightweight reconnaissance -- no agents. Uses Grep and jq operations only to protect the main context window.

### Term expansion

Take the user's subject string and generate a broader search vocabulary using the fixed expansion table. If the seed term matches a table key, use the full expansion. Otherwise fall back to the seed term alone.

```javascript
seed_term = subject;

EXPANSION_TABLE = {
  'auth':        ['auth', 'authentication', 'authorization', 'OAuth', 'token', 'login', 'session', 'JWT', 'OIDC', 'credential'],
  'deploy':      ['deploy', 'deployment', 'release', 'CI', 'CD', 'pipeline', 'rollout', 'ship', 'publish', 'artifact'],
  'test':        ['test', 'testing', 'spec', 'jest', 'pytest', 'coverage', 'assert', 'mock', 'fixture', 'e2e'],
  'api':         ['api', 'endpoint', 'REST', 'GraphQL', 'request', 'response', 'route', 'handler', 'controller', 'swagger'],
  'db':          ['db', 'database', 'query', 'migration', 'schema', 'ORM', 'SQL', 'postgres', 'mysql', 'sqlite'],
  'cache':       ['cache', 'caching', 'Redis', 'Memcached', 'invalidation', 'TTL', 'eviction', 'warm', 'hit', 'miss'],
  'performance': ['performance', 'latency', 'throughput', 'profiling', 'benchmark', 'slow', 'optimise', 'N+1', 'bottleneck', 'timeout'],
  'error':       ['error', 'exception', 'failure', 'crash', 'bug', 'stack trace', 'panic', 'retry', 'fallback', 'recovery']
};

if (EXPANSION_TABLE[seed_term.toLowerCase()]) {
  expanded_terms = EXPANSION_TABLE[seed_term.toLowerCase()];
} else {
  expanded_terms = [seed_term];
  note("No fixed expansion for this subject. Results may be narrow. Consider enriching manually.");
}
```

### Survey enrichment

If `survey.md` exists for the project, scan it for domain rows matching the subject slug. Extract primary keywords from the matching domain definition and add to `expanded_terms`:

```javascript
survey_path = `${ARCHAEOLOGY_DIR}/survey.md`;
if (exists(survey_path)) {
  survey_content = Read(survey_path);
  // Find domain rows whose domain ID or name partially matches subject_slug
  matching_domain_row = survey_content
    .split('\n')
    .find(line => line.includes('|') && line.toLowerCase().includes(subject_slug));

  if (matching_domain_row) {
    domain_id = matching_domain_row.split('|')[1].trim();
    domain_def_path = `${SKILL_DIR}/references/domains/${domain_id}.md`;
    if (exists(domain_def_path)) {
      domain_def = Read(domain_def_path);
      domain_keywords = parse_frontmatter(domain_def).keywords;
      for (kw of domain_keywords.primary) {
        if (!expanded_terms.includes(kw)) expanded_terms.push(kw);
      }
    }
  }
}
```

### Domain findings enrichment

If `findings.json` exists for a domain whose keywords overlap with the subject, read its high-confidence highlights as seed context for D4 display:

```javascript
findings_path = `${ARCHAEOLOGY_DIR}/${subject_slug}/findings.json`;
if (!exists(findings_path)) {
  findings_path = `${CENTRAL_OUTPUT_DIR}/${subject_slug}/findings.json`;
}

HAS_PRIOR_FINDINGS = exists(findings_path);
if (HAS_PRIOR_FINDINGS) {
  prior_findings = JSON.parse(Read(findings_path));
  SEED_HIGHLIGHTS = prior_findings.findings
    .filter(f => f.confidence === 'high')
    .slice(0, 5)
    .map(f => f.title);
} else {
  SEED_HIGHLIGHTS = [];
}
```

### Session scoring

Score every conversation file against the expanded term list using jq-filtered JSONL. Filtering through the conversation parser is mandatory -- raw Grep on JSONL produces inflated counts from tool definitions, system prompts, and `tool_result` blocks.

```javascript
JQ_FILTER_PATH = `${SKILL_DIR}/references/jsonl-filter.jq`;
conversation_files = Glob(`${HISTORY_DIR}/**/*.jsonl`);

PRIMARY_CAP   = 5;  // per session, per term
SECONDARY_CAP = 3;

session_scores = [];

for (file of conversation_files) {
  per_term_hits = {};
  total_score   = 0;

  for (term of expanded_terms) {
    // Pipe file through jq filter, count case-insensitive keyword matches
    // jq -r -f "$JQ_FILTER_PATH" "$file" 2>/dev/null | grep -oi "\b${term}\b" | wc -l
    raw_count  = count_filtered(file, term, JQ_FILTER_PATH);
    capped     = Math.min(raw_count, PRIMARY_CAP);
    total_score += capped;
    if (raw_count > 0) per_term_hits[term] = capped;
  }

  if (total_score > 0) {
    session_mtime = stat(file).mtime;
    session_scores.push({
      file:  file,
      score: total_score,
      hits:  per_term_hits,
      date:  format_date(session_mtime)
    });
  }
}

// Rank by score descending
session_scores.sort((a, b) => b.score - a.score);
```

**Zero-hit guard:** If `session_scores.length === 0`, remove the lock file and exit with:

```
No sessions found matching '{subject}'. Try a different subject or run /archaeology survey first.
```

---

## Dig Step D3: Tunnel Generation

Groups ranked sessions into named investigation branches (tunnels) based on shared keyword signal. A tunnel is a coherent cluster of sessions where the same subset of expanded terms recurs together.

### Cluster formation

Build a term co-occurrence profile for each session. Take the top 3 terms by hit count as the session's cluster signature, then group sessions by signature:

```javascript
for (session of session_scores) {
  top_terms = Object.entries(session.hits)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([term]) => term);
  session.cluster_signature = top_terms.join('+');
}

clusters = {};
for (session of session_scores) {
  sig = session.cluster_signature;
  if (!clusters[sig]) {
    clusters[sig] = {
      signature:   sig,
      top_terms:   session.cluster_signature.split('+'),
      sessions:    [],
      total_score: 0
    };
  }
  clusters[sig].sessions.push(session);
  clusters[sig].total_score += session.score;
}
```

Sessions are allowed to appear in multiple tunnels. A session discussing both OAuth token issuance and login UX flows legitimately belongs to both clusters. Deduplication applies only to the catch-all `tunnel-other`.

### Tunnel naming

Derive a human-readable label from the cluster's top terms:

```javascript
function make_tunnel_label(top_terms) {
  slug_parts = top_terms.slice(0, 2).map(t => t.toLowerCase().replace(/[^a-z0-9]+/g, '-'));
  return `tunnel-${slug_parts.join('-')}`;
}

tunnels = Object.values(clusters).map(c => ({
  label:         make_tunnel_label(c.top_terms),
  top_terms:     c.top_terms,
  sessions:      c.sessions,
  total_score:   c.total_score,
  session_count: c.sessions.length,
  date_range:    compute_date_range(c.sessions),
  status:        'unexplored'
}));
```

### Tunnel ranking with temporal spread bonus

Tunnels spanning longer date ranges rank higher when scores are close:

```javascript
function compute_date_range(sessions) {
  dates = sessions.map(s => new Date(s.date)).sort((a, b) => a - b);
  if (dates.length === 1) return format_date(dates[0]);
  span_months = Math.round((dates[dates.length - 1] - dates[0]) / (1000 * 60 * 60 * 24 * 30));
  return `${format_date(dates[0])} -- ${format_date(dates[dates.length - 1])} (${span_months}mo span)`;
}

function tunnel_rank_score(tunnel) {
  span_days = date_span_days(tunnel.sessions);
  span_bonus = Math.min(1.5, 1.0 + (span_days / 365) * 0.5);  // max +50% for year-spanning
  return tunnel.total_score * span_bonus;
}

tunnels.sort((a, b) => tunnel_rank_score(b) - tunnel_rank_score(a));
```

### Cap at 10 with catch-all merge

If there are more than 10 tunnels, merge the weakest into a catch-all:

```javascript
if (tunnels.length > 10) {
  tail = tunnels.splice(10);
  other_sessions = tail.flatMap(t => t.sessions);
  other_sessions = unique_by(other_sessions, s => s.file);  // deduplicate catch-all only
  tunnels.push({
    label:         'tunnel-other',
    top_terms:     [],
    sessions:      other_sessions,
    total_score:   tail.reduce((sum, t) => sum + t.total_score, 0),
    session_count: other_sessions.length,
    date_range:    compute_date_range(other_sessions),
    status:        'unexplored'
  });
}
```

### Write cavern-map.json

Build the tree structure. The root node represents the subject. Each tunnel becomes a child node at depth 1. Write atomically.

```javascript
now = new Date().toISOString();

// Build tunnel nodes
tunnel_nodes = {};
tunnel_ids = [];

for (t of tunnels) {
  tunnel_id = t.label;
  tunnel_ids.push(tunnel_id);

  tunnel_nodes[tunnel_id] = {
    id:                tunnel_id,
    label:             t.label.replace(/^tunnel-/, '').replace(/-/g, ' '),
    status:            'unexplored',
    depth:             1,
    parent_id:         'root',
    children:          [],
    nugget_ids:        [],
    sessions_searched: [],
    discovered_at:     now,
    last_dug:          null
  };
}

cavern_map = {
  schema_version: "1.0",
  subject:        subject,
  subject_slug:   subject_slug,
  project:        PROJECT_SLUG,
  started_at:     now,
  last_modified:  now,
  total_nuggets:  0,
  total_veins:    0,
  expanded_terms: expanded_terms,
  session_count:  session_scores.length,
  prior_outputs: {
    survey:    exists(`${ARCHAEOLOGY_DIR}/survey.md`) || exists(`${CENTRAL_OUTPUT_DIR}/survey.md`),
    domains:   HAS_PRIOR_FINDINGS ? [subject_slug] : [],
    artifacts: exists(`${ARCHAEOLOGY_DIR}/artifacts/_index.json`)
  },
  root: {
    id:                "root",
    label:             subject,
    status:            "active",
    depth:             0,
    parent_id:         null,
    children:          tunnel_ids,
    nugget_ids:        [],
    sessions_searched: [],
    discovered_at:     now,
    last_dug:          null
  },
  tunnel_nodes:  tunnel_nodes,
  decision_log:  []
};

// Atomic write
Write(`${CAVERN_MAP}.tmp`, JSON.stringify(cavern_map, null, 2));
Bash(`mv "${CAVERN_MAP}.tmp" "${CAVERN_MAP}"`);
```

The structure is a tree: `root` + `tunnel_nodes` map. NOT a flat `tunnels` array. Field names must match the schema: `started_at`, `last_modified`, `total_nuggets`, `total_veins`, `schema_version`.

---

## Dig Step D4: Present Cavern Map

Displays the cavern map to the user and waits for direction. This is the first interaction point in every dig session.

### Verify cavern map

Before displaying, verify the cavern map is present and valid JSON:

```javascript
if (!exists(CAVERN_MAP)) {
  error(`cavern-map.json not found at ${CAVERN_MAP}. D3 may have failed.`);
}
try {
  cavern_map = JSON.parse(Read(CAVERN_MAP));
} catch (e) {
  error(`cavern-map.json is not valid JSON: ${e.message}`);
}
```

`cavern_map.root` must exist with a non-empty `children` array before proceeding to display.

### Display -- init mode

Follow the format rules from `output-templates.md`: no emoji, no markdown tables, no ASCII box-drawing, no horizontal rules. Two-space indent for nested items.

Display the init banner, then render the `{#dig-map}` template:

```
{SIGIL_DIG} Archaeology Dig: {subject}
  Sessions found: {session_count} across {date_range}
  Expanded terms: {expanded_terms}
  Prior outputs: survey {survey_present}, domains: {domain_list}, artifacts: {artifact_count}

  Tunnels:
    {N}. {tunnel_label} [UNEXPLORED] ({tunnel_session_count} sessions, {tunnel_date_range})
       Keywords: {kw1}, {kw2}, {kw3}

Pick a tunnel number, or describe what to explore.
```

Variable mappings:
- `{subject}` -- the subject string as provided by the user
- `{session_count}` -- total sessions found in D2 scope
- `{date_range}` -- `{earliest} to {latest}` from session metadata
- `{expanded_terms}` -- `cavern_map.expanded_terms`, joined with `", "`. Shown only in init mode.
- `{survey_present}` -- `yes` or `no`
- `{domain_list}` -- comma-separated list of domains with existing findings, or `none`
- `{artifact_count}` -- count of conserved artifacts, or `none`
- Tunnel lines: one per tunnel, ordered by index. Keywords are the top 3 by frequency.

### Display -- resume mode

When `existing_state` was true and `--fresh` was not passed, render the `{#dig-map}` template in resume mode. The `Expanded terms:` line is omitted; the resume block is shown:

```
{SIGIL_DIG} Archaeology Dig: {subject}
  Sessions found: {session_count} across {date_range}

  Tunnels:
    {N}. {tunnel_label} [{STATUS}] ({tunnel_session_count} sessions, {tunnel_date_range})
       Keywords: {kw1}, {kw2}, {kw3}
       Nuggets: {nugget_count}

  Treasure trove: {total_nuggets} nuggets, {total_veins} veins
  Last dig: {last_dig_date}
  Recent decisions:
    Turn {turn_N}: "{user_said_truncated}" -- {action} ({nuggets_found} nuggets)

  Recommended: {recommended_tunnel_label} -- {reason}

Pick a tunnel number, or describe what to explore.
```

Variable mappings for resume mode:
- `{STATUS}` -- one of `UNEXPLORED`, `ACTIVE`, `EXHAUSTED`, `PAUSED`
- "Nuggets: N" sub-line shown only for tunnels with `nugget_count > 0`
- `{total_nuggets}` / `{total_veins}` -- from `cavern_map`
- `{last_dig_date}` -- `cavern_map.last_modified`, formatted as `YYYY-MM-DD`
- Decision log entries: last 3 from `cavern_map.decision_log`, sorted by turn number descending. `{user_said_truncated}` is truncated to 60 characters.
- `{recommended_tunnel_label}` -- highest-signal unexplored tunnel. `{reason}` is a brief rationale (e.g. "highest keyword density", "referenced by 3 existing nuggets").

### Waiting for user input

After displaying, wait for the user's response. Do not proceed automatically. Valid inputs:

- **A tunnel number** (1-N) -- navigate directly into that tunnel
- **A descriptive phrase** -- match it to the most relevant tunnel by keyword overlap and confirm with the user
- **`done` / `finish`** -- trigger D-final export
- **`map`** -- redisplay the current cavern map without proceeding

Record the user's direction and the resolved tunnel in `cavern_map.decision_log` before D5 begins.

---

## Dig Step D5: Spelunker Dispatch

The investigation phase begins. The entire D5-D7 sequence is wrapped in a try/finally block to ensure lock file cleanup on any error path:

```javascript
try {
  // D5: Spelunker dispatch
  // D6: Connector dispatch (conditional)
  // D7: Trove regeneration and turn completion
} finally {
  remove(LOCK_FILE);
}
```

**Trigger:** The user selected a tunnel from the cavern map (D4), or provided free-text that was matched to the nearest tunnel by keyword overlap.

### Session selection

Pull sessions from the chosen tunnel node. Filter out sessions already searched for this tunnel. Rank candidates by keyword relevance. Cap at 6 per cycle.

```javascript
tunnel = find_tunnel_by_id(cavern_map, chosen_tunnel_id);

all_sessions = Glob(`${HISTORY_DIR}/**/*.jsonl`);

// Filter out already-searched sessions
already_searched = new Set(tunnel.sessions_searched);
candidate_sessions = all_sessions.filter(f => !already_searched.has(f));

if (candidate_sessions.length === 0) {
  tunnel.status = 'exhausted';
  write_cavern_map(cavern_map);
  display(`Tunnel "${tunnel.label}" is exhausted -- all sessions searched. Pick another direction.`);
  return;
}

// Rank candidates by keyword relevance to the tunnel
tunnel_keywords = extract_tunnel_keywords(tunnel);
ranked = rank_sessions_by_keyword_density(candidate_sessions, tunnel_keywords);

// Cap at 6 sessions per cycle
selected_sessions = ranked.slice(0, 6);
```

### Session assignment preparation

Build a lightweight assignment list -- paths and metadata only. Spelunker agents read the files themselves using the Read tool.

```javascript
SIZE_THRESHOLD = 200 * 1024;    // 200KB -- above this, spelunker reads in windows

// Build session assignment list -- paths only, no content loading
// The spelunker agents will read files themselves
session_assignments = [];
for (session_path of selected_sessions) {
  file_size = stat(session_path).size;
  session_assignments.push({
    session_path: session_path,
    session_date: extract_date_from_path(session_path),
    file_size: file_size,
    large_file: file_size >= SIZE_THRESHOLD
  });
}
```

**Pre-filtering context for spelunkers:** `tool_result` content blocks constitute 40-60% of a typical session file. Spelunkers should skip these blocks entirely and focus on the conversation flow -- what the user asked, what the assistant decided, what tools were invoked and why -- not the raw file contents returned by those tools.

### Agent dispatch

Fan out Explore agents, maximum 3 per cycle. Distribute sessions round-robin across spelunkers.

```javascript
MAX_SPELUNKERS = 3;

// Ensure nuggets directory exists before any glob operations
mkdir -p ${NUGGETS_DIR}

// Distribute sessions across spelunkers round-robin
spelunker_assignments = Array.from({ length: MAX_SPELUNKERS }, () => []);
for (let i = 0; i < session_assignments.length; i++) {
  spelunker_assignments[i % MAX_SPELUNKERS].push(session_assignments[i]);
}
// Remove empty assignments (fewer sessions than agents)
spelunker_assignments = spelunker_assignments.filter(a => a.length > 0);
```

### Prior nugget context for dedup

Build 1-line summaries of existing nuggets for this tunnel so spelunkers avoid re-discovery:

```javascript
existing_nuggets = tunnel.nugget_ids.map(nug_file => {
  frontmatter = parse_frontmatter(Read(`${NUGGETS_DIR}/${nug_file}`));
  what_line = extract_section(Read(`${NUGGETS_DIR}/${nug_file}`), 'What');
  return `${frontmatter.id}: ${what_line.slice(0, 120)}`;
});
prior_nugget_context = existing_nuggets.length > 0
  ? existing_nuggets.join('\n')
  : 'None yet.';
```

### Dispatch spelunker agents

For each assignment, build the session list (paths + metadata) and dispatch an Explore agent using the spelunker prompt (see Agent Prompts section below):

```javascript
spelunker_results = [];
for (assignment of spelunker_assignments) {
  session_list = assignment.map(s => ({
    path: s.session_path,
    date: s.session_date,
    large_file: s.large_file
  }));

  Agent({
    subagent_type: "Explore",
    prompt: build_spelunker_prompt(
      tunnel.label,
      cavern_map.subject,
      session_list,        // paths + metadata, NOT content
      prior_nugget_context
    )
  });
}
```

Wait for all spelunker agents to complete.

### Spelunker output parsing

Parse XML output from each spelunker using the `extract_xml_field()` pattern from `conversation-parser.md`:

```javascript
function parse_nugget_blocks(agent_output) {
  if (!agent_output || !agent_output.includes('<nugget>')) return [];

  blocks = agent_output.split('<nugget>').filter(Boolean);
  nuggets = [];

  for (block of blocks) {
    if (!block.includes('</nugget>')) continue;
    content = block.split('</nugget>')[0].trim();

    parsed = {
      what:           extract_xml_field(content, 'what'),
      why:            extract_xml_field(content, 'why'),
      confidence:     extract_xml_field(content, 'confidence'),
      weight:         extract_xml_field(content, 'weight'),
      tags:           extract_xml_field(content, 'tags'),
      source_session: extract_xml_field(content, 'source_session'),
      source_range:   extract_xml_field(content, 'source_range')
    };

    // Validate required fields
    if (!parsed.what || parsed.what.length < 30) continue;
    if (!parsed.why) continue;
    if (!['high', 'medium', 'low'].includes(parsed.confidence)) continue;
    weight_int = parseInt(parsed.weight);
    if (isNaN(weight_int) || weight_int < 1 || weight_int > 10) continue;

    parsed.weight = weight_int;
    parsed.tags = parsed.tags
      ? parsed.tags.split(',').map(t => t.trim()).filter(Boolean)
      : [];

    nuggets.push(parsed);
  }

  return nuggets;
}
```

### Source attribution with validation and fallback

For each parsed nugget, validate the spelunker-provided `source_session` against the assigned sessions. Fall back to the first assignment if validation fails:

```javascript
all_new_nuggets = [];
for (let i = 0; i < spelunker_results.length; i++) {
  result = spelunker_results[i];
  assignment = spelunker_assignments[i];
  parsed_nuggets = parse_nugget_blocks(result);

  for (nugget of parsed_nuggets) {
    assigned_sessions = assignment.map(s => s.session_path);

    if (nugget.source_session) {
      // Validate source_session matches one of the assigned sessions
      matched = assigned_sessions.find(s =>
        s.endsWith(nugget.source_session) || s.includes(nugget.source_session)
      );
      if (matched) {
        nugget.session_path = matched;
      } else {
        // Fallback: source_session doesn't match any assigned session
        nugget.session_path = assignment[0].session_path;
      }
    } else {
      // No source_session provided -- fallback to first assignment
      nugget.session_path = assignment[0].session_path;
    }

    nugget.slab_range = nugget.source_range || 'all';
    nugget.session_date = extract_date_from_path(nugget.session_path);
    all_new_nuggets.push(nugget);
  }
}
```

### Deduplication

Check new nuggets against existing nuggets for this tunnel. Two nuggets are duplicates if their `what` fields share > 80% token overlap:

```javascript
function token_overlap(text_a, text_b) {
  tokens_a = new Set(text_a.toLowerCase().split(/\s+/));
  tokens_b = new Set(text_b.toLowerCase().split(/\s+/));
  intersection = [...tokens_a].filter(t => tokens_b.has(t));
  smaller = Math.min(tokens_a.size, tokens_b.size);
  return smaller > 0 ? intersection.length / smaller : 0;
}

existing_whats = tunnel.nugget_ids.map(nug_file => {
  return extract_section(Read(`${NUGGETS_DIR}/${nug_file}`), 'What');
});

deduplicated = all_new_nuggets.filter(nugget => {
  for (existing_what of existing_whats) {
    if (token_overlap(nugget.what, existing_what) > 0.8) return false;
  }
  return true;
});
```

80% token overlap threshold for v1. Known gap for semantic duplicates -- flagged for v2 trigram similarity upgrade.

### Write nugget files

Assign IDs continuing from the highest existing nugget number across ALL tunnels. Write markdown files with YAML frontmatter:

```javascript
existing_nug_files = Glob(`${NUGGETS_DIR}/nug-*.md`);
highest = existing_nug_files.length > 0
  ? Math.max(...existing_nug_files.map(f => parseInt(basename(f).match(/nug-(\d+)/)[1])))
  : 0;

for (let i = 0; i < deduplicated.length; i++) {
  nug = deduplicated[i];
  nug_num = highest + i + 1;
  nug_id = `nug-${String(nug_num).padStart(3, '0')}`;
  nug_filename = `${nug_id}.md`;

  fm  = `id: ${nug_id}\n`;
  fm += `subject: ${cavern_map.subject_slug}\n`;
  fm += `tunnel_id: ${tunnel.id}\n`;
  fm += `session: ${nug.session_path}\n`;
  fm += `session_date: ${nug.session_date}\n`;
  fm += `slab: "${nug.slab_range}"\n`;
  fm += `confidence: ${nug.confidence}\n`;
  fm += `weight: ${nug.weight}\n`;
  fm += `tags:\n` + nug.tags.map(t => `  - "${t}"`).join('\n') + '\n';
  fm += `discovered_at: "${new Date().toISOString()}"\n`;

  file_content = `---\n${fm}---\n\n## What\n\n${nug.what}\n\n## Why\n\n${nug.why}\n`;

  Write(`${NUGGETS_DIR}/${nug_filename}`, file_content);

  // Track for cavern map update
  tunnel.nugget_ids.push(nug_filename);
}
```

### Update cavern map after nugget writes

```javascript
// Mark sessions as searched for this tunnel
for (assignment of session_assignments) {
  if (!tunnel.sessions_searched.includes(assignment.session_path)) {
    tunnel.sessions_searched.push(assignment.session_path);
  }
}

tunnel.status = 'active';
tunnel.last_dug = new Date().toISOString();
cavern_map.total_nuggets += deduplicated.length;
cavern_map.last_modified = new Date().toISOString();
```

---

## Dig Step D6: Connector Dispatch (Conditional)

Connectors run ONLY when there are enough nuggets to form meaningful connections. Below the threshold, connections are premature.

### Eligibility check

```javascript
all_nugget_files = Glob(`${NUGGETS_DIR}/nug-*.md`);
unique_sessions = new Set();
for (nug_file of all_nugget_files) {
  fm = parse_frontmatter(Read(`${NUGGETS_DIR}/${basename(nug_file)}`));
  unique_sessions.add(fm.session);
}

CONNECTOR_ELIGIBLE = all_nugget_files.length >= 5 && unique_sessions.size >= 2;
```

If not eligible, skip to D7.

### Nugget index preparation

Build a chronological index for the connector. The connector receives summaries, not full nugget bodies -- it reasons over the index to identify candidate connections.

```javascript
if (CONNECTOR_ELIGIBLE) {
  nugget_index_entries = [];

  for (nug_file of all_nugget_files) {
    content = Read(`${NUGGETS_DIR}/${basename(nug_file)}`);
    fm = parse_frontmatter(content);
    what_text = extract_section(content, 'What');
    // Truncate to 2 sentences for the index
    summary = what_text.split(/\.\s+/).slice(0, 2).join('. ') + '.';

    nugget_index_entries.push({
      id:           fm.id,
      session_date: fm.session_date,
      tunnel_id:    fm.tunnel_id,
      weight:       fm.weight,
      confidence:   fm.confidence,
      tags:         fm.tags,
      summary:      summary
    });
  }

  // Sort chronologically
  nugget_index_entries.sort((a, b) => a.session_date.localeCompare(b.session_date));

  // Build the index text with explicit temporal gap markers
  nugget_index_text = nugget_index_entries.map((entry, i) => {
    prev_date = i > 0 ? nugget_index_entries[i - 1].session_date : null;
    temporal_gap = '';
    if (prev_date) {
      days = date_diff_days(prev_date, entry.session_date);
      if (days > 0) temporal_gap = ` [${days} days after previous]`;
    }

    return `${entry.id} (${entry.session_date}${temporal_gap}) [tunnel: ${entry.tunnel_id}, weight: ${entry.weight}, confidence: ${entry.confidence}]\n  Tags: ${entry.tags.join(', ')}\n  ${entry.summary}`;
  }).join('\n\n');
```

### Existing veins context

Load existing veins to prevent re-discovery:

```javascript
  existing_veins = exists(`${STATE_DIR}/veins.json`)
    ? JSON.parse(Read(`${STATE_DIR}/veins.json`))
    : [];

  existing_vein_pairs = existing_veins.map(v =>
    [v.nugget_a, v.nugget_b].sort().join('--')
  );
  existing_veins_context = existing_veins.length > 0
    ? existing_veins.map(v =>
        `${v.id}: ${v.nugget_a} <-> ${v.nugget_b} (${v.link_type}, bridge: ${v.bridge})`
      ).join('\n')
    : 'None yet.';
```

### Single Explore agent dispatch

One connector agent per run. Connectors are not parallelised -- they need to see all nuggets to reason about cross-cutting connections:

```javascript
  connector_result = Agent({
    subagent_type: "Explore",
    prompt: build_connector_prompt(
      cavern_map.subject,
      nugget_index_text,
      existing_veins_context
    )
  });
```

Wait for the connector agent to complete.

### Connector output parsing

Parse XML output using the same `extract_xml_field()` pattern:

```javascript
  function parse_vein_blocks(agent_output) {
    if (!agent_output || !agent_output.includes('<vein>')) return [];

    blocks = agent_output.split('<vein>').filter(Boolean);
    veins = [];

    for (block of blocks) {
      if (!block.includes('</vein>')) continue;
      content = block.split('</vein>')[0].trim();

      parsed = {
        nugget_a:   extract_xml_field(content, 'nugget_a'),
        nugget_b:   extract_xml_field(content, 'nugget_b'),
        link_type:  extract_xml_field(content, 'link_type'),
        direction:  extract_xml_field(content, 'direction'),
        bridge:     extract_xml_field(content, 'bridge'),
        narrative:  extract_xml_field(content, 'narrative'),
        confidence: extract_xml_field(content, 'confidence')
      };

      // Validate required fields
      VALID_LINK_TYPES = ['evolution', 'recurrence', 'contradiction', 'consequence', 'reference'];
      VALID_DIRECTIONS = ['a_before_b', 'b_before_a', 'contemporaneous'];
      VALID_CONF = ['high', 'medium', 'low'];

      if (!parsed.nugget_a || !parsed.nugget_b) continue;
      if (!VALID_LINK_TYPES.includes(parsed.link_type)) continue;
      if (!VALID_DIRECTIONS.includes(parsed.direction)) continue;
      if (!VALID_CONF.includes(parsed.confidence)) continue;
      if (!parsed.bridge || parsed.bridge.length < 3) continue;
      if (!parsed.narrative || parsed.narrative.length < 30) continue;

      // Verify both nuggets exist
      if (!exists(`${NUGGETS_DIR}/${parsed.nugget_a}.md`)) continue;
      if (!exists(`${NUGGETS_DIR}/${parsed.nugget_b}.md`)) continue;

      // Check for duplicate pairs (including reversed order)
      pair_key = [parsed.nugget_a, parsed.nugget_b].sort().join('--');
      if (existing_vein_pairs.includes(pair_key)) continue;

      veins.push(parsed);
    }

    // Enforce max 3 veins per connector run
    return veins.slice(0, 3);
  }

  new_veins = parse_vein_blocks(connector_result);
```

### Vein ID assignment and atomic write

```javascript
  highest_vein = existing_veins.length > 0
    ? Math.max(...existing_veins.map(v => parseInt(v.id.match(/vein-(\d+)/)[1])))
    : 0;

  for (let i = 0; i < new_veins.length; i++) {
    vein_num = highest_vein + i + 1;
    new_veins[i].id = `vein-${String(vein_num).padStart(3, '0')}`;
    new_veins[i].discovered_at = new Date().toISOString();
  }

  // Append to veins array and write atomically
  all_veins = [...existing_veins, ...new_veins];
  Write(`${STATE_DIR}/veins.json.tmp`, JSON.stringify(all_veins, null, 2));
  Bash(`mv "${STATE_DIR}/veins.json.tmp" "${STATE_DIR}/veins.json"`);

  cavern_map.total_veins = all_veins.length;
}
```

---

## Dig Step D7: Trove Regeneration and Turn Completion

After spelunkers (and optionally connectors) complete, regenerate the trove, update the cavern map, check stopping signals, and return control to the user.

### 1. Rebuild trove.md

Regenerate from scratch every cycle. Group nuggets by tunnel, sort chronologically within each group. Interleave veins where they connect nuggets within the same section.

```javascript
all_nugget_files = Glob(`${NUGGETS_DIR}/nug-*.md`);
all_veins = exists(`${STATE_DIR}/veins.json`)
  ? JSON.parse(Read(`${STATE_DIR}/veins.json`))
  : [];

// Group nuggets by tunnel
nuggets_by_tunnel = {};
for (nug_file of all_nugget_files) {
  content = Read(`${NUGGETS_DIR}/${basename(nug_file)}`);
  fm = parse_frontmatter(content);
  what_text = extract_section(content, 'What');
  why_text = extract_section(content, 'Why');

  if (!nuggets_by_tunnel[fm.tunnel_id]) nuggets_by_tunnel[fm.tunnel_id] = [];
  nuggets_by_tunnel[fm.tunnel_id].push({
    id:           fm.id,
    session_date: fm.session_date,
    weight:       fm.weight,
    confidence:   fm.confidence,
    tags:         fm.tags,
    what:         what_text,
    why:          why_text
  });
}

// Sort each group chronologically
for (tunnel_id of Object.keys(nuggets_by_tunnel)) {
  nuggets_by_tunnel[tunnel_id].sort((a, b) =>
    a.session_date.localeCompare(b.session_date)
  );
}

// Build trove markdown
trove_lines = [];
trove_lines.push(`# ${cavern_map.subject} -- Treasure Trove`);
trove_lines.push('');
trove_lines.push(`> ${cavern_map.total_nuggets} nuggets, ${cavern_map.total_veins} veins | Last updated: ${current_date()}`);
trove_lines.push('');

flat_nodes = flatten_tunnel_tree(cavern_map);

for (node of flat_nodes) {
  nuggets = nuggets_by_tunnel[node.id];
  if (!nuggets || nuggets.length === 0) continue;

  trove_lines.push(`## ${node.label}`);
  trove_lines.push('');

  for (nugget of nuggets) {
    trove_lines.push(`### ${nugget.id} (${nugget.session_date}) weight: ${nugget.weight}, ${nugget.confidence}`);
    trove_lines.push('');
    trove_lines.push(nugget.what);
    trove_lines.push('');
    trove_lines.push(`*${nugget.why}*`);
    trove_lines.push('');

    // Interleave veins connected to this nugget
    connected_veins = all_veins.filter(v =>
      v.nugget_a === nugget.id || v.nugget_b === nugget.id
    );
    for (vein of connected_veins) {
      other = vein.nugget_a === nugget.id ? vein.nugget_b : vein.nugget_a;
      trove_lines.push(`> **${vein.id}** (${vein.link_type}) ${nugget.id} -- ${other}: ${vein.bridge}`);
      trove_lines.push(`> ${vein.narrative}`);
      trove_lines.push('');
    }
  }
}

trove_lines.push('---');
trove_lines.push(`*Generated by archaeology skill -- mode: dig*`);

Write(`${STATE_DIR}/trove.md`, trove_lines.join('\n'));
```

### 2. Update cavern map

Record this turn in the decision log. Check for new tunnel suggestions from spelunker output -- nuggets whose tags are not covered by any existing tunnel suggest a new branch.

```javascript
// New tunnel discovery from uncovered tags
existing_tunnel_keywords = new Set();
for (node of flat_nodes) {
  for (keyword of extract_tunnel_keywords(node)) {
    existing_tunnel_keywords.add(keyword.toLowerCase());
  }
}

new_tunnel_suggestions = [];
for (nugget of deduplicated) {
  for (tag of nugget.tags) {
    if (!existing_tunnel_keywords.has(tag.toLowerCase())) {
      new_tunnel_suggestions.push(tag);
    }
  }
}
new_tunnel_suggestions = [...new Set(new_tunnel_suggestions)];

// Create new tunnel nodes for suggestions (status: unexplored)
for (suggestion of new_tunnel_suggestions) {
  new_tunnel_id = `tunnel-${suggestion.toLowerCase().replace(/[^a-z0-9]+/g, '-')}`;
  if (cavern_map.tunnel_nodes[new_tunnel_id]) continue;
  if (new_tunnel_id === 'root') continue;

  new_node = {
    id:                new_tunnel_id,
    label:             suggestion,
    status:            'unexplored',
    depth:             tunnel.depth + 1,
    parent_id:         tunnel.id,
    children:          [],
    nugget_ids:        [],
    sessions_searched: [],
    discovered_at:     new Date().toISOString(),
    last_dug:          null
  };

  tunnel.children.push(new_tunnel_id);
  cavern_map.tunnel_nodes[new_tunnel_id] = new_node;
}

// Append decision log entry
turn_number = cavern_map.decision_log.length + 1;
cavern_map.decision_log.push({
  turn:              turn_number,
  timestamp:         new Date().toISOString(),
  user_said:         user_instruction_verbatim,
  action:            `Dispatched ${spelunker_assignments.length} spelunker(s) into ${tunnel.label}. Found ${deduplicated.length} nuggets.`
                     + (CONNECTOR_ELIGIBLE ? ` Connector found ${new_veins.length} veins.` : ''),
  rationale:         build_turn_rationale(tunnel, deduplicated, new_tunnel_suggestions),
  tunnels_explored:  [tunnel.id],
  nuggets_found:     deduplicated.length
});

// Atomic write
Write(`${CAVERN_MAP}.tmp`, JSON.stringify(cavern_map, null, 2));
Bash(`mv "${CAVERN_MAP}.tmp" "${CAVERN_MAP}"`);
```

### 3. Stopping signals

Check three stopping conditions after every cycle:

```javascript
// Signal 1: 0-nugget exhaustion -- 2 consecutive cycles with 0 new nuggets
if (deduplicated.length === 0) {
  prior_turns_for_tunnel = cavern_map.decision_log.filter(entry =>
    entry.tunnels_explored.includes(tunnel.id) && entry.turn < turn_number
  );
  last_prior = prior_turns_for_tunnel[prior_turns_for_tunnel.length - 1];

  if (last_prior && last_prior.nuggets_found === 0) {
    // 2 consecutive cycles with 0 nuggets -- mark exhausted
    tunnel.status = 'exhausted';
    write_cavern_map(cavern_map);
  }
}

// Signal 2: All tunnels exhausted
all_tunnel_list = flatten_tunnel_tree(cavern_map);
active_or_unexplored = all_tunnel_list.filter(t =>
  t.status === 'active' || t.status === 'unexplored'
);
dig_complete_suggestion = active_or_unexplored.length === 0;

// Signal 3: Session coverage -- tunnel-scoped count
total_tunnel_sessions = count_tunnel_scoped_sessions(tunnel, session_scores);
searched_for_tunnel = tunnel.sessions_searched.length;
```

### 4. Display turn results

Use the `{#dig-iteration}` template. Format rules from `output-templates.md` apply: no box-drawing, no emoji, no markdown tables, no horizontal rules.

```
{SIGIL_DIG} Dig cycle {N} -- {tunnel_label}
  New nuggets: {new_nuggets} (total: {total_nuggets})
  New veins: {new_veins} (total: {total_veins})
  Sessions covered: {searched}/{tunnel_total} for this tunnel

  Nuggets found this cycle:
    nug-{NNN}: {what_truncated} (weight: {weight}, confidence: {confidence})

[if new tunnels discovered:]
  New tunnels spotted:
    {tunnel_label} -- suggested by nug-{NNN}

[if tunnel exhausted:]
  Tunnel "{label}" tapped out -- {searched}/{tunnel_total} sessions searched

[if all tunnels exhausted:]
  All tunnels exhausted. Run /archaeology dig '{subject}' --done to export.

[if budget checkpoint reached:]
  Budget checkpoint -- continue with /archaeology dig "{subject}" in a new session

Pick next direction, or /archaeology dig "{subject}" --done to wrap up.

{SIGNOFF}
```

Variable mappings:
- `{N}` -- `turn_number` from the decision log entry
- `{tunnel_label}` -- `tunnel.label`
- `{new_nuggets}` -- `deduplicated.length`
- `{total_nuggets}` -- `cavern_map.total_nuggets`
- `{new_veins}` -- `new_veins.length` (0 if connector did not run)
- `{total_veins}` -- `cavern_map.total_veins`
- `{searched}` -- `tunnel.sessions_searched.length`
- `{tunnel_total}` -- tunnel-scoped session count (sessions matching tunnel keywords), not all project sessions
- Nugget lines: one per nugget found this cycle, ordered by weight descending, capped at 5. `{what_truncated}` is the first sentence of `## What`, truncated to 80 characters. If 0 nuggets found, replace the block with: `No new nuggets this cycle.`
- New tunnel lines: one per suggestion, including the nugget ID that prompted it
- Exhaustion and completion lines: conditional on state

### 5. Budget check

Enforce a 2-cycle cap per session to prevent context window exhaustion:

```javascript
cycles_this_session = count_cycles_this_session();  // tracked in-memory, not persisted

if (cycles_this_session >= 2) {
  display('Budget checkpoint -- continue in a new session with `/archaeology dig "' +
    cavern_map.subject + '"` to resume.');
}
```

### 6. Lock file removal

The lock file is removed by the try/finally wrapper around D5-D7. No explicit removal needed here -- the finally block handles all exit paths including errors.

---

## D-FINAL: Central Work-Log Export

Triggered by `--done` or `--export` flag. Not automatic per turn.

- `--done` -- marks the dig complete, exports all outputs, and updates index files and SUMMARY.md
- `--export` -- exports current state without changing status to complete; useful for mid-dig checkpoints

### Export destination

```
${CENTRAL_PROJECT_DIR}/spelunk/{subject-slug}/
```

Where `CENTRAL_PROJECT_DIR = ~/.claude/data/visibility-toolkit/work-log/archaeology/${PROJECT_SLUG}`.

### Files exported

| File | Contents |
|------|----------|
| `trove.md` | Human-readable synthesis of all nuggets, organised by tunnel |
| `nuggets.json` | All nuggets as a JSON array compiled from individual `.md` files |
| `veins.json` | All vein connections |
| `cavern-map.json` | Full cavern-map state (for reference and resume) |
| `metadata.json` | Summary metadata for index detection |

### metadata.json structure

```json
{
  "type": "dig",
  "subject": "auth",
  "subject_slug": "auth",
  "status": "complete",
  "total_nuggets": 12,
  "total_veins": 5,
  "total_tunnels": 4,
  "tunnels_exhausted": 2,
  "started_at": "2026-03-09T10:00:00Z",
  "completed_at": "2026-03-09T11:30:00Z",
  "sessions_analyzed": 8,
  "dig_cycles": 3
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | yes | Always `"dig"` |
| `subject` | string | yes | Subject string as provided by user |
| `subject_slug` | string | yes | Slugified subject |
| `status` | enum | yes | `"complete"` (via `--done`) or `"in-progress"` (via `--export`) |
| `total_nuggets` | integer | yes | Total nuggets found across all tunnels |
| `total_veins` | integer | yes | Total veins discovered |
| `total_tunnels` | integer | yes | Total tunnel count in cavern map |
| `tunnels_exhausted` | integer | yes | Count of tunnels with status `exhausted` |
| `started_at` | ISO timestamp | yes | When the dig was first initiated |
| `completed_at` | ISO timestamp | no | Set when status is `"complete"`. Omitted when `"in-progress"` |
| `sessions_analyzed` | integer | yes | Total unique sessions analyzed across all cycles |
| `dig_cycles` | integer | yes | Number of completed dig cycles |

`status` is `"complete"` when exported via `--done`; `"in-progress"` when exported via `--export`. `completed_at` is omitted if status is `"in-progress"`.

### Completion display

When `--done` is used, display the `{#dig-completion}` template:

```
{SIGIL_DIG} Archaeology Dig complete: {subject}
  Duration: {started_at} to {completed_at}
  Dig cycles: {dig_cycles}
  Tunnels explored: {explored}/{total_tunnels} ({exhausted} exhausted)

  Treasure trove:
    Nuggets: {total_nuggets} ({high_confidence_count} high confidence)
    Veins: {total_veins}
    Top findings by weight:
      nug-{NNN}: {what_truncated} (weight: {weight})
      nug-{NNN}: {what_truncated} (weight: {weight})
      nug-{NNN}: {what_truncated} (weight: {weight})

[if exported:]
  Exported to:
    Local:   {ARCHAEOLOGY_DIR}/spelunk/{subject_slug}/
    Central: {CENTRAL_PROJECT_DIR}/spelunk/{subject_slug}/

[if not exported (--no-export was set):]
  Run /archaeology dig "{subject}" --export to export findings.

{SIGNOFF}
```

### Post-export index updates

After writing the export files, update three index locations:

1. **Local INDEX.md** -- call `update_local_archaeology_index()`. Extend its scan to detect `spelunk/*/cavern-map.json` under `ARCHAEOLOGY_DIR` and include a `has_spelunk` indicator in the local INDEX.md project entry.

2. **Central INDEX.md** -- call `update_central_index()`. Extend its scan to detect `spelunk/*/metadata.json` under `CENTRAL_PROJECT_DIR`. For each spelunk entry found, include a row with: subject slug, status, nugget count, and last updated date.

3. **SUMMARY.md Deep Digs section** -- if `--done`, update `${CENTRAL_PROJECT_DIR}/SUMMARY.md`. Add or refresh a "Deep Digs" section listing all completed digs. Each entry shows: subject, total nuggets, and the top 3 nuggets by weight (ID + truncated `what` field, max 80 chars).

---

## Agent Prompts

Two agent types: spelunkers (D5) and connectors (D6). The prompts below are complete, quotable prompt text ready to inject into `Agent()` calls with `${variable}` substitution.

### Spelunker Agent Prompt

Called by `build_spelunker_prompt()` in D5. Variable placeholders are marked with `${...}`.

```
You are a spelunker -- an archaeological sub-agent that reads Claude Code
conversation history and extracts discrete findings about a specific subject.

SUBJECT: ${subject}
TUNNEL: ${tunnel_label}
You are looking for information specifically about: ${tunnel_label} as it
relates to ${subject}.

SESSIONS ASSIGNED TO YOU:
${session_list_formatted}

READING INSTRUCTIONS:
For each session file assigned to you:
1. Use the Read tool to read the file
2. Pre-filter: Skip tool_result content blocks entirely -- they are raw file
   contents and tool outputs that inflate the file by 40-60%. Focus on the
   conversation flow: what the user asked, what the assistant decided, what
   tools were invoked and why.
3. For large files (marked large_file: true), read in 150-message windows.
   Process each window before reading the next. Do not attempt to load the
   entire file at once.
4. As you read, extract nuggets per the rules below. You do not need to
   hold the entire session in memory -- process each session/window and
   emit nuggets as you go.

SIZE_THRESHOLD: 200KB. Files above this are marked large_file: true.
SLAB_SIZE: 150 messages per reading window for large files.

YOUR TASK HAS TWO PHASES. Complete both in a single pass over the material.

PHASE 1 -- EXTRACT
Find concrete moments in the conversation. What was said, decided, built,
broken, changed. Look for named entities:
- Tool names and function names
- Error messages and stack traces
- Explicit decisions ("we chose X over Y because Z")
- Metrics and measurements (response times, file sizes, counts)
- File paths and configuration values
- Quoted statements from the user or assistant

You are looking for MOMENTS, not themes. "The team discussed authentication"
is NOT a finding. "The team chose PKCE over implicit flow because the app
runs on mobile and cannot securely store a client secret" IS a finding.

PHASE 2 -- REASON
For each extracted moment, explain why it matters. What caused it? What
followed from it? Why would someone reading this 6 months from now care?

Your reasoning MUST reference a specific noun from the extraction -- a tool
name, a decision, an error message, a metric. If your reasoning cannot point
to something concrete from the extraction, omit the nugget entirely.

HARD RULES:
- Return 0 nuggets if nothing significant exists. Empty-handed is fine.
  Do not manufacture findings to fill a quota.
- Weight is your judgment of importance on a 1-10 scale:
    1-2: routine configuration, minor detail
    3-4: notable but unsurprising
    5-6: meaningful decision or event with downstream effects
    7-8: pivotal -- changed the direction of the project or revealed a
         fundamental constraint
    9-10: defining moment -- the kind of thing that gets retold in
          project retrospectives
- Confidence reflects evidence quality:
    high: explicit statement in the conversation, direct quote, or named
          artefact you can point to
    medium: inferred from context with at least one concrete reference
    low: synthesised from patterns across the session, no single clear anchor
- Do NOT re-discover findings that already exist. These nuggets have already
  been found for this tunnel:
${prior_nugget_summaries}

FORMAT RULES:
- source_range: msg:{start}-{end} referencing JSONL message indices
- source_session: the session filename you read
- tags: 2-5 tags using domain/specific hierarchy (e.g., mcp/caching,
  perf/latency). Include parent tag when useful for clustering.
- XML escaping: < as &lt;, > as &gt;, & as &amp;

OUTPUT FORMAT:
Return ONLY <nugget> blocks. Do not include any text outside of nugget tags.
Do not explain your reasoning outside the tags. Do not add preamble or summary.

<nugget>
  <what>Concrete description of what happened. Must contain named entities --
  tool names, error messages, decisions, metrics, file paths. Minimum 30
  characters.</what>
  <why>Why this matters. Must reference a specific noun from <what>. If you
  cannot name a specific tool, decision, error, or metric from your <what> --
  omit the nugget entirely.</why>
  <confidence>high|medium|low</confidence>
  <weight>1-10</weight>
  <tags>comma-separated lowercase tags using domain/specific hierarchy</tags>
  <source_session>filename.jsonl from your SESSIONS list</source_session>
  <source_range>msg:{start}-{end}</source_range>
</nugget>

EXAMPLES:

Good example:
<nugget>
  <what>Switched MCP tool registration from per-request dynamic lookup to
  a static manifest cached in .claude/mcp-manifest.json after profiling
  showed google-workspace-mcp added 1.2s latency per ToolSearch call due
  to repeated schema fetches over stdio transport.</what>
  <why>The 1.2s overhead compounded across sub-agents -- a 4-agent fan-out
  spent ~5s on MCP discovery alone before doing any work.</why>
  <confidence>high</confidence>
  <weight>6</weight>
  <tags>mcp, mcp/caching, perf/latency</tags>
  <source_session>2026-02-18T14-22.jsonl</source_session>
  <source_range>msg:1450-1523</source_range>
</nugget>

Bad example (DO NOT DO THIS):
<nugget>
  <what>The team explored different approaches to MCP tool caching and
  decided to implement a file-based solution to improve performance.</what>
  <why>Caching is important for performance in multi-agent workflows
  because repeated lookups add unnecessary overhead.</why>
  <confidence>medium</confidence>
  <weight>7</weight>
  <tags>caching, performance, mcp</tags>
  <source_session>2026-02-18T14-22.jsonl</source_session>
  <source_range>msg:1200-1600</source_range>
</nugget>

WHY THIS FAILS:
- <what> has zero concrete nouns -- "file-based solution" could mean anything.
- <why> restates the theme instead of referencing a specific noun from <what>.
- weight:7 is inflated -- compare the good example: weight:6 WITH a named
  metric (1.2s) and a measured downstream effect.
- source_range spans 400 messages -- too broad to relocate the finding.

```

**Prompt assembly notes:**
- `${subject}` -- `cavern_map.subject`, the user's original subject string.
- `${tunnel_label}` -- `tunnel.label`, the human-readable tunnel name.
- `${prior_nugget_summaries}` -- the 1-line summaries built in D5, or `"None yet."` if this is the first cycle for this tunnel.
- `${session_list_formatted}` -- one line per session: `  {path}  ({date})  [LARGE -- read in windows]` (the large-file marker is omitted for small files).
- `build_spelunker_prompt()` signature: `(tunnel_label, subject, session_list, prior_nugget_context)` -- takes session metadata, not content.

### Connector Agent Prompt

Called by `build_connector_prompt()` in D6. Variable placeholders are marked with `${...}`.

```
You are a connector -- an archaeological sub-agent that identifies
relationships between discrete findings (nuggets) from a dig investigation.

SUBJECT: ${subject}

You will receive a chronological index of nuggets. Each entry includes the
nugget ID, session date, tunnel, weight, confidence, tags, and a 1-2
sentence summary. You are looking for relationships BETWEEN nuggets -- not
summarising individual ones.

LINK TYPES YOU MAY IDENTIFY:

evolution
  Same concept changed over time. Nugget B postdates Nugget A, and there is
  a detectable change in approach, scope, or outcome. The bridge must name
  the concept that evolved.

recurrence
  Same concept appears independently across sessions with no clear causal
  link. This is a pattern claim, not a causal one. The bridge must name the
  recurring element.

contradiction
  Two nuggets assert incompatible things about the same topic. The bridge
  must name the specific point of disagreement.

consequence
  Nugget B is plausibly caused by Nugget A. You must name the causal
  mechanism explicitly in the narrative -- not just assert that one follows
  the other chronologically.

reference
  Nugget B explicitly builds on or refers to Nugget A's subject matter.
  The bridge must name the shared element.

ANTI-INFLATION RULES:
- Return a MAXIMUM of 3 veins. This forces you to prioritise. If you see
  more than 3 candidate connections, pick the 3 with the strongest evidence.
- Each vein MUST name a <bridge> -- a specific element (tool name, concept
  label, decision, file path, error message) that appears in BOTH nuggets.
  The bridge must be a proper noun, not a theme. Not "authentication" or
  "performance". A concrete noun that you can point to in both nugget
  summaries. If the bridge element does not appear in both nuggets, the
  vein is invalid.
- Return 0 veins if no strong connections exist. Unconnected nuggets are
  fine. Forcing connections where none exist degrades the dig's signal.

FORMAT RULES:
- bridge: the specific file, tool, config key, or concept shared by both
  nuggets -- a proper noun, not a theme
- tags: 2-5 tags using domain/specific hierarchy (e.g., mcp/caching,
  perf/latency). Include parent tag when useful for clustering.
- XML escaping: < as &lt;, > as &gt;, & as &amp;

EXISTING VEINS (do not duplicate these connections):
${existing_veins_context}

OUTPUT FORMAT:
Return ONLY <vein> blocks. Do not include any text outside of vein tags.
Do not explain your reasoning outside the tags. Do not add preamble or summary.

<vein>
  <nugget_a>nug-NNN</nugget_a>
  <nugget_b>nug-NNN</nugget_b>
  <link_type>evolution|recurrence|contradiction|consequence|reference</link_type>
  <direction>a_before_b|b_before_a|contemporaneous</direction>
  <bridge>The specific named element appearing in both nuggets</bridge>
  <narrative>One paragraph explaining the relationship. Ground it in the
  bridge element. For consequence links, name the causal mechanism. For
  evolution links, describe what changed and why. For contradiction links,
  state both positions clearly.</narrative>
  <confidence>high|medium|low</confidence>
</vein>

EXAMPLE:

<vein>
  <nugget_a>nug-014</nugget_a>
  <nugget_b>nug-027</nugget_b>
  <link_type>consequence</link_type>
  <direction>a_before_b</direction>
  <bridge>.claude/mcp-manifest.json</bridge>
  <narrative>The decision in nug-014 to cache MCP schemas in
  .claude/mcp-manifest.json traded discovery latency for staleness risk.
  When google-workspace-mcp updated its schema to add
  batch_share_drive_file, the cached manifest served the old version,
  causing nug-027's "tool not found" errors -- static cache with no
  invalidation hook meant schema drift went undetected.</narrative>
  <confidence>high</confidence>
</vein>

CHRONOLOGICAL NUGGET INDEX:
${nugget_index_text}
```

**Prompt assembly notes:**
- `${subject}` -- `cavern_map.subject`, the user's original subject string.
- `${existing_veins_context}` -- 1-line summaries of existing veins built in D6, or `"None yet."` if no veins exist.
- `${nugget_index_text}` -- the chronological nugget index built in D6, with temporal gap markers between entries.

### Agent Output Convention Alignment

Both agents follow the XML output convention defined in `conversation-parser.md`:

| Convention | Spelunker | Connector |
|------------|-----------|-----------|
| XML tags for structured output | `<nugget>` with `<what>`, `<why>`, `<confidence>`, `<weight>`, `<tags>`, `<source_session>`, `<source_range>` | `<vein>` with `<nugget_a>`, `<nugget_b>`, `<link_type>`, `<direction>`, `<bridge>`, `<narrative>`, `<confidence>` |
| Parsed with `extract_xml_field()` | Yes | Yes |
| "Return ONLY" instruction | Yes | Yes |
| `snake_case` field names | Yes | Yes |
| Permission to return 0 results | Explicit | Explicit |
| XML escaping instruction | Yes | Yes |
| Few-shot examples | Good + bad with explanation | Vein example |

---

## Error Handling

| Scenario | Behaviour |
|----------|-----------|
| All sessions for tunnel already searched | Mark tunnel `exhausted`, prompt user to pick another direction |
| 0 sessions selected (no candidate sessions) | Same as above |
| Spelunker returns empty or unstructured output | Log as diagnostic, continue with remaining spelunkers |
| All spelunkers return 0 nuggets | Record in decision log, check exhaustion signal, display "No new nuggets this cycle" |
| 3/3 spelunkers return unstructured output | Warn: "All spelunker agents returned unusable output. Try narrowing the tunnel focus or rephrasing the subject." |
| Connector returns 0 veins | Normal -- record 0 new veins in display |
| Connector returns invalid XML | Skip parsing, log warning, proceed with 0 new veins |
| Lock file exists at invocation | Warn and proceed (do not auto-remove) |
| Nugget ID collision (race condition) | Cannot happen -- IDs are assigned sequentially from max existing, and the lock file prevents concurrent writes |
| `veins.json` corrupted or unparseable | Reset to empty array, log warning, proceed |
| `cavern-map.json` not valid JSON at D4 | Error and exit -- D3 may have failed |
| Schema version mismatch on resume | Remove lock, error with version details |
| 0 conversation files found in HISTORY_DIR | Remove lock, exit with guidance to run survey first |
| 0 sessions match subject in D2 | Remove lock, exit with guidance to try a different subject |

---

## Completion Criteria

### Reconnaissance Phase (D1-D4)

- [ ] Project context resolved -- `PROJECT_ROOT`, `PROJECT_SLUG`, `ARCHAEOLOGY_DIR`, `CENTRAL_OUTPUT_DIR` set (D1)
- [ ] Execution path determined -- init, resume, or flag-driven shortcut (D1)
- [ ] Lock file written to `STATE_DIR` before init/resume branch (D1)
- [ ] `NUGGETS_DIR` created and `veins.json` initialized as `[]` on init (D1)
- [ ] Schema version checked on resume -- must be `"1.0"` (D1)
- [ ] `--fresh` confirmation guard when `total_nuggets > 0` (D1)
- [ ] Subject expanded to 5-10 search terms (D2)
- [ ] Survey and domain outputs incorporated if present (D2)
- [ ] All conversation files scored against expanded terms using jq-filtered JSONL (D2)
- [ ] Sessions ranked by score (D2)
- [ ] Zero-hit guard checked -- exits cleanly if no sessions match (D2)
- [ ] Sessions clustered into tunnels by term co-occurrence (D3)
- [ ] Tunnels ranked by score with temporal spread bonus (D3)
- [ ] Tunnel count capped at 10 with catch-all merge if needed (D3)
- [ ] `cavern-map.json` written atomically with tree structure (root + tunnel_nodes) (D3)
- [ ] Schema version is `"1.0"`, field names match schema: `started_at`, `last_modified`, `total_nuggets`, `total_veins`, `schema_version` (D3)
- [ ] `cavern-map.json` verified as valid JSON before display (D4)
- [ ] Cavern map displayed to user in contract format (D4)
- [ ] User direction received -- ready to pass to D5 (D4)

### Investigation Phase (D5-D7)

- [ ] Sessions selected and assignments prepared for the active tunnel (D5)
- [ ] `NUGGETS_DIR` verified to exist before glob operations (D5)
- [ ] Spelunker agents dispatched (max 3 Explore agents, round-robin sessions) and all results collected (D5)
- [ ] Spelunker XML parsed with source attribution (`source_session`, `source_range`) (D5)
- [ ] Source session validated against assigned sessions with fallback (D5)
- [ ] New nuggets deduplicated against existing (80% token overlap threshold) (D5)
- [ ] Nugget files written with YAML frontmatter and body (D5)
- [ ] Cavern map updated with new nugget IDs and searched sessions (D5)
- [ ] **(If eligible: 5+ nuggets across 2+ sessions)** Connector agent dispatched and result collected (D6)
- [ ] **(If eligible)** Vein XML parsed, validated (link type, direction, confidence, bridge length, narrative length, nugget existence), max 3 veins per run (D6)
- [ ] **(If eligible)** `veins.json` written atomically (D6)
- [ ] `trove.md` regenerated from current nugget and vein set, grouped by tunnel, chronological, veins interleaved (D7)
- [ ] Decision log entry appended to cavern map (D7)
- [ ] New tunnel suggestions added as `unexplored` nodes if applicable (D7)
- [ ] Stopping signals checked: 0-nugget exhaustion (2 consecutive), all tunnels exhausted, session coverage (D7)
- [ ] Turn results displayed using `{#dig-iteration}` template (D7)
- [ ] Budget check performed (2 cycles max per session) (D7)
- [ ] Lock file removed via try/finally (D7)
