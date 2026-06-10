# Magpie Marketplace

A collection of shiny, useful Claude Code plugins — hoarded responsibly.

This is an open catalog of plugins for extending AI-assisted development workflows with Claude Code. Plugins are organisation-agnostic and designed for community use — install any of them independently.

## Installation

```bash
claude plugin add /path/to/magpie-marketplace/<plugin-name>
```

---

## Catalog

### Development & Authoring

| Plugin | Version | Description |
|--------|---------|-------------|
| **[claude-code-development-kit](./claude-code-development-kit)** | 2.1.0 | Complete toolkit for building Claude Code extensions - skills, commands, plugins, and supporting infrastructure. Includes guides for skill authoring, prompt engineering, command creation, plugin development, and memory management. |
| **[plugin-profile](./plugin-profile)** | 2.0.0 | Auto-detect project type and configure Claude Code plugins with profile management. |
| **[quality-assurance-toolkit](./quality-assurance-toolkit)** | 2.0.0 | Validation and quality assurance tools for plugins and skills. |

### Code Review & Quality

| Plugin | Version | Description |
|--------|---------|-------------|
| **[expert-review](./expert-review)** | 1.2.0 | Spawn expert sub-agents to review, iterate, and improve work at checkpoints. Supports parallel expert reviews with conflict resolution via domain precedence. |

### Orchestration & Workflow

| Plugin | Version | Description |
|--------|---------|-------------|
| **[orchestration-toolkit](./orchestration-toolkit)** | 3.0.0 | Composable pipeline for task decomposition and parallel agent execution. Includes decompose skill, orchestrate command, fan-out/team dispatch, and agent coordination patterns. |
| **[session-budget](./session-budget)** | 1.2.0 | Scope estimator that scores tasks by complexity, caps sessions at ~8 points, and recommends splitting work across sessions when overloaded. |
| **[session-autopilot](./session-autopilot)** | 0.1.0 | Automatic session continuity — handoff on exit, checkpoint on compact, resume on start. |
| **[todo-system](./todo-system)** | 1.0.0 | Portable todo management with paired session-launch prompts, category folders, modular gates, and auto-capture. |

### Content Generation

| Plugin | Version | Description |
|--------|---------|-------------|
| **[gen-plugin](./gen-plugin)** | 1.0.0 | One-shot artifact generators for different output formats - executive briefs, technical deep dives, and talking points. |
| **[mode-plugin](./mode-plugin)** | 1.0.0 | Persistent interaction modes for Claude Code responses - creative brainstorming, challenger stress-testing, and teaching explanations. |

### Research & Exploration

| Plugin | Version | Description |
|--------|---------|-------------|
| **[archaeology](./archaeology)** | 1.4.0 | Dig through Claude Code session history — survey projects, extract domain patterns, analyse workstyles, and conserve narrative artifacts. |
| **[iterative-usability](./iterative-usability)** | 1.1.0 | Agents that improve how Claude Code explores codebases and researches topics — writing persistent findings to disk instead of bloating the main context window. |
| **[knowledge-harvester](./knowledge-harvester)** | 0.1.0 | Multi-agent knowledge harvesting, validation, and synthesis from multiple sources. |

### Design & Reference

| Plugin | Version | Description |
|--------|---------|-------------|
| **[unicode-library](./unicode-library)** | 1.0.0 | Curated, tested Unicode character library for CLI visual design. The reference standard for branded terminal output in Claude Code skills, commands, and agents. |
