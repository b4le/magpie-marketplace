# YAML Frontmatter Best Practices

## Overview

The YAML frontmatter is the metadata that Claude Code loads at startup to understand your skill's purpose and capabilities.

## Recommended Fields

### description

**Strongly recommended** — Claude uses this to decide when to load the skill. If omitted, Claude falls back to the first paragraph of the markdown body, which may not provide accurate trigger context.
**Format**: Third person, includes trigger phrases

**Structure**:
1. What the skill does (1-2 sentences)
2. When to use it (trigger phrases)
3. Specific use cases or keywords

**Good example**:
```yaml
description: Creates REST API endpoints with validation, error handling, and OpenAPI documentation. Use when user asks to create an API route, add an endpoint, implement a REST service, or scaffold API handlers.
```

**Bad examples**:
```yaml
description: API helper                                    # Too vague
description: I help you create APIs                        # First person
description: Creates APIs                                  # Missing triggers
description: This skill is used for various API tasks      # Unclear
```

**Character count check**:
```bash
# Count characters in description
echo "Your description here" | wc -c
```

## Optional Fields

### name

**Format**: `skill-name`
**Character limit**: 64 characters
**Rules**:
- Lowercase letters, numbers, and hyphens only
- If omitted, Claude Code uses the directory name

**Examples**:
```yaml
name: explain-code            # ✓ Correct
name: analyzing-logs          # ✓ Correct
name: log-analyzer            # ✓ Correct
name: api-v2                  # ✓ Correct (numbers allowed)

name: analyze_logs            # ❌ Wrong (underscore)
name: AnalyzingLogs           # ❌ Wrong (uppercase)
name: analyzing logs          # ❌ Wrong (space)
```

**Note**: There is no requirement to use gerund (verb + -ing) form. Any descriptive name using lowercase letters, numbers, and hyphens is valid.

### allowed-tools

**Purpose**: Restrict which tools the skill can use
**Format**: YAML array of tool names

**Common tools**:
- Read
- Write
- Edit
- Bash
- Grep
- Glob
- WebFetch
- WebSearch

**Example**:
```yaml
allowed-tools:
  - Read
  - Grep
  - Glob
```

**When to use**:
- Analysis skills (read-only): `[Read, Grep, Glob]`
- Code generation (no analysis): `[Write, Edit, Read]`
- Documentation (read-only): `[Read, Grep, Glob]`

**When not to use**:
- Skills that need full tool access
- Skills where tool usage varies by context

### argument-hint

**Purpose**: Hint shown in autocomplete to indicate expected arguments
**Format**: A short usage string describing expected arguments

**Example**:
```yaml
argument-hint: "[issue-number]"
argument-hint: "[filename] [format]"
```

### disable-model-invocation

**Purpose**: Prevent Claude from automatically loading the skill. Use for workflows you want to trigger manually with `/skill-name`.
**Format**: Boolean (`true` or `false`)
**Default**: `false`

**Example**:
```yaml
disable-model-invocation: true
```

Use this for deployment scripts, commit workflows, or any action you always want to trigger explicitly rather than having Claude decide.

### user-invocable

**Purpose**: Controls whether the skill appears in the slash-command picker for manual invocation.
**Format**: Boolean (`true` or `false`)
**Default**: `true`

**Example**:
```yaml
user-invocable: false
```

Use `false` for background reference skills that Claude loads automatically but that users should not invoke directly.

### model

**Purpose**: Specify which model to use when this skill is invoked. Useful for directing lightweight analysis to faster/cheaper models and complex reasoning to more capable ones.
**Format**: Model shorthand string
**Values**: `haiku`, `sonnet`, `opus` (or full model IDs)

**Example**:
```yaml
model: opus
```

Use `haiku` for quick read-only analysis, `sonnet` for general tasks, `opus` for deep reasoning or architecture decisions.

### context

**Purpose**: Set to `fork` to run the skill in a forked subagent context, isolating it from the main conversation.
**Format**: String (only accepted value is `fork`)

**Example**:
```yaml
context: fork
```

Use this when the skill should operate independently and return a summary rather than continuing in the main thread.

### agent

**Purpose**: Name of the agent configuration to delegate skill execution to.
**Format**: Agent name string

