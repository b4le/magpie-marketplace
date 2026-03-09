# Writing Effective Skill Descriptions

## Overview

The skill description is the most critical element for skill discoverability. Claude reads descriptions at startup to decide when to invoke skills.

## Character Limits

- **Recommended**: 200-400 characters
- There is no hard maximum or minimum character limit for descriptions

## Format Requirements

### Use Third Person

**Correct**:
- "Creates React components with TypeScript"
- "Analyzes code for performance issues"
- "Generates API documentation"

**Incorrect**:
- "I create React components" ❌
- "I'll help analyze code" ❌
- "Let me generate API docs" ❌

### Lead with Action

Start with what the skill does, not background information:

**Good**:
```yaml
description: Creates database migration files with up/down migrations and timestamps. Use when schema changes are needed or user asks to create a migration.
```

**Bad**:
```yaml
description: Database migrations are important for schema management. This skill helps with migrations when you need them.
```

### Include Trigger Phrases

Add explicit "when to use" statements:

**Trigger phrase patterns**:
- "Use when..."
- "Invoke when user asks to..."
- "Apply when..."
- "Useful for..."

**Examples**:

```yaml
description: Generates React components with TypeScript, following project conventions. Use when user asks to create a new React component, generate a component, or scaffold component files.
```

```yaml
description: Analyzes API logs for errors, performance issues, and usage patterns. Use when user requests log analysis, error investigation, or API metrics.
```

```yaml
description: Migrates JavaScript files to TypeScript with proper types and interfaces. Apply when converting JS to TS, adding types to untyped code, or modernizing JavaScript projects.
```

### Add Relevant Keywords

Include domain-specific terms that users might mention:

**For a testing skill**:
```yaml
description: Generates unit tests following Jest patterns with mocks, assertions, and coverage tracking. Use when creating tests, adding test coverage, or implementing TDD workflows.
```

Keywords: unit tests, Jest, mocks, assertions, coverage, TDD

**For a documentation skill**:
```yaml
description: Creates OpenAPI/Swagger documentation for REST endpoints with schemas, examples, and response codes. Use when documenting APIs, adding OpenAPI specs, or generating Swagger docs.
```

Keywords: OpenAPI, Swagger, REST, schemas, endpoints, API documentation

### Specify Context

Make it clear in what situations the skill applies:

**Good (specific context)**:
```yaml
description: Optimizes React components by adding memoization, lazy loading, and code splitting. Use when improving performance, reducing bundle size, or addressing rendering issues in React applications.
```

**Bad (vague context)**:
```yaml
description: Helps make React apps faster and better.
```

## Description Templates

### Code Generation Skill

```yaml
description: Generates [WHAT] with [KEY_FEATURES]. Use when user asks to create [TRIGGER_1], [TRIGGER_2], or [TRIGGER_3].
```

Example:
```yaml
description: Generates REST API endpoints with validation, error handling, and OpenAPI docs. Use when user asks to create an API route, add an endpoint, or implement a REST service.
```

### Analysis Skill

```yaml
description: Analyzes [WHAT] for [ISSUES/PATTERNS]. Use when [TRIGGER_CONTEXT] or user requests [SPECIFIC_ANALYSIS].
```

Example:
```yaml
description: Analyzes database queries for N+1 problems, missing indexes, and performance bottlenecks. Use when optimizing database performance or user requests query analysis.
```

### Documentation Skill

```yaml
description: Creates [DOC_TYPE] following [STANDARDS] with [COMPONENTS]. Use when documenting [WHAT] or [TRIGGER_CONTEXT].
```

Example:
```yaml
description: Creates API documentation following OpenAPI 3.0 standards with schemas, examples, and authentication details. Use when documenting REST endpoints or generating Swagger specs.
```

### Refactoring/Migration Skill

```yaml
description: Migrates [FROM] to [TO] with [APPROACH]. Use when converting [TRIGGER_1], modernizing [TRIGGER_2], or [TRIGGER_3].
```

Example:
```yaml
description: Migrates class components to functional components with hooks and modern React patterns. Use when converting legacy React code, adopting hooks, or modernizing component architecture.
```

## Common Mistakes

### Too Vague

❌ "Helps with frontend development"
❌ "Assists with database tasks"
❌ "Useful for testing"

✓ "Generates React components with TypeScript, Tailwind CSS, and accessibility features. Use when creating new UI components."
✓ "Creates database migrations with up/down scripts and rollback support. Use when modifying database schema."
✓ "Generates Jest unit tests with mocks and assertions. Use when adding test coverage to functions or components."

### Missing Triggers

❌ "Creates API endpoints with proper validation and error handling"

✓ "Creates API endpoints with proper validation and error handling. Use when adding REST routes, implementing API services, or scaffolding endpoint handlers."

### First Person

