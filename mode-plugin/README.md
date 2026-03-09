# Mode Plugin

**Version:** 1.0.0

Persistent interaction modes that change how Claude responds until explicitly exited. Switch between creative brainstorming, challenger stress-testing, and teaching explanations.

## Features

- **Creative Mode** - Divergent brainstorming with 3-4 named directions and "yes and" energy
- **Challenger Mode** - Devil's advocate stress-testing with alternatives and steelman conclusions
- **Teaching Mode** - Step-by-step explanations with progressive disclosure and "why" rationale
- **Mode Persistence** - Modes stay active across exchanges until explicitly exited
- **Natural Language Triggers** - Activate modes via phrases like "brainstorm" or "challenge this"

## Installation

### Via Marketplace

```bash
claude plugin install mode-plugin@content-platform-marketplace
```

### Manual Installation

1. Clone the repository
2. Add path to `~/.claude/settings.json` plugins array
3. Restart Claude Code

## Prerequisites

- Claude Code v1.0+

## Quick Start

1. Enter a mode: `/mode:creative`
2. Work in that mode - Claude adapts all responses to the mode's style
3. Exit when done: `/mode:exit`

## Commands

| Command | Description |
|---------|-------------|
| `/mode:creative` | Divergent brainstorming, 3-4 directions, "yes and" energy |
| `/mode:challenger` | Devil's advocate, stress-test ideas, steelman at end |
| `/mode:teaching` | Step-by-step with "why", progressive disclosure |
| `/mode:exit` | Return to default response behavior |
| `/mode:status` | Show current active mode |

## Troubleshooting

### Command not found

**Solution:** Ensure the plugin is installed and Claude Code has been restarted.

### Mode reverts unexpectedly

**Solution:** Modes persist automatically. If you notice default behavior, invoke `/mode:status` to check state, then re-enter your desired mode.

### Generators exit my mode

**Solution:** This should not happen. Generators (`/gen:*`) run independently and do not exit modes. If this occurs, re-enter the mode after generating.

## Contributing

Contributions welcome. Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

MIT

## Version History

Check `.claude-plugin/plugin.json` for current version.
