---
name: authoring-output-styles
description: Guide for creating Claude Code output styles — markdown files that modify how Claude responds. Use when creating, activating, or switching output styles stored in ~/.claude/output-styles/ or .claude/output-styles/.
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
version: 2.0.0
created: 2025-12-06
last_updated: 2026-03-01
tags:
  - output-styles
  - formatting
---

# Authoring Output Styles

## What Output Styles Are

Output styles are markdown files that Claude Code adds to the system prompt when activated. They let you change how Claude responds — adapting tone, structure, and focus for different audiences or use cases. They are distinct from skills, commands, and CLAUDE.md configuration.

An output style file contains:
- Optional YAML frontmatter (3 recognized fields)
- A free-form markdown body describing how Claude should respond

When an output style is active, its full content is injected into the system prompt alongside Claude's default instructions.

## When to Use This Skill

Use this skill when:
- Creating a new output style for a specific audience or document type
- Understanding which frontmatter fields are valid for output styles
- Learning storage locations and activation commands

### Do NOT Use This Skill When:
- Creating skills themselves — use `authoring-skills` instead
- Writing slash commands — use `creating-commands` instead
- Configuring Claude's general behaviour — edit CLAUDE.md directly

## Frontmatter Fields

Output style files support exactly three frontmatter fields:

| Field | Purpose | Default |
|-------|---------|---------|
| `name` | Display name shown in the `/output-style` UI | Inherits from filename |
| `description` | Description shown in the `/output-style` UI only | None |
| `keep-coding-instructions` | Whether to retain the coding-focused parts of Claude's system prompt | `false` |

The `keep-coding-instructions` field is the most functionally significant. Set it to `true` when the output style is used alongside coding tasks — for example, a style that changes response tone but still needs Claude to reason about code. Set it to `false` (the default) for styles used in purely non-technical contexts such as executive briefs or creative writing.

Custom fields (like `category`, `audience`, `tone`, `version`) are accepted without error but have no effect on behaviour. They are useful as documentation for human readers.

## Storage Locations

| Scope | Directory | Who it affects |
|-------|-----------|---------------|
| Personal | `~/.claude/output-styles/` | Your Claude sessions everywhere |
| Project | `.claude/output-styles/` | Anyone working in that project |

Files at either location are automatically discovered. Use the project directory when sharing a style with your team via version control.

## File Format

An output style is a `.md` file. The name of the file (without extension) becomes the style's identifier unless overridden by the `name` frontmatter field.

**Minimal example** (`~/.claude/output-styles/concise.md`):

```markdown
Respond concisely. Use bullet points for lists. Avoid preamble and filler phrases.
```

**Typical example** (`~/.claude/output-styles/exec-brief.md`):

```markdown
---
name: exec-brief
description: Concise summaries for executive audiences
keep-coding-instructions: false
---

# Executive Brief Style

- Keep responses under 150 words
- Lead with the bottom line, not the background
- Translate technical terms into business impact
- State a clear recommendation or ask

## Structure

1. Bottom line (1 sentence)
2. Context (2-3 sentences)
3. Key points (3-5 bullets, quantified)
4. Recommendation (1 sentence)
```

**Example with coding instructions retained** (`~/.claude/output-styles/formal-eng.md`):

```markdown
---
name: formal-eng
description: Formal engineering tone for internal RFC and ADR writing
keep-coding-instructions: true
---

Write in a formal, precise engineering register. Use RFC 2119 keywords (MUST, SHOULD, MAY)
for normative requirements. Avoid colloquialisms. Prefer structured headings and tables
over long prose paragraphs.
```

## Activating and Switching Styles

Output styles are activated via the built-in `/output-style` command in Claude Code.

```
/output-style exec-brief
```

To see available styles:

```
/output-style
```

To clear the active style and return to default:

```
/output-style none
```

Only one output style can be active at a time. Switching styles replaces the previous one.

## What the Body Can Contain

The markdown body is free-form. It can include:
- Tone and voice instructions ("Be direct. Avoid hedging.")
- Structural requirements ("Always include a TL;DR")
- Audience descriptions ("Assume no technical background")
- Formatting rules ("Use tables for comparisons")
- Before/after examples to clarify expectations
- Constraints ("Responses must not exceed 200 words")

There is no schema, no variable substitution, and no automated validation. The text is appended to the system prompt as-is and Claude uses it as context for how to respond.

## Practical Patterns

### Non-technical audience style

```markdown
---
name: product-comms
description: Product communication — clear, benefit-focused writing for non-technical stakeholders
keep-coding-instructions: false
---

Write for a non-technical audience. Focus on outcomes, not implementation.
Avoid acronyms without explanation. Use plain English. Keep paragraphs short
(3 sentences max). Lead with the user benefit before explaining how something works.
```

### Technical depth style

```markdown
---
name: technical-deep-dive
description: Engineering-depth analysis with trade-offs and implementation detail
keep-coding-instructions: true
---

Provide full technical depth. Include code examples, quantified trade-offs,
and file/line references where relevant. Present at least one alternative approach.
Use tables for comparisons. Cite specific files, functions, or docs.
```

### Presentation prep style

```markdown
---
name: talking-points
description: Structured format for meeting and presentation preparation
keep-coding-instructions: false
---

Format output as talking points:
1. Opening hook (1 sentence)
2. Key messages (3-5 bullets, each with headline + evidence)
3. Anticipated questions (2-3 with concise answers)
4. Call to action (1 sentence)

Keep each point punchy. Prioritise what the audience will remember tomorrow.
```

## Supporting Documentation

See the real output style files installed for this user at `~/.claude/output-styles/` for working examples of the `exec-brief`, `technical-deep-dive`, `talking-points`, and other styles.

## Version History

### v2.0.0 (2026-03-01)
- Complete rewrite to teach the actual Claude Code output styles feature
- Documents the 3 official frontmatter fields: name, description, keep-coding-instructions
- Documents storage locations and /output-style activation command
- Removes fabricated schema references (style-definition-spec.md was deleted)
- Removes misleading framing that conflated generic prompt formatting with the output styles feature

### v1.0.0 (2025-12-06)
- Initial skill creation (subsequently found to misrepresent the feature)
