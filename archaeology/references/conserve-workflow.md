# Conservation Workflow (C1-C7)

> **Reference file** — This file is referenced from SKILL.md. Do not rename or move without updating the reference.
>
> Conservation extracts atomic narrative artifacts from project history, generates a default exhibition, and exports to the central work-log.

**Command:** `/archaeology conserve [project-name] [--no-export]`

---

### Conservation Step C1: Resolve Project Context

Reuses SKILL.md Step 1 logic. Sets `PROJECT_NAME`, `PROJECT_SLUG`, `ARCHAEOLOGY_DIR`, `CENTRAL_BASE`, `NO_EXPORT`.

```javascript
NO_EXPORT = args.includes('--no-export');

// Standard project resolution (same as survey S1, workstyle W1)
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
ARTIFACTS_DIR = `${ARCHAEOLOGY_DIR}/artifacts`;
CENTRAL_BASE = `~/.claude/data/visibility-toolkit/work-log/archaeology`;
CENTRAL_PROJECT_DIR = `${CENTRAL_BASE}/${PROJECT_SLUG}`;
CENTRAL_ARTIFACTS_DIR = `${CENTRAL_PROJECT_DIR}/artifacts`;
```

Create directories:

```bash
mkdir -p ${ARTIFACTS_DIR}
if (!NO_EXPORT) mkdir -p ${CENTRAL_ARTIFACTS_DIR}
```

---

### Conservation Step C2: Load Prior Extractions

Scan for existing `findings.json` files and build a narrative seed map.

```javascript
// Find all domain findings for this project
findings_files = Glob(`${CENTRAL_PROJECT_DIR}/*/findings.json`);
// Also check local
local_findings = Glob(`${ARCHAEOLOGY_DIR}/*/findings.json`);
findings_files = [...new Set([...findings_files, ...local_findings])];

HAS_FINDINGS = findings_files.length > 0;
narrative_seeds = [];

if (HAS_FINDINGS) {
  for (file of findings_files) {
    data = JSON.parse(Read(file));
    // Extract highlights and their evidence for narrative seeding
    for (finding of data.findings.filter(f => f.confidence === 'high')) {
      narrative_seeds.push({
        finding_id: finding.id,
        domain: data.domain,
        title: finding.title,
        type: finding.type,
        confidence: finding.confidence || 'low',
        description: finding.description,
        evidence: finding.evidence,
        tags: finding.tags
      });
    }
  }
}

// Also check for survey.md for project context
HAS_SURVEY = exists(`${ARCHAEOLOGY_DIR}/survey.md`) || exists(`${CENTRAL_PROJECT_DIR}/survey.md`);
```

---

### Conservation Step C3: Session Selection

Two paths depending on whether findings exist.

```javascript
conversation_files = Glob(`${HISTORY_DIR}/**/*.jsonl`);

// Minimum data check
if (conversation_files.length === 0) {
  error("No session history found for this project.");
}
if (conversation_files.length < 3) {
  warn(`Only ${conversation_files.length} sessions found. Conservation may produce low-confidence artifacts.`);
}

if (HAS_FINDINGS) {
  // FINDINGS-GUIDED: select sessions referenced in finding evidence
  referenced_sessions = new Set();
  for (seed of narrative_seeds) {
    for (evidence_item of seed.evidence) {
      // Evidence items often contain session file paths or identifiers
      matching = conversation_files.filter(f =>
        evidence_item.includes(basename(f)) || evidence_item.includes(f)
      );
      matching.forEach(m => referenced_sessions.add(m));
    }
  }

  // If evidence paths don't resolve to specific sessions, fall back to heuristic
  if (referenced_sessions.size < 3) {
    // Supplement with heuristic sampling
    sampled = heuristic_sample(conversation_files);
    sampled.forEach(s => referenced_sessions.add(s));
  }

  selected_sessions = [...referenced_sessions].slice(0, 8);
} else {
  // HEURISTIC FALLBACK: sample like workstyle W4
  warn("No prior extractions found. Running with session sampling only -- confidence will be lower. Run /archaeology survey first for better results.");
  selected_sessions = heuristic_sample(conversation_files);
}

function heuristic_sample(files) {
  sampled = [];
  // Longest (most data)
  sampled.push(max_by_size(files));
  // Most recent (current state)
  sampled.push(max_by_mtime(files));
  // Earliest (origin story)
  sampled.push(min_by_mtime(files));
  // 2-3 random from middle (diversity)
  middle = files.filter(f => !sampled.includes(f));
  sampled.push(...random_sample(middle, 3));
  return unique(sampled).slice(0, 6);
}
```