**Example**:
```yaml
agent: cloud-architect
```

Useful when you want a domain-specific agent persona (e.g. `security-auditor`, `cloud-architect`) to handle skill invocation.

### hooks

**Purpose**: Define lifecycle hook configurations that run shell commands or inject prompts at specific events during skill execution.
**Format**: Object with event keys (`PreToolUse`, `PostToolUse`, `Stop`). Each event is an array of matcher/handler entries.

**Example**:
```yaml
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "echo 'About to run Bash'"
          timeout: 5
  PostToolUse:
    - matcher: "*"
      hooks:
        - type: command
          command: "echo 'Tool finished'"
  Stop:
    - matcher: "*"
      hooks:
        - type: command
          command: "echo 'Skill complete'"
```

**Hook handler properties**:
- `type`: `command`, `http`, `prompt`, or `agent`
- `command`: Shell command to execute (when `type: command`)
- `prompt`: Text for LLM evaluation (when `type: prompt` or `type: agent`)
- `url`: HTTP endpoint to POST to (when `type: http`)
- `timeout`: Maximum execution time in seconds (1-600). Defaults: command/http=600s, prompt=30s, agent=60s

Use hooks for logging, validation, or post-processing that should happen automatically around tool usage.

### Custom Fields

You can add custom fields for your own tracking:

```yaml
---
name: my-skill
description: My skill description
version: 1.0.0
author: Team Name
last-updated: 2025-01-15
tags:
  - react
  - typescript
  - testing
---
```

**Note**: Custom fields are ignored by Claude Code but useful for documentation.

## YAML Syntax Rules

### Indentation

Use 2 spaces (not tabs):

```yaml
# Correct
---
name: my-skill
description: My description
allowed-tools:
  - Read
  - Write
---

# Wrong (tabs)
---
name: my-skill
description: My description
allowed-tools:
	- Read    # Tab instead of spaces
	- Write
---
```

### Quotes

Use quotes for descriptions with special characters:

```yaml
# No quotes needed
description: Creates React components with TypeScript

# Quotes needed (colon in text)
description: "Creates components: functional and class-based"

# Quotes needed (starts with special char)
description: "@mentions support for component documentation"
```

### Multi-line Descriptions

**Warning**: A raw multi-line description (text that wraps onto a new line without a YAML block scalar) will break skill discovery. Claude reads the description as a single string; an unquoted line break produces a YAML parse error or silently truncates the value, causing the skill to be skipped at load time.

Always keep descriptions on a single line, or use a YAML block scalar if you need more space:

Use `>` (folded scalar) to join lines with a space:

```yaml
description: >
  Creates REST API endpoints with validation, error handling,
  and OpenAPI documentation. Use when user asks to create
  an API route, add an endpoint, or implement a REST service.
```

Use `|` (literal scalar) to preserve explicit line breaks:

```yaml
description: |
  Creates REST API endpoints with validation and error handling.

  Use when user asks to create an API route or implement a REST service.
```

**Do not** write a bare multi-line value like this — it will break parsing:

```yaml
# BROKEN — missing block scalar indicator
description: Creates REST API endpoints with validation, error handling,
  and OpenAPI documentation.
```

**Recommendation**: Prefer a single line for descriptions under 400 characters. Only reach for `>` or `|` when the description genuinely cannot fit on one line.

### Arrays

Two valid formats:

**Flow style** (inline):
```yaml
allowed-tools: [Read, Write, Edit]
```

**Block style** (recommended):
```yaml
allowed-tools:
  - Read
  - Write
  - Edit
```

### Comments

Use `#` for comments:

```yaml
---
name: my-skill
# This description was optimized for discoverability
description: Creates components with TypeScript
# Tools restricted to read-only operations
allowed-tools:
  - Read
  - Grep
  - Glob
---
```

## Common YAML Errors

### Missing Closing Quotes

**Error**:
```yaml
description: "Creates components with TypeScript
```

**Fix**:
```yaml
description: "Creates components with TypeScript"
```

### Incorrect Indentation

**Error**:
```yaml
allowed-tools:
- Read
- Write
```

**Fix**:
```yaml
allowed-tools:
  - Read
  - Write
```

### Missing description

