# Gen Plugin

**Version:** 1.0.0

One-shot artifact generators that produce formatted output for different audiences without changing your current mode.

## Features

- **Executive Briefs** - Generate concise summaries for leadership with business impact and clear recommendations
- **Technical Deep Dives** - Create engineering-depth analysis with code examples and trade-off tables
- **Talking Points** - Prepare structured presentation notes with anticipated Q&A and objection handling

## Installation

### Via Marketplace

```bash
claude plugin install gen-plugin@content-platform-marketplace
```

### Manual Installation

1. Clone the repository
2. Add path to `~/.claude/settings.json` plugins array
3. Restart Claude Code

## Prerequisites

- Claude Code v1.5.0+

## Quick Start

1. Run `/gen:exec-brief` after discussing a topic to generate a leadership summary
2. Use `/gen:tech-deep-dive` to document architectural decisions for engineers
3. Try `/gen:talking-points` before stakeholder presentations

## Skills

| Skill | Description | Invoke |
|-------|-------------|--------|
| `exec-brief` | Generate executive summaries (max 150 words) for leadership | `/gen:exec-brief` |
| `tech-deep-dive` | Generate technical analysis with code and trade-offs | `/gen:tech-deep-dive` |
| `talking-points` | Generate presentation prep with Q&A and objection handling | `/gen:talking-points` |

## Commands

| Command | Description | Invoke |
|---------|-------------|--------|
| `exec-brief` | Generate executive-level summary for leadership audiences | `/gen:exec-brief` |
| `tech-deep-dive` | Generate engineering-depth technical analysis | `/gen:tech-deep-dive` |
| `talking-points` | Generate presentation talking points and meeting prep | `/gen:talking-points` |

## Troubleshooting

### Skill not found

**Solution:** Ensure the plugin is installed and Claude Code has been restarted.

### Generator changes my current mode

**Solution:** Generators are one-shot artifacts and should not affect your mode. If this happens, use `/mode:status` to check your current mode and `/mode:exit` to return to default.

### Output is too long for exec-brief

**Solution:** The exec-brief generator has a 150-word constraint. If you need more detail, use `/gen:tech-deep-dive` instead, or ask for a more focused summary on a specific aspect.

## Contributing

Contributions welcome. Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

MIT

## Version History

Check `.claude-plugin/plugin.json` for current version.
