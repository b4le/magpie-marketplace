# Archaeology

Dig through Claude Code session history — survey projects, extract domain patterns, analyse workstyles, and conserve narrative artifacts.

## Quick start

```bash
/archaeology                # Survey current project
/archaeology list           # Show available domains
/archaeology orchestration  # Extract orchestration patterns
/archaeology workstyle      # Analyse working style
/archaeology conserve       # Preserve narrative artifacts
/archaeology excavation     # Portfolio scan across all projects
```

## Layout

```
archaeology/
├── .claude-plugin/plugin.json   # Plugin manifest
├── skills/archaeology/          # Skill definition + references
│   ├── SKILL.md                 # Main skill entry point
│   ├── SCHEMA.md                # Output schema
│   └── references/              # Workflow specs, parsers, domains
├── scripts/                     # Shell scripts (validation, excavation)
└── docs/                        # Design docs, showcase
```

Output data (surveys, orchestration findings) lives outside the repo at `~/.claude/archaeology/`.

## Version

1.3.0
