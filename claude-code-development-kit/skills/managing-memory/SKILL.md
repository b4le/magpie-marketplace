---
name: managing-memory
description: "Complete guide to using Claude Code's memory system effectively. Use when creating CLAUDE.md files, organizing project memory, understanding memory hierarchy, implementing @path imports, or troubleshooting memory issues. Covers structure, best practices, and maintenance for both project and user-level memory."
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
version: 1.0.0
created: 2025-11-20
last_updated: 2025-11-26
tags:
  - memory
  - claude-md
  - configuration
---

# Managing Memory

## Overview

Claude Code uses a hierarchical memory system to provide persistent context across sessions. Memory files are automatically loaded and inform Claude's behavior, enabling you to define project conventions, coding standards, workflows, and preferences that persist across all interactions.

### Primary Capabilities

- Understanding memory hierarchy and file locations
- Creating and editing CLAUDE.md files for projects and users
- Structuring memory content for maximum effectiveness
- Using @path imports to organize large memory files
- Implementing best practices for different project types
- Troubleshooting common memory issues
- Maintaining memory files over time

### When to Use This Skill

Use this skill when:
- Creating a new CLAUDE.md file for a project or user
- Organizing existing memory content
- Understanding which memory file to edit (project vs user)
- Implementing @path imports to reduce file size
- Memory instructions aren't being followed
- Setting up team-wide project conventions
- Migrating from old memory patterns to new best practices

### Do NOT Use This Skill When:
- ❌ Just editing memory content → Use Edit tool directly on CLAUDE.md
- ❌ Opening memory file → Use `/memory` command instead
- ❌ Memory is working fine and no restructuring needed → Don't invoke unnecessarily

## Memory System Overview

Memory is loaded in this priority order (highest to lowest):

1. **Managed Policy** - Organization-wide settings (system-managed, read-only)
2. **Project Memory** - Team-shared project context (`.claude/CLAUDE.md` or `./CLAUDE.md`)
3. **User Memory** - Personal preferences (`~/.claude/CLAUDE.md`)
4. **Local Project** - Personal project-specific preferences (`CLAUDE.local.md`, not committed to git)

**Important:** More specific locations take precedence over broader ones. If two rules conflict, Claude may pick one arbitrarily — review your files periodically to remove contradictions.

**Tree walk behavior:** Claude walks up the directory tree loading ALL CLAUDE.md files it finds along the way (not stopping at the first one). CLAUDE.md files in subdirectories load on-demand when Claude reads files in those directories.

## Quick Start

### Creating Project Memory

1. **Initialize memory file:**
   ```bash
   mkdir -p .claude
   touch .claude/CLAUDE.md
   ```

2. **Add basic structure:**
   ```markdown
   # Project Name

   Brief description of the project.

   ## Technology Stack
   - Frontend: [Your stack]
   - Backend: [Your stack]
   - Database: [Your database]

   ## Coding Conventions
   [Your conventions]

   ## Common Commands
   \`\`\`bash
   npm run dev    # Start development
   npm test       # Run tests
   \`\`\`
   ```

3. **Commit to version control:**
   ```bash
   git add .claude/CLAUDE.md
   git commit -m "docs: add project memory"
   ```

### Creating User Memory

1. **Create file:**
   ```bash
   mkdir -p ~/.claude
   touch ~/.claude/CLAUDE.md
   ```

2. **Add personal preferences:**
   ```markdown
   # My Preferences

   ## Coding Style
   - Prefer functional components over class components
   - Use TypeScript strict mode
   - Explicit return types for exported functions

   ## Common Workflows
   [Your personal workflows]
   ```

## Memory File Locations

### Project Memory (Team-Shared)

**Locations** (searched in order):
- `./CLAUDE.md` (project root)
- `./.claude/CLAUDE.md` (recommended)

**Purpose:** Team-shared project-specific context

**Contains:**
- Project architecture and patterns
- Coding conventions specific to this codebase
- Technology stack information
- Common commands and workflows
- File structure and organization

**Sharing:** Committed to version control, shared with entire team

### User Memory (Personal)