---

### Conservation Step C4: Narrative Extraction

Dispatch 5 Explore agents, each focused on specific artifact types.

```javascript
// Build type-specific seed context per agent (see build_seed_context below)
// seed_context is assembled per-agent in the dispatch loop below

function distribute_sessions(sessions, num_agents) {
  // Anchored overlap: earliest + longest shared by all agents.
  // Remaining sessions distributed round-robin.
  // Prerequisite: C3 session gate (< 3 sessions) must have fired before here.

  anchors = [
    min_by_mtime(sessions),  // earliest -- origin story context
    max_by_size(sessions)    // longest -- densest narrative material
  ].filter(unique);  // deduplicate if same session is both

  remainder = sessions.filter(s => !anchors.includes(s));

  agent_sessions = Array.from({ length: num_agents }, () => [...anchors]);
  for (let i = 0; i < remainder.length; i++) {
    agent_sessions[i % num_agents].push(remainder[i]);
  }

  return agent_sessions;
}

TYPE_SEED_MAP = {
  'shipment':  ['pattern', 'outcome', 'workflow'],
  'decision':  ['decision', 'pattern'],
  'incident':  ['failure', 'decision'],
  'discovery': ['pattern', 'failure', 'outcome'],
  'tale':      ['pattern', 'failure', 'outcome', 'workflow'],
  'practice':  ['workflow', 'pattern']
};

function build_seed_context(narrative_seeds, agent_types, max_seeds = 12, max_chars = 2500) {
  type_relevant = narrative_seeds.filter(s =>
    agent_types.some(t => TYPE_SEED_MAP[t].includes(s.type))
  );

  high_sig = narrative_seeds
    .filter(s => !type_relevant.includes(s))
    .filter(s => s.confidence === 'high')
    .slice(0, 3);

  combined = [...type_relevant, ...high_sig]
    .sort((a, b) => {
      conf_order = { high: 0, medium: 1, low: 2 };
      if (conf_order[a.confidence] !== conf_order[b.confidence])
        return conf_order[a.confidence] - conf_order[b.confidence];
      return a.description.length - b.description.length;
    })
    .slice(0, max_seeds);

  result = [];
  char_count = 0;
  for (seed of combined) {
    line = `[${seed.domain}/${seed.finding_id}] ${seed.title}: ${seed.description}`;
    if (char_count + line.length > max_chars) break;
    result.push(line);
    char_count += line.length;
  }

  if (result.length < combined.length) {
    result.push(`[${combined.length - result.length} additional seeds omitted for brevity]`);
  }

  return result.join('\n');
}

// Assign sessions to agents using anchored overlap strategy:
// earliest and longest sessions shared by all agents, remainder distributed round-robin
session_assignments = distribute_sessions(selected_sessions, 5);

agents = [
  {
    focus: "Shipments: features delivered, launches, milestones reached",
    types: ["shipment"],
    sections: "What was built / Why it matters / The result"
  },
  {
    focus: "Decisions: choices made, technology selections, architecture pivots",
    types: ["decision"],
    sections: "The options / The constraints / The choice / What happened next"
  },
  {
    focus: "Incidents: things that broke, failures, near-misses, recovery stories",
    types: ["incident"],
    sections: "What broke / The response / The fix / The systemic change"
  },
  {
    focus: "Discoveries: surprises, busted assumptions, unexpected findings",
    types: ["discovery"],
    sections: "The assumption / The evidence / The new understanding"
  },
  {
    focus: "Tales and Practices: origin stories, narrative arcs, process evolution, workflows",
    types: ["tale", "practice"],
    sections: "Tale: The setup / The complication / The resolution. Practice: What we do / Why it emerged / What it solves"
  }
];

for (i = 0; i < agents.length; i++) {
  seed_context = HAS_FINDINGS
    ? build_seed_context(narrative_seeds, agents[i].types, 12, 2500)
    : 'No prior findings available. Extract narrative from session content directly.';

  Agent({
    subagent_type: "Explore",
    prompt: `You are extracting narrative artifacts from Claude Code session history.

