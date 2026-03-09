# Skill Migration Plan

This document provides the workflow for migrating existing prompts, files, or workflows into properly structured Claude Code skills.

## Phase 1: Analyze Source Content

**Read and analyze the source file to understand:**

1. **Content Type** - Is it a:
   - Prompt template
   - Workflow/process guide
   - Reference documentation
   - Tool/command instructions

2. **Key Concepts** - Extract:
   - Main purpose and goals
   - Target use cases
   - Required tools or dependencies
   - Trigger phrases users might say

3. **Complexity Assessment**:
   - Simple (single-purpose, <100 lines) → Minimal skill
   - Medium (multi-step, 100-300 lines) → Standard skill
   - Complex (multi-phase, >300 lines) → Skill with @path imports

**Output:** Summary of content and recommended skill structure.

---

## Phase 2: Validate Skill Name

**Check the proposed skill name against conventions:**

### Naming Rules
- Use kebab-case (lowercase with hyphens)
- Prefer gerund form (verb-ing): `generating-`, `analyzing-`, `documenting-`
- Be descriptive but concise (2-4 words)
- Avoid generic names like `helper` or `utility`

### Good Examples
- `generating-reports`
- `analyzing-code`
- `documenting-apis`
- `resolving-issues`

### Bad Examples
- `mySkill` (not kebab-case)
- `skill1` (not descriptive)
- `do-stuff` (too vague)
- `comprehensive-multi-purpose-all-in-one-skill` (too long)

**If name does not meet standards, suggest alternatives before proceeding.**

---

## Phase 3: Create Skill Structure

### Directory Creation

```bash
mkdir -p ~/.claude/skills/<skill-name>
```

### File Structure (based on complexity)

**Minimal Skill:**
```
~/.claude/skills/<skill-name>/
└── SKILL.md
```

**Standard Skill:**
```
~/.claude/skills/<skill-name>/
├── SKILL.md
└── examples/
    └── example-1.md
```

**Complex Skill:**
```
~/.claude/skills/<skill-name>/
├── SKILL.md
├── templates/
│   └── template-1.md
├── examples/
│   └── example-1.md
└── reference/
    └── detailed-guide.md
```

---

## Phase 4: Generate SKILL.md

### Required Frontmatter

```yaml
---
name: <skill-name>
description: <200-400 chars with trigger phrases for discoverability>
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
version: 1.0.0
created: <YYYY-MM-DD>
last_updated: <YYYY-MM-DD>
---
```

### Required Sections

```markdown
# [Skill Title]

## When to Use This Skill

Use this skill when:
- [Trigger phrase 1]
- [Trigger phrase 2]
- [Trigger phrase 3]

### Do NOT Use This Skill When:
- [Exclusion case 1]
- [Exclusion case 2]

## Quick Reference

[Key concepts from migrated content]

## Instructions

[Step-by-step workflow from migrated content]

## Examples

[Examples extracted or generated from content]

## Validation

- [ ] [Validation item 1]
- [ ] [Validation item 2]
```

---

## Phase 5: Transform Content

### Content Transformation Rules

1. **Extract Instructions** → Structured numbered steps
2. **Identify Triggers** → Add to description and "When to Use"
3. **Create Examples** → If not present in source, generate realistic examples
4. **Add Validation** → Checklist items for quality assurance
5. **Apply Progressive Disclosure** → Move content >300 lines to supporting files

### Using @path Imports

For content exceeding recommended line limits:

```markdown
## Detailed Reference

@reference/detailed-guide.md
```

---

## Phase 6: Validate Created Skill

### Validation Checklist

Run these checks after creating the skill:

1. **YAML Validation**
   ```bash
   # Check frontmatter is valid
   head -20 ~/.claude/skills/<skill-name>/SKILL.md
   ```

2. **Required Fields Present**
   - [ ] `name` field matches directory name
   - [ ] `description` is 200-400 characters
   - [ ] `description` includes trigger phrases
   - [ ] `allowed-tools` lists relevant tools
   - [ ] `version` is semantic (X.Y.Z)

3. **Content Structure**
   - [ ] "When to Use" section present
   - [ ] "When NOT to Use" section present
   - [ ] Examples provided
   - [ ] Line count under 500 lines

4. **@path Resolution**
   - [ ] All `@path` imports point to existing files
   - [ ] Referenced files are within skill directory

### Validation Command

```bash
~/.claude/hooks/validate-skill-structure.sh ~/.claude/skills/<skill-name>/SKILL.md
```

Expected: No errors (warnings acceptable)

---

## Phase 7: Post-Migration

### Success Output

```
Skill "<skill-name>" created successfully!

Location: ~/.claude/skills/<skill-name>/

Files created:
- SKILL.md (main skill file)
- [any supporting files]

The skill can now be invoked by:
- Mentioning trigger phrases in requests
- Directly referencing the skill name

Next steps:
1. Review generated skill: cat ~/.claude/skills/<skill-name>/SKILL.md
2. Test invocation with a sample request
3. Iterate based on usage

Source file preserved at: [original-path]
```

### Testing the Skill

1. **Trigger Test** - Make a request using natural trigger phrases
2. **Functionality Test** - Execute the skill's main workflow
3. **Edge Case Test** - Try invalid or boundary inputs

---

## Error Handling

| Scenario | Resolution |
|----------|------------|
| Source file not found | Show path and ask for correction |
| Invalid skill name | Suggest compliant alternatives |
| Skill directory already exists | Offer rename, remove, or abort options |
| YAML parse error in generated SKILL.md | Show specific issue and fix |
| Content too large for SKILL.md | Split into @path imported files |
| Missing required sections | Prompt for additional information |

---

## Migration Examples

### Example 1: Simple Prompt Migration

**Source**: A prompt template for code review

**Result**:
```
~/.claude/skills/reviewing-code/
└── SKILL.md (80 lines)
```

### Example 2: Workflow Migration

**Source**: Multi-step deployment process

**Result**:
```
~/.claude/skills/deploying-services/
├── SKILL.md (150 lines)
├── templates/
│   └── deployment-checklist.md
└── examples/
    └── staging-deployment.md
```

### Example 3: Reference Doc Migration

**Source**: Comprehensive API documentation

**Result**:
```
~/.claude/skills/documenting-apis/
├── SKILL.md (200 lines with @path imports)
└── reference/
    ├── api-patterns.md
    └── endpoint-templates.md
```