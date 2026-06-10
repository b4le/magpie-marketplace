# Memory Commands Reference

Commands for viewing, editing, and controlling Claude Code's auto-memory system.

## `/memory` — View and Manage Memory

Opens an interactive file selector showing all loaded memory files for the current session.

```
/memory
```

### What the selector shows

- `MEMORY.md` — the auto memory entrypoint for the current project
- `~/.claude/CLAUDE.md` — your user-level manual memory
- `.claude/CLAUDE.md` — the project-level manual memory (if present)
- Any additional files imported via `@path` in CLAUDE.md files

### Auto-memory toggle

The `/memory` selector includes an **auto-memory toggle**. Use it to enable or disable auto memory for the current project without editing settings files.

### Editing memory directly

Selecting a file from the `/memory` selector opens it in your system editor. You can freely edit `MEMORY.md` — Claude treats it as a regular markdown file and will respect any changes you make.

To remove a memory, delete the relevant line or section from the file. Claude will stop referencing it in future sessions.

## Saving Context Explicitly — Natural Language

There is no formal `/remember` command. Instead, tell Claude directly in natural language during a session:

```
Remember that we use pnpm, not npm
```

```
Save to memory that the API tests require a local Redis instance running on port 6379
```

```
Note for memory: the staging environment uses feature flags controlled by the FEATURE_FLAGS env var
```

Claude writes the information to `MEMORY.md` (or an appropriate topic file in the memory directory) immediately.

### Effective phrasing patterns

| Pattern | Example |
|---------|---------|
| `Remember that...` | "Remember that this repo uses Bun, not Node" |
| `Save to memory that...` | "Save to memory that deploy is done via `make deploy`" |
| `Note for memory:` | "Note for memory: never use `git push --force` on this repo" |

### What Claude saves vs ignores

Claude is selective about what it saves automatically. It tends to save:
- Corrections you make (e.g., "no, use single quotes")
- Package manager / build tool preferences
- Frequently used commands
- Key architecture or technology decisions

It does not exhaustively log every fact from the session. For critical context that must persist, use an explicit "remember that" instruction rather than relying on Claude to decide.

## Removing or Editing Memories

Auto memory files are plain markdown. You can edit them at any time:

1. Run `/memory` to open the file selector
2. Select `MEMORY.md` (or the relevant topic file)
3. Edit or delete entries directly
4. Save the file

Changes take effect in the next session (or immediately if Claude re-reads the file during the current session).

## Disabling Auto Memory

To disable auto memory without editing settings files, run `/memory` and use the toggle in the selector.

For persistent settings-based disabling, see the main SKILL.md.

## Related

- See `SKILL.md` for context on when to use auto memory vs CLAUDE.md
- See @memory-md-format.md for the file structure Claude uses
