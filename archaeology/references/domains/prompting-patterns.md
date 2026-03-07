---
domain: prompting-patterns
status: active
maintainer: archaeology-skill
last_updated: 2026-02-26
version: 1.0.0
agent_count: 5

keywords:
  primary:
    - CLAUDE.md
    - system prompt
    - skill
    - /use
    - "mode:creative"
    - "mode:teaching"
    - "mode:challenger"
  secondary:
    - few-shot
    - chain-of-thought
    - example
    - template
    - instruction
    - extended thinking
    - thinking mode
    - tool_choice
    - prefill
    - constraint
    - guideline
    - "<example>"
    - "<thinking>"
    - "<context>"
    - MUST
    - NEVER
    - "/mode:"
    - "/gen:"
  exclusion:
    - API key
    - secret
    - password
    - token
    - credential
    - bearer
    - auth token
    - "authorization:"
    - API_KEY
    - SECRET_KEY

locations:
  - path: "~/.claude/projects/-Users-*-{PROJECT_PATH_PATTERN}/"
    purpose: "Conversation *.jsonl files and subagents/ subdirectories"
    priority: high
  - path: "~/{PROJECT_ROOT}/CLAUDE.md"
    purpose: "Project-level instructions"
    priority: high
  - path: "~/{PROJECT_ROOT}/.claude/"
    purpose: "Project Claude config"
    priority: high
  - path: "~/.claude/CLAUDE.md"
    purpose: "Global instructions"
    priority: medium
  - path: "~/.claude/skills/"
    purpose: "Skill definitions"
    priority: medium
  - path: "~/.claude/output-styles/"
    purpose: "Modes and generators"
    priority: medium
  - path: "~/.claude/commands/"
    purpose: "Command patterns"
    priority: low

outputs:
  - file: README.md
    required: true
    template: readme
  - file: claude-md-patterns.md
    required: true
    template: patterns
  - file: prompt-techniques.md
    required: true
    template: prompts
  - file: skill-usage.md
    required: false
    template: patterns
  - file: mode-generator-usage.md
    required: false
    template: patterns
---

# Prompting Patterns Domain

**Description:** Claude usage patterns, prompt engineering techniques, and CLAUDE.md evolution

---

## Metadata

| Field | Value |
|-------|-------|
| Domain ID | prompting-patterns |
| Version | 1.0.0 |
| Created | 2026-02-26 |
| Updated | 2026-02-26 |
| Maintainer | archaeology-skill |

## Search Keywords

**Primary keywords:**
- CLAUDE.md, system prompt, skill, /use, mode:

**Secondary keywords:**
- few-shot, chain-of-thought, example, template, instruction
- output style, tone, format
- thinking, reasoning, step-by-step

**Exclusion keywords:**
- API key, secret, password, token, credential

## Search Locations

> **Note:** Agent labels below are illustrative for readability. In practice, each agent searches all locations — assignment is not 1:1.

| Agent | Location | Purpose | Priority |
|-------|----------|---------|----------|
| Explore-1 | ~/.claude/projects/-Users-*-{PROJECT_PATH_PATTERN}/ | Conversation history | High |
| Explore-2 | ~/{PROJECT_ROOT}/CLAUDE.md, ~/{PROJECT_ROOT}/.claude/ | Project instructions | High |
| Explore-3 | ~/.claude/CLAUDE.md, ~/.claude/skills/ | Global prompts & skills | Medium |
| Explore-4 | ~/.claude/output-styles/ | Modes and generators | Medium |
| Explore-5 | ~/.claude/commands/ | Command patterns | Low |

## Extraction Pattern

For each instance found, extract:
- The prompt/instruction (verbatim)
- Context: what task it was used for
- Effectiveness: did it produce desired output?
- Evolution: how did it change over time?
- Tool usage patterns: what tools were called and in what sequence

**Distinguish between:**
- System prompts (CLAUDE.md files)
- Runtime prompts (conversation messages)

**For CLAUDE.md patterns:**
- Section structure
- Instruction patterns (MUSTs, examples, constraints)
- What worked vs what was revised

**For skill usage:**
- Which skills invoked
- Arguments passed
- Output quality

## Output Files

| File | Content | Required |
|------|---------|----------|
| README.md | Index and summary | Yes |
| claude-md-patterns.md | CLAUDE.md structure patterns | Yes |
| prompt-techniques.md | Effective prompt patterns | Yes |
| skill-usage.md | Skill invocation patterns | If found |

## Validation Rules

**Pre-execution:**
- At least one CLAUDE.md or conversation exists
- Output directory is writable

**Post-execution:**
- Results found OR no-results file
- No sensitive data in output (API keys, etc.)
- All files have frontmatter

## Success Criteria

Findings should answer:
1. What prompting techniques are used?
2. How is CLAUDE.md structured?
3. What skills are most effective?
4. What patterns produce best results?
5. How did prompting approaches evolve across sessions?

## Anti-Patterns

**Do NOT extract:**
- API keys, secrets, credentials
- Personal data beyond git metadata
- Raw conversation dumps without analysis
- Prompts that failed without learning context
- Prompts containing hardcoded file paths specific to one machine

## Quick Extraction Commands

For manual inspection:

```bash
# Find CLAUDE.md references in conversations
grep -r "CLAUDE.md" ~/.claude/projects/ --include="*.jsonl" | head -20

# Find skill invocations
grep -r "/use " ~/.claude/projects/ --include="*.jsonl"

# Find mode commands
grep -r "mode:creative\|mode:teaching\|mode:challenger" ~/.claude/projects/

# Find system prompt patterns
grep -r "system prompt\|system-reminder" ~/.claude/projects/ --include="*.jsonl"

# Find few-shot examples in conversations
grep -r "<example>" ~/.claude/projects/ --include="*.jsonl"

# List all skills used
grep -r '"skill":' ~/.claude/projects/ --include="*.jsonl" | jq -r '.skill' 2>/dev/null | sort | uniq -c | sort -rn
```

## If No Results Found

If extraction yields no findings:

1. **Inform user:** "No prompting patterns found in project history"
2. **Suggest alternatives:**
   - Check if CLAUDE.md exists: `ls -la {PROJECT_ROOT}/CLAUDE.md`
   - Look for global patterns: `/archaeology prompting-patterns` in home directory
   - Verify conversation history exists in `~/.claude/projects/`
3. **Common reasons for no results:**
   - New project with no Claude Code history
   - Conversations cleared or expired
   - Project uses different prompting approach (not captured in history)
4. **Do NOT create empty output files**

## Completion Criteria

Prompting patterns extraction is complete when:

- [ ] All search locations checked (conversations, CLAUDE.md files, skills, output-styles)
- [ ] CLAUDE.md structure patterns documented
- [ ] Prompt engineering techniques catalogued
- [ ] Skill usage patterns identified (if any)
- [ ] Output files written per domain spec
- [ ] No placeholder text in outputs
- [ ] README.md links all generated findings