The `description` field is strongly recommended. Without it, Claude uses the first paragraph of the skill body, which may not accurately describe when to use the skill.

**Suboptimal** (no description — Claude falls back to first body paragraph):
```yaml
---
name: my-skill
---
```

**Recommended**:
```yaml
---
name: my-skill
description: Clear description of what the skill does and when to use it
---
```

### Special Characters Not Escaped

**Error**:
```yaml
description: Creates components: functional & class-based
```

**Fix**:
```yaml
description: "Creates components: functional & class-based"
```

### Wrong Tool Names

**Error**:
```yaml
allowed-tools:
  - read        # Wrong (lowercase)
  - FileRead    # Wrong (not a tool name)
  - grep        # Wrong (lowercase)
```

**Fix**:
```yaml
allowed-tools:
  - Read        # Correct
  - Grep        # Correct
  - Glob        # Correct
```

## Validation Tools

### yamllint

Install and use yamllint:

```bash
# Install
pip install yamllint

# Basic validation
yamllint SKILL.md

# Custom rules for skills
cat > .yamllint << 'EOF'
extends: default
rules:
  line-length:
    max: 200
  document-start: disable
  trailing-spaces: enable
EOF

yamllint -c .yamllint SKILL.md
```

### Online Validators

- https://www.yamllint.com/
- https://codebeautify.org/yaml-validator

Copy your frontmatter and validate.

### Manual Validation Checklist

- [ ] YAML delimiters (`---`) present at start and end
- [ ] `name` field, if present, uses only lowercase letters, numbers, and hyphens (max 64 chars)
- [ ] `description` field present and clear (no hard character limit, but keep it focused)
- [ ] Indentation uses 2 spaces, not tabs
- [ ] Arrays use proper format
- [ ] Special characters are quoted
- [ ] No trailing spaces
- [ ] Tool names are capitalized correctly (if using `allowed-tools`)

## Dynamic Context Injection

Skills can inject live, runtime output into their content by prefixing a line with `!`. Claude Code executes the shell command when the skill is loaded and replaces the line with the command's stdout.

### Syntax

```
!<shell-command>
```

The `!` must appear at the start of a line in the skill body (not in YAML frontmatter). The command runs in the project root directory at load time — before Claude sees the skill content.

### Example: Inject Recent Git History

```markdown
---
name: reviewing-changes
description: Reviews recent commits and open diffs. Use when summarising what has changed or preparing a changelog entry.
allowed-tools:
  - Read
  - Bash
---

Here is the current state of the repository:

!git log --oneline -10
!git status --short

Review the changes above and prepare a concise summary.
```

When this skill loads, `git log --oneline -10` and `git status --short` run immediately. Their output is embedded in the skill context that Claude receives.

### Contrast with `@path` File Imports

| Feature | `@path` imports | `!command` injection |
|---------|-----------------|----------------------|
| Resolved | At parse time (static) | At runtime when skill loads |
| Content | File contents | Command stdout |
| Changes | Reflects file on disk | Reflects live system state |
| Use for | Templates, conventions, reference docs | Git state, env info, dynamic config |

Use `@path` when the content is stable (style guides, templates, schemas). Use `!command` when the content must reflect the current state of the repository or environment.

### Security Considerations

Dynamic injection executes arbitrary shell commands with the same permissions as the Claude Code process. Before using `!command` in a skill:

- **Avoid user-controlled input**: Do not construct `!command` lines that incorporate `$ARGUMENTS` or other user-supplied values without sanitisation. An attacker who controls a skill argument could inject shell metacharacters.
- **Prefer read-only commands**: Commands like `git log`, `git status`, and `cat` are low risk. Avoid commands with side effects (network calls, file writes, package installs).
- **Treat output as untrusted**: The injected output becomes part of Claude's context. If a command returns attacker-controlled text (e.g., contents of a file downloaded from the internet), that text could influence Claude's behaviour.
- **Keep commands deterministic**: Avoid commands that are slow, non-deterministic, or that may fail on some machines. A failing `!command` line surfaces as an error and may prevent the skill from loading.

### Timeout Behaviour

Each `!command` line has an implicit execution timeout enforced by Claude Code. Commands that run longer than the timeout are terminated and their output is replaced with a timeout error. Design dynamic context commands to complete quickly — typically under a few seconds. If a command may be slow, prefer fetching the data in the skill body using the `Bash` tool instead, so Claude can handle the latency gracefully.

