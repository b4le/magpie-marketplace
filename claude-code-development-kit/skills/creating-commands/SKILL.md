---
name: creating-commands
description: Guide for creating custom slash commands in Claude Code with proper structure, frontmatter, arguments, and best practices. Use when users want to create, design, or author new slash commands, build command templates, or learn command development patterns.
version: 1.2.0
created: 2025-11-20
last_updated: 2026-02-28
tags:
  - commands
  - authoring
  - slash-commands
---

## When to Use This Skill

Use this skill when:
- Creating, designing, or authoring new slash commands
- Building command templates or learning command development patterns
- Understanding command structure, frontmatter, and argument handling
- Need best practices for command authoring

### Do NOT Use This Skill When:
- ❌ Just using existing slash commands → Use `using-commands` instead
- ❌ Creating skills → Use `authoring-skills` instead
- ❌ Creating complete plugins → Use `creating-plugins` instead (includes commands)
- ❌ Task is too simple for a command → Just write the prompt directly

> **Note:** Slash commands are considered a legacy mechanism. For new development, prefer skills (`authoring-skills`) which offer better discoverability, richer metadata, and progressive disclosure via `@path` imports.

## Command Anatomy

A command is a Markdown file stored in `.claude/commands/` (project) or `~/.claude/commands/` (personal). It has two sections:

```
[frontmatter]      ← optional YAML between --- delimiters
[body]             ← the prompt content sent to Claude
```

Full example:

```markdown
---
description: Review a pull request and report issues
argument-hint: <pr-number>
---

Review PR $1:

!gh pr view $1
!gh pr diff $1

Check for breaking changes, security issues, and test coverage.
Follow conventions in @CLAUDE.md.
```

## Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `description` | Recommended | Shown in `/help` and the command picker |
| `argument-hint` | Recommended | Usage hint displayed alongside the command |
| `allowed-tools` | Optional | Restrict which tools Claude may use |
| `disable-model-invocation` | Optional | Set to `true` to prevent Claude from auto-loading; useful for workflows you want to trigger manually |
| `user-invocable` | Optional | Set to `false` to hide from the slash-command picker |

All fields are optional, but `description` and `argument-hint` significantly improve discoverability.

## Argument Handling

Arguments are passed after the command name at invocation time:

```
/command-name arg1 arg2 arg3
```

Inside the command body, access them via:

| Variable | Alias | Description |
|----------|-------|-------------|
| `$ARGUMENTS` | — | All arguments as a single string |
| `$1` | `$ARGUMENTS[0]` | First argument |
| `$2` | `$ARGUMENTS[1]` | Second argument |
| `$3` | `$ARGUMENTS[2]` | Third argument (and so on) |

Example body using arguments:

```markdown
Refactor $1 to use $2 pattern.

1. Read the current implementation of $1
2. Apply the $2 pattern
3. Update tests
```

## Environment Variables

Commands have access to a limited set of substitution variables in `!` bash lines and in the prompt body.

### Available Variables

| Variable | Description |
|----------|-------------|
| `$ARGUMENTS` | All arguments passed to the command as a single string |
| `$1`, `$2`, `$3` ... | Individual positional arguments (aliases: `$ARGUMENTS[0]`, `$ARGUMENTS[1]`, etc.) |
| `${CLAUDE_SESSION_ID}` | Unique identifier for the current Claude Code session. Useful for logging, cache keys, or tracking multi-step workflows across bash commands. |

> **Note on `${CLAUDE_PLUGIN_ROOT}`:** This variable is documented as resolving to the plugin's installation directory, but there is a known bug ([GitHub issue #9354](https://github.com/anthropics/claude-code/issues/9354)) where it does **not** expand inside command markdown files. It works in plugin JSON configs but not in `.md` command files. Avoid relying on it in command bodies until this is resolved.