❌ "I help you create React components"
❌ "I'll generate tests for your code"

✓ "Creates React components following project patterns"
✓ "Generates tests with Jest and React Testing Library"

### Too Long

❌ "This skill provides comprehensive support for creating, managing, and maintaining React components across your application architecture. It includes templates for functional components, class components, hooks, context providers, and higher-order components. The skill follows industry best practices including TypeScript integration, prop validation with PropTypes or TypeScript interfaces, comprehensive testing strategies, accessibility guidelines compliance, and performance optimization techniques. It can be used whenever you need to scaffold new components, refactor existing ones, or establish component patterns across your React application."

✓ "Generates React components with TypeScript, hooks, and accessibility features. Use when creating new components, scaffolding UI elements, or establishing component patterns."

### Generic Terms Without Context

❌ "Handles API operations"
❌ "Manages database interactions"

✓ "Creates REST API endpoints with OpenAPI documentation. Use when building API routes or documenting services."
✓ "Generates database migrations with up/down scripts. Use when modifying database schema or adding tables."

## Testing Your Description

### 1. Read It Aloud

Does it clearly explain:
- What the skill does?
- When to use it?
- What triggers it?

### 2. User Perspective Test

Would a user saying any of these phrases trigger your skill?

Example description:
```yaml
description: Generates React components with TypeScript and Tailwind CSS. Use when creating new components, scaffolding UI elements, or adding React files.
```

User phrases that should trigger:
- "Create a new React component called UserProfile"
- "Generate a component for displaying user cards"
- "Add a React component for the navigation bar"
- "Scaffold a new UI component"

### 3. Uniqueness Check

Is your description distinct from other skills?

If you have multiple skills, ensure each has a unique focus:

```yaml
# Good - Distinct skills
---
name: generating-components
description: Generates React components with TypeScript. Use when creating new components.
---

---
name: generating-tests
description: Generates Jest tests for React components. Use when adding test coverage.
---

---
name: documenting-components
description: Creates Storybook stories for React components. Use when documenting component APIs.
---
```

### 4. Keyword Coverage

List the keywords users might use, then verify they're in your description:

For a migration skill:
- Keywords: migrate, convert, TypeScript, JavaScript, types, interfaces
- Description: "Migrates JavaScript files to TypeScript with proper types and interfaces. Use when converting JS to TS or adding types to JavaScript code."
- ✓ All keywords covered

## Description Format and Skill Discovery

### Single-line vs Multi-line Descriptions

A description must parse correctly as a YAML scalar. A raw multi-line value without a block scalar indicator (`>` or `|`) will cause a YAML parse error and silently prevent skill discovery — the skill will not be loaded.

**Safe formats**:

```yaml
# Single line — preferred for descriptions under 400 characters
description: Creates REST API endpoints with validation and error handling. Use when adding routes or implementing services.

# Folded scalar — lines are joined with a space
description: >
  Creates REST API endpoints with validation and error handling.
  Use when adding routes or implementing services.

# Literal scalar — line breaks are preserved
description: |
  Creates REST API endpoints with validation and error handling.
  Use when adding routes or implementing services.
```

**Broken format — do not use**:

```yaml
# BROKEN — no block scalar indicator, YAML parser sees an error
description: Creates REST API endpoints with validation and error handling,
  authentication, and OpenAPI documentation.
```

If a skill is not appearing in `/help` or Claude is not selecting it, check that the description is a valid single-line or block scalar value.

## Skill Activation Optimization

The description determines how often Claude selects your skill. Claude reads all loaded skill descriptions at the start of a session and uses them to decide which skill (if any) applies to each user request. A poorly calibrated description leads to one of two failure modes: under-selection (Claude ignores the skill when it should help) or over-selection (Claude loads the skill for irrelevant requests, consuming context).

### Activation Rate Targets

| Activation rate | Symptom | Cause |
|-----------------|---------|-------|
| ~20% (too low) | Claude rarely uses the skill even when appropriate | Description is too generic or missing trigger phrases |
| ~50% (ideal) | Claude selects the skill in the right situations | Description is well-targeted with specific triggers |
| ~90% (too high) | Claude loads the skill for almost every request | Description is too broad or triggers on common words |

These rates are illustrative. The goal is for Claude to select the skill when the user's intent clearly matches, and skip it when it does not.

### Too Broad — Triggers Too Often

A description that matches everyday language will activate constantly:

```yaml
# Too broad — "help", "code", "files" match almost everything
description: Helps with code and files. Use when working on a project.
```

This skill will load for most requests, even when unrelated. It wastes context and may interfere with other skills.

**Fix**: Add specific domain terms and constrain the trigger phrases:

```yaml
description: Generates database migration files with up/down scripts for PostgreSQL. Use when modifying schema, adding tables, or creating migration files in a Postgres project.
```