## Examples by Skill Type

### Code Generation Skill

```yaml
---
name: generating-react-components
description: Creates React functional components with TypeScript, hooks, and accessibility features. Use when user asks to create a new component, generate a React file, or scaffold UI elements.
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
---
```

### Analysis Skill

```yaml
---
name: analyzing-performance
description: Analyzes code for performance issues including N+1 queries, missing memoization, and bundle size problems. Use when optimizing performance or user requests code analysis.
allowed-tools:
  - Read
  - Grep
  - Glob
---
```

### Documentation Skill

```yaml
---
name: documenting-apis
description: Generates OpenAPI 3.0 documentation for REST endpoints with schemas, examples, and authentication details. Use when documenting APIs or creating Swagger specs.
allowed-tools:
  - Read
  - Grep
  - Glob
---
```

### Refactoring Skill

```yaml
---
name: migrating-to-typescript
description: Migrates JavaScript files to TypeScript with proper type annotations, interfaces, and generics. Use when converting JS to TS or adding types to legacy code.
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
---
```

### Testing Skill

```yaml
---
name: generating-unit-tests
description: Creates Jest unit tests with mocks, assertions, and coverage for functions and React components. Use when adding test coverage or implementing TDD workflows.
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
---
```

## Field-Specific Guidelines

### Name Guidelines

**Character budgeting**:
- Total limit: 64 characters
- Recommended: 15-30 characters
- Hyphens count toward limit

**Naming rules** (official):
- Lowercase letters, numbers, and hyphens only
- If omitted, Claude Code uses the directory name as the skill name

**Common patterns** (gerund form is one valid option, not a requirement):
- `{verb-ing}-{noun}`: generating-components, analyzing-logs
- `{noun}-{noun}`: api-conventions, code-review
- `{adjective}-{noun}`: react-patterns, typescript-migrations

**Avoid**:
- Underscores (use hyphens instead)
- Uppercase letters
- Spaces
- Abbreviations (unless very common: API, UI, DB)
- Version numbers (use version history in content)
- Organization names (goes in description)

### Description Guidelines

**Template structure**:
```
{Action verb} {what} with {key features}. Use when {trigger 1}, {trigger 2}, or {trigger 3}.
```

**Example**:
```
Creates database migrations with up/down scripts and timestamps. Use when modifying schema, adding tables, or creating migration files.
```

**Keywords to include**:
- Domain terms (React, TypeScript, API, database)
- Action verbs (create, generate, analyze, document)
- Output types (components, tests, documentation, migrations)
- Trigger contexts (when user asks, when creating, when documenting)

### allowed-tools Guidelines

**Read-only skills**:
```yaml
allowed-tools:
  - Read
  - Grep
  - Glob
```

**Code generation skills**:
```yaml
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
```

**Skills needing execution**:
```yaml
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
```

**Web research skills**:
```yaml
allowed-tools:
  - Read
  - WebFetch
  - WebSearch
  - Grep
```

## Version History

### v1.3.0 (2026-03-01)
- Added documentation for `model`, `context`, `agent`, and `hooks` frontmatter fields (W1)
- Removed `minLength: 20` constraint on `description`; official docs specify no minimum length

### v1.2.0 (2026-03-01)
- Corrected `name` field: it is optional (directory name used if omitted), not required
- Removed fabricated gerund naming requirement; official rule is lowercase letters, numbers, and hyphens only (max 64 chars)
- Removed fabricated 1024-character limit for `description`; no hard per-field limit in official docs
- Added missing frontmatter fields: `argument-hint`, `disable-model-invocation`, `user-invocable`
- Updated Manual Validation Checklist to reflect correct field rules
- Updated Name Guidelines to remove gerund-only claim

### v1.1.0 (2026-02-28)
- Added warning about multi-line description parsing and skill discovery failure
- Added Dynamic Context Injection section with `!command` syntax, security guidance, and comparison with `@path` imports

### v1.0.0 (2025-11-17)
- Initial creation from skills-authoring-guide.md
- Added YAML syntax rules and examples
- Included validation tools and checklists
- Documented field-specific guidelines
