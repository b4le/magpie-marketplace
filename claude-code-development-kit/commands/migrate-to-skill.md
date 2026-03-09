---
name: migrate-to-skill
description: Migrate a prompt or file into a properly structured Claude Code skill
argument-hint: "[file-path] [skill-name]"
version: 1.0.0
---

# Migrate to Skill

Migrate an existing file into a properly structured Claude Code skill.

## Arguments

- **$1** (file-path): Path to the file to migrate (prompt, markdown, or text file)
- **$2** (skill-name): Proposed name for the new skill (kebab-case, e.g., `generating-reports`)

## Pre-flight Validation

Before proceeding, validate inputs:

### 1. Check Source File Exists

```bash
ls "$1" 2>/dev/null
```

If file does not exist, STOP and show:
```
Error: Source file not found: $1

Please provide a valid file path to migrate.
```

### 2. Check for Existing Skill

```bash
ls ~/.claude/skills/$2/ 2>/dev/null
```

If directory exists, STOP and show:
```
Error: Skill "$2" already exists at ~/.claude/skills/$2/

Options:
1. Choose a different name: /migrate-to-skill $1 new-skill-name
2. Remove existing skill: rm -rf ~/.claude/skills/$2/
3. Abort migration
```

### 3. Validate Skill Name

Compare `$2` against naming conventions using the `authoring-skills` skill guidance. Suggest alternatives if the name does not meet standards:

- Must be kebab-case (lowercase with hyphens)
- Prefer gerund form (verb-ing prefix)
- Should be descriptive but concise

## Migration Workflow

Follow the migration plan to transform the source content. The migration plan covers:

1. **Analyze** - Understand source content type and complexity
2. **Validate Name** - Check skill name meets conventions
3. **Create Structure** - Set up skill directory
4. **Generate SKILL.md** - Create with proper frontmatter
5. **Transform Content** - Convert source to skill format
6. **Validate** - Run validation checks
7. **Post-Migration** - Test and iterate

For the complete migration workflow, invoke the `authoring-skills` skill.

## Example Usage

```bash
/migrate-to-skill ~/prompts/code-review-prompt.md reviewing-code
/migrate-to-skill ./old-workflow.txt generating-reports
/migrate-to-skill /path/to/api-docs.md documenting-apis
```

## Notes

- The original source file is preserved (not deleted)
- Skills are created in `~/.claude/skills/<skill-name>/`
- For complex content (>300 lines), use @path imports to supporting files
