# MEMORY.md File Structure and Format

Reference for the auto memory directory layout, file format, and how Claude organises entries.

## Directory Structure

Each project gets a dedicated memory directory derived from the git repository root:

```
~/.claude/projects/<project>/memory/
├── MEMORY.md          # Required entrypoint — loaded into every session (first 200 lines)
├── patterns.md        # Optional: code patterns and conventions Claude discovered
├── commands.md        # Optional: frequently used commands and flags
└── decisions.md       # Optional: key architectural or tooling decisions
```

The `<project>` segment is the git repository root path, normalised for use as a directory name. All subdirectories and all worktrees within the same repo share one memory directory.

Outside a git repository, the memory directory is based on the working directory path.

## MEMORY.md — The Entrypoint

`MEMORY.md` is the primary file Claude reads and writes. It:

- Is loaded automatically at the start of every session
- Has a **200-line limit** — only the first 200 lines are loaded into context
- Acts as an index when topic files exist in the same directory
- Is editable by you at any time

### Typical format

```markdown
# Project Memory

## Package Manager
- Uses pnpm (not npm or yarn). Run `pnpm install`, `pnpm run dev`.

## Build Commands
- `pnpm run build` — production build
- `pnpm run dev` — start dev server with hot reload
- `pnpm test` — run Vitest suite

## Conventions
- Single quotes for strings in TypeScript
- Named exports only; no default exports
- Barrel files (`index.ts`) at directory level

## Key Decisions
- Chose Postgres over MySQL (2026-02-10) — team already has Postgres expertise
- Using Zod for runtime validation after evaluating Yup and Valibot

## See also
- patterns.md — component and hook patterns
- commands.md — full command list with flags
```

### Entry format guidelines

Claude typically writes entries as:
- **Section headers** (`##`) for categories
- **Bullet points** for individual facts
- **Inline code** (backticks) for commands, file paths, and identifiers
- **Parenthetical dates** for decisions where recency matters

## Topic Files

When the memory directory contains topic files, `MEMORY.md` acts as an index referencing them. Topic files are not loaded automatically — Claude reads them on demand during a session.

Claude creates topic files when `MEMORY.md` approaches the 200-line limit or when a category grows large enough to warrant separation.

### Common topic file patterns

| File | Contents |
|------|----------|
| `patterns.md` | Code patterns, component structures, hook conventions |
| `commands.md` | Full command list with flags and descriptions |
| `decisions.md` | Architecture decisions with rationale and dates |
| `environment.md` | Environment variables, service URLs, local setup notes |

## Relationship to `.claude/projects/` Directory

The `.claude/projects/` directory at `~/.claude/projects/` also stores session transcripts. The memory directory lives alongside these:

```
~/.claude/projects/<project>/
├── memory/            # Auto memory (MEMORY.md and topic files)
│   └── MEMORY.md
└── ...                # Session transcripts and other session data
```

The memory directory is separate from transcript files. Transcripts are not loaded into context; only `MEMORY.md` (and any topic files Claude explicitly reads) are loaded.

## Editing Tips

- Keep `MEMORY.md` under 200 lines to ensure all entries are loaded into context
- Put stable, high-value facts near the top — they are always loaded
- Move large or less-critical sections to topic files and reference them in `MEMORY.md`
- Remove outdated entries promptly; stale memory can mislead Claude
- Use clear section headers so Claude can locate and update specific entries

## Related

- See @memory-commands.md for how to open and edit these files
- See `SKILL.md` for guidance on what belongs in MEMORY.md vs CLAUDE.md
