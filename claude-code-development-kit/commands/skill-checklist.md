---
name: skill-checklist
description: Quick validation checklist for creating and authoring Claude Code skills
version: 1.0.0
---

# Skill Creation Checklist

Use this checklist when creating or updating a Claude Code skill to ensure it meets quality standards.

## Frontmatter

### Required (validation errors if missing)

- [ ] File starts with `---` on line 1
- [ ] `name` field present (kebab-case, e.g., `my-skill-name`)
- [ ] `description` field present (200-400 characters recommended)
- [ ] Frontmatter closes with `---` (second occurrence)
- [ ] No YAML fields appear after the closing `---`

### Recommended (validation warnings if missing)

- [ ] `allowed-tools` field present with relevant tools
- [ ] `version` field present (semantic versioning: 1.0.0)
- [ ] `last_updated` field present (YYYY-MM-DD format)

### Optional (not validated)

- [ ] `created` field (YYYY-MM-DD format)

## Structure (Required)

- [ ] Main content starts with `# Skill Name` heading
- [ ] Has "When to Use" or "Overview" section
- [ ] Line count under 500 lines in SKILL.md
- [ ] Uses `@path` imports for content >300 lines

## Progressive Disclosure (Recommended)

- [ ] Supporting files in `templates/`, `examples/`, `reference/` folders
- [ ] Complex content moved to separate files with `@path` imports
- [ ] Main SKILL.md remains scannable (< 500 lines)

## Content Quality (Recommended)

- [ ] Clear "When to Use" section with specific triggers
- [ ] Clear "When NOT to Use" section
- [ ] Examples or templates provided (inline or via @path)
- [ ] Description includes trigger phrases users would say

## Validation

Run the validation hook to check:
```bash
./hooks/validate-skill-structure.sh ~/.claude/skills/<skill-name>/SKILL.md
```

Expected result: No errors (warnings acceptable)

## Testing

- [ ] Skill loads without YAML parsing errors
- [ ] Description triggers correctly when expected
- [ ] `@path` imports resolve to existing files
- [ ] Examples/templates are actionable

## Common Issues

**Frontmatter outside block:**
```yaml
---
name: my-skill
---
version: 1.0.0  # WRONG - should be inside ---
```

**Fix:** Move all YAML fields inside the `---` delimiters

**Line count exceeded:**
- Use `@path: reference/detailed-guide.md` to extract large sections
- Keep core guidance in SKILL.md, details in imported files

**Missing trigger phrases:**
- Add phrases users would naturally say in the description
- Example: "Use when creating new skills..." not just "Skill creation guide"

---

For detailed guidance, invoke the `authoring-skills` skill.