**Location:** `~/.claude/CLAUDE.md`

**Purpose:** Personal preferences across all projects

**Contains:**
- Personal coding preferences
- Frequently used patterns you prefer
- Custom shortcuts and workflows
- Personal development preferences

**Sharing:** Not shared (personal configuration)

### Local Project Memory (Personal, Not Committed)

**Location:** `./CLAUDE.local.md` (project root)

**Purpose:** Personal project-specific preferences that should NOT be in version control

**Contains:**
- Sandbox URLs and local server addresses
- Your preferred test data or local config overrides
- Machine-specific settings

**Sharing:** Automatically added to `.gitignore` — personal only

**Worktree note:** `CLAUDE.local.md` only exists in one worktree. If you work across multiple git worktrees and need personal instructions available everywhere, use a home-directory import in each worktree's CLAUDE.local.md: `@~/.claude/my-project-instructions.md`

### User-Level Rules

**Location:** `~/.claude/rules/`

Individual `.md` files in this directory apply to every project on your machine. Use them for personal preferences that are not project-specific. User-level rules are loaded before project rules, giving project rules higher priority.

### Enterprise Policy (Organization-Wide)

**Purpose:** Organization-wide policies and standards

**Managed by:** System administrators (deployed via MDM, Group Policy, Ansible, etc.)

**Locations** (OS-dependent):
- **macOS:** `/Library/Application Support/ClaudeCode/CLAUDE.md`
- **Linux/WSL:** `/etc/claude-code/CLAUDE.md`
- **Windows:** `C:\Program Files\ClaudeCode\CLAUDE.md`

**Contains:**
- Company coding standards
- Required security practices
- Compliance requirements
- Approved tools and libraries

**User control:** Read-only. Cannot be excluded by individual settings.

See @reference/memory-locations.md for detailed specifications.

## Organizing Rules with .claude/rules/

For larger projects, place markdown files in `.claude/rules/` to keep instructions modular. Rules can be scoped to specific file paths, so they only load when Claude works with matching files.

**Directory structure:**
```
your-project/
├── .claude/
│   ├── CLAUDE.md          # Main project instructions
│   └── rules/
│       ├── testing.md     # Testing conventions
│       ├── api-design.md  # API rules
│       └── security.md    # Security requirements
```

**Path-specific rules** use YAML frontmatter to scope rules to file patterns:

```markdown
---
paths:
  - "src/api/**/*.ts"
---
# API Development Rules
- All API endpoints must include input validation
- Use the standard error response format
```

Rules without a `paths` field load at launch unconditionally (same priority as `.claude/CLAUDE.md`). Path-scoped rules trigger when Claude reads matching files, not on every tool use.

**Sharing rules across projects** — `.claude/rules/` supports symlinks:
```bash
ln -s ~/shared-claude-rules .claude/rules/shared
```

## File Imports with @path

Import other files into memory using `@path` syntax:

```markdown
# Project Memory

## API Documentation
@docs/api-reference.md

## Code Style Guide
@docs/style-guide.md

## Architecture Decision Records
@docs/adr/
```

**Features:**
- Supports recursive imports (max 5 hops)
- Relative paths from memory file location
- Can import entire directories
- Imported content becomes part of context

**Important:** Imports in code blocks and inline code spans are ignored to prevent collision with actual code examples.

**Example:**
```markdown
# Memory File

This import will work:
@docs/api-guide.md

But this won't be processed as an import:
\`\`\`python
# This @docs/example.md is just a comment
file = "@data/config.json"  # Not an import
\`\`\`

And this inline code won't import: \`@path/to/file\`
```

## What to Include in Memory

### Project-Level Information

**Do include:**
- Architecture patterns and principles
- Coding conventions and style guides
- Technology stack and versions
- Common commands and workflows
- File structure and organization
- Testing approaches
- Deployment procedures
- Team agreements and decisions

**Don't include:**
- Specific implementation details (use code comments instead)
- Temporary notes (use separate files)
- Secrets or credentials (use environment variables)
- Large reference documents (import with @path instead)

## Memory Best Practices

### 1. Be Specific and Actionable