PROJECT: ${PROJECT_NAME}
FOCUS: ${agents[i].focus}
ARTIFACT TYPES TO FIND: ${agents[i].types.join(', ')}
NATURAL SECTIONS: ${agents[i].sections}

SESSIONS TO READ:
${session_assignments[i].join('\n')}

PRIOR FINDINGS (use as seeds -- look for the stories behind these):
${seed_context}

For each narrative you find, return an artifact using this EXACT format:

<artifact>
<type>${agents[i].types.join('|')}</type>
<title>max 80 chars, concrete nouns not abstractions</title>
<confidence evidence="quote or session reference">high|medium|low</confidence>
<significance>1-10</significance>
<tags>comma-separated</tags>
<session_date>YYYY-MM-DD, best estimate</session_date>
<source_sessions>file paths</source_sessions>
<source_findings>finding IDs, or none</source_findings>
<body>
## The Situation
[2-4 sentences]
## What Happened
[core narrative, 80-150 words, concrete details]
## The Insight
[1-2 sentences]
## Evidence
[specific: session references, error messages, metrics, code patterns]
</body>
</artifact>

Here is an example of a well-formed artifact:

<artifact>
<type>incident</type>
<title>Context Overflow on First Parallel Dispatch</title>
<confidence evidence="Session 2026-02-15T10-00.jsonl: 'context usage 98.2%'">high</confidence>
<significance>7</significance>
<tags>orchestration, context-window, parallel</tags>
<session_date>2026-02-15</session_date>
<source_sessions>2026-02-15T10-00.jsonl</source_sessions>
<source_findings>f-001, f-002</source_findings>
<body>
## The Situation
[narrative]
## What Happened
[core narrative]
## The Insight
[1-2 sentences]
## Evidence
[specifics]
</body>
</artifact>

Now extract artifacts from the sessions listed above. Return 0-4 artifacts in this exact format.

Rules:
- Concrete nouns ("JSONL files", "sub-agents", "findings.json"), not abstractions ("the data", "the process")
- Failure stories must name what actually broke, not "there were challenges"
- Include at least one number in before/after comparisons (even estimates with caveats)
- If evidence is weak, set confidence to low -- do not fabricate detail
- Return 0 artifacts if nothing of this type exists (do not force creation)
- Maximum 4 artifacts per agent run
- Return ONLY <artifact> blocks. Do not include any text outside of artifact tags. Do not explain your reasoning.`
  });
}
```

Wait for all agents to complete.

---

### Conservation Step C5: Artifact Assembly

Parse agent outputs and write individual artifact files.

```javascript
function extract_xml_field(text, tag) {
  match = text.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)<\\/${tag}>`));
  return match ? match[1].trim() : null;
}

function parse_xml_artifact(content) {
  return {
    type: extract_xml_field(content, 'type'),
    title: extract_xml_field(content, 'title'),
    confidence: extract_xml_field(content, 'confidence'),
    significance: extract_xml_field(content, 'significance'),
    tags: extract_xml_field(content, 'tags'),
    session_date: extract_xml_field(content, 'session_date'),
    source_sessions: extract_xml_field(content, 'source_sessions'),
    source_findings: extract_xml_field(content, 'source_findings'),
    body: extract_xml_field(content, 'body')
  };
}

function validate_artifact(parsed) {
  VALID_TYPES = ['shipment', 'decision', 'incident', 'discovery', 'tale', 'practice'];
  VALID_CONF = ['high', 'medium', 'low'];
  errors = [];

  for (field of ['type', 'title', 'body']) {
    if (!parsed[field]) errors.push(`missing_${field}`);
  }
  if (parsed.type && !VALID_TYPES.includes(parsed.type.toLowerCase())) errors.push('invalid_type');
  sig = parseInt(parsed.significance);
  if (isNaN(sig) || sig < 1 || sig > 10) errors.push('invalid_significance');
  if (parsed.body && parsed.body.length < 100) errors.push('body_too_short');

  return { valid: errors.length === 0, errors, fixable: errors.every(e => ['invalid_significance'].includes(e)) };
}

all_raw_artifacts = [];