### Too Narrow — Triggers Too Rarely

A description with hyper-specific wording will miss legitimate use cases:

```yaml
# Too narrow — only triggers when user says exactly "generate a Postgres migration file"
description: Generates a Postgres migration file. Use when the user asks to generate a Postgres migration file.
```

If the user says "add a new table" or "create a migration", the skill will not activate.

**Fix**: Include synonyms and natural language variants for the trigger context:

```yaml
description: Generates database migration files with up/down scripts for PostgreSQL. Use when modifying schema, adding tables, creating migration files, or when user asks to "add a column" or "rename a table" in a Postgres project.
```

### Optimizing for Claude's Skill Selection

Claude's selection process is semantic, not keyword-matching. It reads the description as a whole and compares it to the user's intent. Practical guidance:

1. **State the output clearly**: Lead with what the skill produces, not background information. Claude correlates the user's goal with the skill's output.
2. **List natural-language triggers**: Include the phrases a user might actually say, not just technical terms. "add a column" activates better than "ALTER TABLE".
3. **Distinguish from similar skills**: If you have two skills covering related territory, make each description explicitly state what the other does not cover. Overlap in descriptions leads to unpredictable selection.
4. **Avoid meta-language**: Phrases like "this skill helps you..." or "use this when you want to..." add words without improving trigger signal. Keep the description factual and action-oriented.
5. **Iterate after observation**: Watch which requests Claude handles with and without the skill. If it misses cases it should cover, add those phrasings to the description. If it over-activates, remove the generic terms that cause it.

### Relationship Between Description Quality and Selection

Claude's skill selection is probabilistic: a better-targeted description does not guarantee correct selection on every request, but it consistently improves the hit rate. The description is the primary signal — the skill name and content body do not influence selection unless the description references them explicitly.

If a skill is not being selected despite a well-written description, verify:
- The skill file is in a location Claude Code scans (see "Where skills live" in the main docs)
- The YAML frontmatter parses without errors (`yamllint SKILL.md`)
- `disable-model-invocation` is not set to `true` (which would require manual invocation)
- No other skill with a higher-priority description is being selected instead

## Skill Naming Conventions

Skill names must use lowercase letters, numbers, and hyphens only (max 64 characters). There is no requirement to use gerund (verb + -ing) form — any descriptive hyphenated name is valid. The gerund pattern (`verb-ing-noun`) is one useful convention, but names like `api-documentation`, `code-review`, or `test-runner` are equally valid.

### Standard Verb Prefixes

| Prefix | Use for |
|--------|---------|
| `authoring-*` | Creating written artifacts — skills, prompts, output styles |
| `creating-*` | Building structural extensions — plugins, commands |
| `using-*` | Learning to operate existing features — tools, commands |
| `understanding-*` | Conceptual knowledge about how something works — hooks, memory |
| `managing-*` | Ongoing operational tasks — memory files, configurations |
| `integrating-*` | Connecting external systems — MCPs, APIs, services |
| `resolving-*` | Diagnosing and fixing problems — issues, errors, conflicts |

### Why the Pattern Matters

**Discoverability**: Claude reads skill names alongside descriptions when selecting skills. A consistent naming scheme gives Claude an additional signal about the skill's purpose before it reads the description body. This benefit applies whether you use the gerund pattern or another descriptive structure.

**User expectation**: Users scanning `/available-skills` can infer what a skill does from the name alone. `authoring-output-styles` is immediately understood; `output-style-helper` is not.

**Namespace clarity**: The verb prefix prevents collisions between skills that cover the same domain from different angles. `creating-commands` (how to build them) and `using-commands` (how to invoke them) cover distinct territory despite sharing the `commands` noun.

### Naming Examples

```
authoring-skills          # Writing SKILL.md files
authoring-agent-prompts   # Writing prompts for agents
creating-plugins          # Building plugin packages
creating-commands         # Building slash commands
using-tools               # Using Claude Code's built-in tools
using-commands            # Using slash commands
understanding-hooks       # How the hook system works
managing-memory           # CLAUDE.md and memory files
integrating-mcps          # Connecting MCP servers
resolving-claude-code-issues  # Fixing common problems
```

When in doubt, choose the verb that matches the user's intent: are they building something (`creating-`, `authoring-`), learning something (`using-`, `understanding-`), operating something ongoing (`managing-`), connecting something external (`integrating-`), or fixing something broken (`resolving-`)?

---

## Version History

### v1.1.0 (2026-02-28)
- Added Description Format and Skill Discovery section with multi-line YAML warning
- Added Skill Activation Optimization section with activation rate targets and calibration guidance

### v1.0.0 (2025-11-17)
- Initial creation from skills-authoring-guide.md
- Added description templates
- Included testing strategies
- Documented common mistakes