**Good:**
```markdown
## Error Handling

All API calls must:
- Use try-catch blocks
- Log errors with context
- Return structured error responses: { success: false, error: string }
```

**Bad:**
```markdown
## Error Handling

Handle errors properly.
```

### 2. Use Structured Formatting

Use markdown features for clarity:

```markdown
## Commands

| Command | Purpose |
|---------|---------|
| `npm run dev` | Start development server |
| `npm test` | Run test suite |
| `npm run build` | Create production build |
```

### 3. Provide Examples

```markdown
## API Request Pattern

Use this pattern for all API requests:

\`\`\`typescript
async function fetchData<T>(endpoint: string): Promise<T> {
  try {
    const response = await fetch(\`/api/\${endpoint}\`);
    if (!response.ok) {
      throw new Error(\`HTTP \${response.status}\`);
    }
    return await response.json();
  } catch (error) {
    logger.error('API request failed', { endpoint, error });
    throw error;
  }
}
\`\`\`
```

### 4. Keep Updated

Document version history:

```markdown
## Version History

### 2025-01-15
- Updated to React 18
- Migrated from Jest to Vitest
- New component patterns using Server Components
```

### 5. Use Clear Hierarchy

```markdown
# Project Name

## Architecture
### Frontend
### Backend
### Database

## Conventions
### TypeScript
### React
### Testing
```

### 6. Include Context, Not Just Rules

**Good:**
```markdown
## State Management

We use Zustand instead of Redux because:
- Simpler API with less boilerplate
- Better TypeScript support
- Smaller bundle size

Store pattern:
\`\`\`typescript
export const useStore = create<StoreState>((set) => ({
  // State and actions
}));
\`\`\`
```

**Bad:**
```markdown
## State Management

Use Zustand.
```

## Recommended Memory Structure

See @templates/memory-structure-template.md for a complete template you can copy and customize for your project.

## Project Type Examples

Different project types benefit from different memory patterns:

- **Web Applications** - Focus on frontend/backend patterns, API conventions, styling approaches
- **API/Backend Services** - Emphasize endpoint patterns, data validation, error handling
- **Libraries/Packages** - Document export patterns, versioning, API design
- **CLI Tools** - Command patterns, argument handling, output formatting

See @examples/project-types.md for specific examples and patterns for each project type.

## Common Memory Commands

### Editing Memory Files

Use the `/memory` command to open and edit memory files:

```
/memory
```

This opens your editor with the appropriate CLAUDE.md file.

### Initializing Project Memory

Use `/init` to bootstrap project memory:

```
/init
```

Creates `.claude/CLAUDE.md` with basic structure if it doesn't exist.

## Troubleshooting

### Memory Not Being Loaded

**Problem:** Changes to memory file not reflected

**Quick Solutions:**
1. Restart Claude Code
2. Check file location (use exact paths listed above)
3. Verify file is named `CLAUDE.md` (case-sensitive)
4. Check file permissions (must be readable)
5. Look for syntax errors in markdown

### Memory Not Specific Enough

**Problem:** Claude doesn't follow memory instructions

**Quick Solutions:**
1. Be more explicit and specific
2. Provide concrete examples
3. Use clear formatting (headers, lists, code blocks)
4. State WHY, not just WHAT
5. Include step-by-step instructions

See @reference/troubleshooting.md for comprehensive troubleshooting guide.

## Advanced Topics

For advanced memory patterns and techniques:

- **Conditional Memory** - Environment-specific patterns
- **Role-Based Memory** - Team workflows by role
- **Task-Specific Memory** - Common task templates
- **Referencing Multiple Files** - Complex @path structures

See @reference/advanced-patterns.md for detailed advanced patterns.

## Memory Maintenance

Regular maintenance keeps memory effective:

**Monthly:**
- Remove outdated information
- Update dependencies and versions
- Add new patterns that emerged
- Remove deprecated patterns

**Quarterly:**
- Major review of structure
- Update architecture documentation
- Align with team changes
- Import/export optimizations

See @reference/maintenance-guide.md for detailed maintenance procedures.