// Per-agent diagnostic tracking
agent_diagnostics = [];
for (i = 0; i < agent_results.length; i++) {
  result = agent_results[i];
  diagnostic = { agent: i, focus: agents[i].focus, status: 'ok', artifacts_found: 0, parse_failures: 0 };

  if (!result || result.trim().length === 0) { diagnostic.status = 'empty'; agent_diagnostics.push(diagnostic); continue; }
  if (!result.includes('<artifact>')) { diagnostic.status = 'unstructured'; agent_diagnostics.push(diagnostic); continue; }

  blocks = result.split('<artifact>').filter(Boolean);
  for (block of blocks) {
    if (!block.includes('</artifact>')) continue;
    content = block.split('</artifact>')[0].trim();
    parsed = parse_xml_artifact(content);
    validation = validate_artifact(parsed);
    if (validation.valid) { all_raw_artifacts.push(parsed); diagnostic.artifacts_found++; }
    else if (validation.fixable) { all_raw_artifacts.push(auto_fix(parsed)); diagnostic.artifacts_found++; }
    else { diagnostic.parse_failures++; }
  }
  if (diagnostic.artifacts_found === 0 && diagnostic.parse_failures === 0) diagnostic.status = 'no_findings';
  else if (diagnostic.parse_failures > 0 && diagnostic.artifacts_found > 0) diagnostic.status = 'partial';
  agent_diagnostics.push(diagnostic);
}

// Hard error at 3+ structural failures
structural_failures = agent_diagnostics.filter(d => d.status === 'empty' || d.status === 'unstructured').length;
if (structural_failures >= 3) error(`${structural_failures}/5 extraction agents returned unusable output. Conservation aborted.`);
if (structural_failures >= 1) warn(`${structural_failures}/5 agents failed structurally. Output may be missing artifact types.`);

// Deduplicate by title similarity (>80% overlap = duplicate)
artifacts = deduplicate(all_raw_artifacts);

// Sort by significance descending, then by type order
TYPE_ORDER = ['shipment', 'decision', 'incident', 'discovery', 'tale', 'practice'];
artifacts.sort((a, b) => {
  if (b.significance !== a.significance) return b.significance - a.significance;
  return TYPE_ORDER.indexOf(a.type) - TYPE_ORDER.indexOf(b.type);
});

// Assign IDs and write files
for (i = 0; i < artifacts.length; i++) {
  art = artifacts[i];
  art.id = `art-${String(i + 1).padStart(3, '0')}`;
  art.uri = `arch://${PROJECT_SLUG}/${art.id}`;
  art.conserved_at = current_date();
  art.status = 'draft';
  art.project = PROJECT_SLUG;
  art.revised = null;
  art.sources = {
    sessions: (art.source_sessions || '').split(/[,\n]+/).map(p => p.trim()).filter(Boolean).map(p => ({ path: p, label: basename(p) })),
    findings: (art.source_findings && art.source_findings !== 'none')
      ? art.source_findings.split(/[,\s]+/).map(id => ({ id: id.trim(), title: '' })).filter(f => f.id)
      : []
  };

  // Build frontmatter — inline, no helper function
  // Required scalar fields
  fm  = `id: "${art.id}"\n`;
  fm += `project: "${art.project}"\n`;
  fm += `uri: "${art.uri}"\n`;
  fm += `type: "${art.type}"\n`;
  fm += `title: "${art.title}"\n`;
  fm += `confidence: "${art.confidence}"\n`;
  fm += `significance: ${art.significance}\n`;
  fm += `tags:\n` + art.tags.map(t => `  - "${t}"`).join('\n') + '\n';
  fm += `conserved_at: "${art.conserved_at}"\n`;
  fm += `session_date: "${art.session_date}"\n`;
  fm += `status: "${art.status}"\n`;
  fm += `revised: ${art.revised === null ? 'null' : '"' + art.revised + '"'}\n`;
  // Nested sources block
  fm += `sources:\n`;
  fm += `  sessions:\n`;
  for (s of art.sources.sessions) {
    fm += `    - path: "${s.path}"\n`;
    fm += `      label: "${s.label}"\n`;
  }
  fm += `  findings:\n`;
  for (f of art.sources.findings) {
    fm += `    - id: "${f.id}"\n`;
    fm += `      title: "${f.title}"\n`;
  }
  // Drop the flat fields so they don't leak into downstream serialisation
  delete art.source_sessions;
  delete art.source_findings;
  frontmatter = fm;

  // Build body with type-appropriate sections
  body = art.body;  // Already structured by agent

  file_content = `---\n${frontmatter}\n---\n\n# ${art.title}\n\n${body}`;
  Write(`${ARTIFACTS_DIR}/${art.id}.md`, file_content);
}