> **Note on `${CLAUDE_PROJECT_DIR}` and `${CLAUDE_CONFIG_DIR}`:** `CLAUDE_PROJECT_DIR` is available in hook scripts only, not in command markdown. `CLAUDE_CONFIG_DIR` does not exist as a substitution variable. For hook variable reference, see the `creating-plugins` skill: `@skills/creating-plugins/reference/environment-variables.md`.

### Usage in Bash Lines

Substitution variables work in `!` bash lines:

```markdown
!echo "Session: ${CLAUDE_SESSION_ID}" >> /tmp/command-log.txt
!gh pr view $1
```

For the full environment variable reference including hook contexts, see the `creating-plugins` skill: `@skills/creating-plugins/reference/environment-variables.md`.

## File References

Prefix any path with `@` to import its content into the prompt at load time:

```markdown
Follow the conventions in @CLAUDE.md.
Use the schema defined in @src/types/api.ts.
```

File references are resolved relative to the project root. Use them to:
- Pull in project memory (`@CLAUDE.md`)
- Include relevant source files for context
- Reference configuration or schema files

## Bash Execution

Prefix a line with `!` to execute a shell command. The output is captured and included in the prompt sent to Claude:

```markdown
Review the current state of changes:

!git status
!git diff

Summarize the changes and suggest a commit message.
```

For pre-processing steps that produce structured output before Claude sees it, chain `!` bash lines to capture and format data before the prompt instructions.

## Command Locations and Namespacing

Commands are stored in `.claude/commands/` (project, version controlled) or `~/.claude/commands/` (personal, all projects). Plugin commands live in a plugin's `commands/` directory.

Organize related commands in subdirectories to create namespaced invocations: a file at `git/commit.md` becomes `/git:commit`.

## Best Practices

1. **Clear descriptions**: Write helpful descriptions for `/help` output
2. **Argument hints**: Provide `argument-hint` for discoverability
3. **Use project memory**: Reference `@CLAUDE.md` for project-specific context
4. **Keep focused**: Each command should have a single, clear purpose
5. **Test thoroughly**: Verify arguments, file references, and bash commands work
6. **Namespace logically**: Group related commands in subdirectories
7. **Version control**: Commit project commands to share with team
8. **Character budget**: All command descriptions combined are limited to approximately 2% of the context window (fallback: 16,000 characters total, not per-command); break complex workflows into multiple commands or use a skill instead

## Command Template

@templates/command-template.md - Complete command template with all options

## Common Use Cases

See @reference/common-use-cases.md for patterns:
- Code review workflows
- Deployment workflows
- Code generation
- Analysis tasks
- Refactoring tasks

## Troubleshooting

See @reference/troubleshooting.md for solutions to:
- Command not found
- Arguments not expanding
- File references not working
- Bash commands not executing

## Version History

### v1.3.0 (2026-03-01)
- Corrected Environment Variables section: removed CLAUDE_PROJECT_DIR (hook-only) and CLAUDE_CONFIG_DIR (does not exist)
- Added bug warning for CLAUDE_PLUGIN_ROOT in command markdown (GitHub issue #9354 — works in JSON configs only)
- Removed undocumented `bash: true` frontmatter field; added disable-model-invocation and user-invocable
- Fixed character limit: all descriptions combined ~2% context window / 16,000 char fallback (not 15,000 per-command)

### v1.2.0 (2026-02-28)
- Added Environment Variables section documenting CLAUDE_PLUGIN_ROOT, CLAUDE_PROJECT_DIR, CLAUDE_CONFIG_DIR, and CLAUDE_SESSION_ID
- Included usage examples for bash lines and plugin-relative path resolution
- Cross-referenced creating-plugins skill for full env var reference

### v1.1.0 (2026-02-28)
- Added Command Anatomy, Frontmatter Fields, Argument Handling, File References, and Bash Execution sections
- Fixed corrupted code fence at lines 27-30
- Added legacy note directing new development toward skills
- Updated frontmatter version and last_updated

### v1.0.0 (2025-11-18)
- Created from slash-commands-guide.md migration
- Separated from using-commands skill
- Focus on command authoring and creation
- Implemented progressive disclosure architecture