// Write _index.json
index = build_artifact_index(artifacts, PROJECT_SLUG);
Write(`${ARTIFACTS_DIR}/_index.json`, JSON.stringify(index, null, 2));
```

Confidence threshold check:

```javascript
medium_plus = artifacts.filter(a => a.confidence === 'high' || a.confidence === 'medium').length;
if (artifacts.length === 0) {
  error("0 artifacts extracted. Do not create output files. Run /archaeology survey and domain extraction first.");
}
if (medium_plus < 3) {
  warn("Insufficient narrative evidence. Run /archaeology survey and domain extraction first.");
}
```

---

### Conservation Step C6: Exhibition Generation

Assemble default exhibition from artifacts.

```javascript
// Group artifacts by type
by_type = {};
for (art of artifacts) {
  if (!by_type[art.type]) by_type[art.type] = [];
  by_type[art.type].push(art);
}

// Build exhibition.md
exhibition_sections = [];
exhibition_manifest_sections = [];

for (type of TYPE_ORDER) {
  if (!by_type[type] || by_type[type].length === 0) continue;

  section_heading = type.charAt(0).toUpperCase() + type.slice(1) + 's';
  if (type === 'practice') section_heading = 'Practices';
  if (type === 'discovery') section_heading = 'Discoveries';

  items = by_type[type].map(a =>
    `- [${a.title}](artifacts/${a.id}.md) -- ${a.tags.slice(0, 3).join(', ')}`
  ).join('\n');

  exhibition_sections.push(`## ${section_heading}\n\n${items}`);
  exhibition_manifest_sections.push({
    heading: section_heading,
    artifact_ids: by_type[type].map(a => a.id),
    connector: null
  });
}

// Type summary for header
type_counts = TYPE_ORDER
  .filter(t => by_type[t] && by_type[t].length > 0)
  .map(t => `${by_type[t].length} ${t}${by_type[t].length > 1 ? 's' : ''}`)
  .join(', ');

exhibition_md = `# ${PROJECT_NAME} -- Conservation

> ${artifacts.length} artifacts conserved on ${current_date()} | ${type_counts}

${exhibition_sections.join('\n\n')}

---
*Conserved by archaeology skill -- command: conserve*
`;

Write(`${ARCHAEOLOGY_DIR}/exhibition.md`, exhibition_md);

// Write manifest
exhibition_json = {
  id: "default",
  project: PROJECT_SLUG,
  title: `${PROJECT_NAME} -- Conservation`,
  generated_at: new Date().toISOString(),
  artifact_count: artifacts.length,
  sections: exhibition_manifest_sections
};
Write(`${ARCHAEOLOGY_DIR}/_exhibition.json`, JSON.stringify(exhibition_json, null, 2));
```

---

### Conservation Step C7: Export + Index Updates

```javascript
if (!NO_EXPORT) {
  // Copy artifacts to central
  for (art of artifacts) {
    Write(`${CENTRAL_ARTIFACTS_DIR}/${art.id}.md`, Read(`${ARTIFACTS_DIR}/${art.id}.md`));
  }
  Write(`${CENTRAL_ARTIFACTS_DIR}/_index.json`, Read(`${ARTIFACTS_DIR}/_index.json`));

  // Copy exhibition
  Write(`${CENTRAL_PROJECT_DIR}/exhibition.md`, exhibition_md);
  Write(`${CENTRAL_PROJECT_DIR}/_exhibition.json`, JSON.stringify(exhibition_json, null, 2));

  // Update global artifacts registry
  update_artifacts_registry(artifacts, PROJECT_SLUG);

  // Update SUMMARY.md with Key Narratives section
  update_summary_with_narratives(artifacts, CENTRAL_PROJECT_DIR);

  // Optionally add artifact_id forward links to findings.json
  if (HAS_FINDINGS) {
    add_forward_links_to_findings(artifacts, narrative_seeds, findings_files);
  }

  // Update central INDEX.md
  update_central_index();
}

// Always update local index
update_local_archaeology_index();  // Updated to detect artifacts/ directory
```

**`update_artifacts_registry()` helper:**

```javascript
function update_artifacts_registry(new_artifacts, project_slug) {
  REGISTRY_PATH = `${CENTRAL_BASE}/artifacts-registry.json`;

  // Read existing or create new
  registry = exists(REGISTRY_PATH) ? JSON.parse(Read(REGISTRY_PATH)) : {
    version: 1, last_updated: null, total_artifacts: 0,
    artifacts: [], tag_index: {}, type_index: {}
  };

  // Remove existing artifacts for this project (replace, not merge)
  registry.artifacts = registry.artifacts.filter(a => a.project !== project_slug);

  // Add new artifacts
  for (art of new_artifacts) {
    registry.artifacts.push({
      id: art.id, project: project_slug, uri: art.uri,
      type: art.type, title: art.title, confidence: art.confidence,
      significance: art.significance, tags: art.tags,
      conserved_at: art.conserved_at, status: 'active'
    });
  }

  // Rebuild indices
  registry.tag_index = {};
  registry.type_index = {};
  for (art of registry.artifacts) {
    for (tag of art.tags) {
      if (!registry.tag_index[tag]) registry.tag_index[tag] = [];
      registry.tag_index[tag].push(art.uri);
    }
    if (!registry.type_index[art.type]) registry.type_index[art.type] = [];
    registry.type_index[art.type].push(art.uri);
  }

  registry.total_artifacts = registry.artifacts.length;
  registry.last_updated = new Date().toISOString();

  Write(REGISTRY_PATH, JSON.stringify(registry, null, 2));
}
```

> `update_central_index()` — see SKILL.md Step 5c (do not redefine here).
> `update_local_archaeology_index()` — see `references/survey-workflow.md` (do not redefine here). Updated to detect `artifacts/` directory and `exhibition.md`.

---

### Error Handling

| Scenario | Behaviour |
|----------|-----------|
| 0 sessions | Error: "No session history found for {project}." |
| < 3 sessions | Warn, proceed with low confidence, note in output |
| No prior findings | Warn, fall back to heuristic session sampling |
| Findings evidence doesn't resolve to sessions | Supplement with heuristic sampling |
| < 3 artifacts at medium+ confidence | Warn: "Insufficient narrative evidence. Run /archaeology survey and domain extraction first." |
| 0 artifacts extracted | Do not create output files. Suggest running survey/extraction first. |
| `--no-export` | Skip central writes, registry update, SUMMARY.md update |
| Partial execution (crash mid-run) | Re-run conserve -- all writes are unconditional overwrites. Registry self-heals. No manual cleanup needed. |
| 3+ structural agent failures | Error: "{N}/5 extraction agents returned unusable output. Conservation aborted." |

---

### Conservation Completion Criteria

Conservation run is complete when:
- [ ] Project context resolved (C1)
- [ ] Prior extractions scanned for narrative seeds (C2)
- [ ] Sessions selected (findings-guided or heuristic fallback) (C3)
- [ ] All 5 extraction agents completed (C4)
- [ ] Artifacts assembled with IDs, frontmatter, and body (C5)
- [ ] Default exhibition generated (C6)
- [ ] **(Unless --no-export)** Artifacts exported to central work-log
- [ ] **(Unless --no-export)** Global artifacts registry updated
- [ ] **(Unless --no-export)** SUMMARY.md updated with Key Narratives
- [ ] **(Unless --no-export)** Central INDEX.md updated
- [ ] Local INDEX.md updated with conservation entry
- [ ] Completion summary displayed with file locations

---

### Conservation Completion Display

**MUST use the exact template from `output-templates.md#conserve-completion`.** Do not reformat, add tables, add emoji, or alter the structure.

Key variable mappings:
- `{artifact_count}` -- total artifacts from C5
- `{high_count}`, `{medium_count}`, `{low_count}` -- confidence distribution from C5
- `{type}` / `{count}` -- one line per type with artifacts, from C5 grouping
- `{PROJECT_SLUG}` -- from C1
