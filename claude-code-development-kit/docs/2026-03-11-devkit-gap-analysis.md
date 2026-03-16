# Claude Code Dev Kit — Gap Analysis

> **Date:** 2026-03-11
> **Method:** 4 parallel researchers (official docs, changelog, community, competitors)
> **Dev Kit Version:** 2.1.0 (15 skills)

## TL;DR

The dev kit covers **authoring and configuration** well but has significant gaps in **operational knowledge** — how to actually use Claude Code day-to-day. The official docs have grown far beyond what the dev kit tracks, and community patterns reveal practical wisdom that no reference captures.

---

## Gap Severity Key

- **P0 — Missing entirely, high value**: Topics the dev kit should cover but doesn't
- **P1 — Partial coverage, needs deepening**: Topics touched on but lacking depth vs. official docs
- **P2 — Nice to have**: Supplementary content that would round out the kit
- **P3 — Monitor**: Emerging patterns worth watching

---

## P0 — Missing Entirely, High Value

### 1. Permissions & Security Model
**What exists officially:** Detailed docs on 5 permission modes (`default`, `acceptEdits`, `plan`, `dontAsk`, `bypassPermissions`), tool specifier patterns (`Bash(npm run *)`, `Read(path)`), deny-first evaluation, sandboxing (Seatbelt/bubblewrap), filesystem/network sandbox config, managed settings enforcement.

**What the dev kit has:** Nothing dedicated. Hooks skill mentions permissions tangentially.

**Why it matters:** This is the #1 thing plugin/skill authors need to understand — their code runs inside a permission system. Authors need to know how `permissionMode` in agent frontmatter affects their agents, how to write permission rules, and sandbox constraints.

---

### 2. Context Window & Cost Management
**What exists officially:** Auto-compaction at ~95%, `/compact`, `/context`, `/cost`, `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`, `CLAUDE_CODE_MAX_OUTPUT_TOKENS`, effort levels, fast mode, MCP Tool Search (85% context savings), prompt caching.

**What community discovered:** Hidden 33-45K token buffer (16-22% of 200K), context rot after compaction, MCP tools consuming 8-30% of context just by existing, three levers that reduce consumption by ~40%.

**What the dev kit has:** Nothing. This is arguably the most impactful operational knowledge.

**Why it matters:** Every skill and agent author needs to understand context economics. Skills that read too many files, agents that spawn too many MCP tools — these directly degrade Claude's performance.

---

### 3. Headless/SDK Mode & CI/CD Patterns
**What exists officially:** `-p`/`--print` mode, output formats (`text`, `json`, `stream-json`), `--max-turns`, `--max-budget-usd`, `--json-schema` for structured output, `--allowedTools`, `--system-prompt`, exit codes, GitHub Actions (`anthropics/claude-code-action`), GitLab CI/CD integration.

**What the dev kit has:** Nothing on programmatic usage or CI integration.

**Why it matters:** Headless mode is how Claude Code gets embedded in pipelines, scripts, and automation. It's a primary consumption pattern alongside interactive mode.

---

### 4. Git Worktree Workflows
**What exists officially:** `--worktree` / `-w` flag, `isolation: worktree` in agent frontmatter, `WorktreeCreate`/`WorktreeRemove` hook events, `ExitWorktree` tool.

**What community discovered:** incident.io runs 4-5 parallel agents on worktrees; clear mental model (subagents for same-branch, worktrees for different-branch parallelism); dedicated tools like ccswarm and Worktrunk.

**What the dev kit has:** Nothing dedicated. The `using-git-worktrees` skill is in superpowers, not the dev kit.

**Why it matters:** Worktrees are the primary isolation mechanism for parallel agent work. Plugin/skill authors building multi-agent workflows need this.

---

### 5. Agent Teams
**What exists officially:** Experimental feature with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`, shared task lists, peer messaging, `SendMessage` tool, `TeamCreate`/`TeamDelete`, `--teammate-mode`, `TeammateIdle` hook event, `TaskCompleted` hook event.

**What the dev kit has:** Nothing. Agent teams launched Feb 2026 and the dev kit hasn't covered them.

**Why it matters:** Agent teams represent a fundamentally new collaboration pattern. Even as experimental, authors building team-aware skills/agents need guidance.

---

### 6. Interactive Mode Features Reference
**What exists officially:** 48+ slash commands, vim mode, custom keybindings (`keybindings.json`), model switching (Alt+P), effort adjustment, Shift+Tab permission cycling, prompt suggestions, task list (Ctrl+T), checkpointing/rewind (Esc+Esc), image paste, `/btw` side questions, `!` bash mode, `@` file mentions.

**What the dev kit has:** `using-commands` covers slash command concepts but not the interactive mode features as a whole.

**Why it matters:** Users learning Claude Code need a practical reference for the interactive experience, not just the extension points.

---

### 7. Model Configuration & Effort Levels
**What exists officially:** Model aliases, effort levels (low/medium/high), fast mode (`/fast`), extended thinking (Alt+T), `--fallback-model`, third-party providers (Bedrock, Vertex, Foundry), per-tier model env var overrides, subagent model override.

**What the dev kit has:** Brief mention in agent frontmatter docs. No dedicated guide.

**Why it matters:** Model selection directly affects cost, speed, and quality. Skill/agent authors need to know when to use `model: haiku` vs letting the user's model inherit.

---

## P1 — Partial Coverage, Needs Deepening

### 8. Hooks System — Newer Events & Types
**Dev kit covers:** Basic hook concepts, command-type hooks, core events.

**Missing from dev kit:**
- Hook types `prompt` and `agent` (added later)
- HTTP hooks (POST JSON)
- Events: `Setup`, `InstructionsLoaded`, `ConfigChange`, `WorktreeCreate`/`WorktreeRemove`, `PreCompact`, `TeammateIdle`, `TaskCompleted`, `SubagentStart`, `SubagentStop`
- Matcher patterns for MCP tools
- JSON output with `hookSpecificOutput` for `permissionDecision`
- Input modification via PreToolUse hooks
- Async hooks
- Subagent-scoped hooks (in agent frontmatter)
- Community recipes: auto-format on edit, credential filtering, notification hooks

### 9. MCP Integration — Advanced Patterns
**Dev kit covers:** Basic connection, transport types, configuration locations.

**Missing from dev kit:**
- MCP Tool Search / deferred tool loading (auto mode, context savings)
- MCP prompts as commands (`/mcp__<server>__<prompt>`)
- Context overhead warning (8-30% of context consumed by tool descriptions alone)
- `--strict-mcp-config` for CI/testing
- Subagent MCP access patterns (name reference vs inline definition)
- Enterprise controls (`allowedMcpServers`, `deniedMcpServers`)
- Recommended community MCP servers (Context7, Sequential Thinking, Playwright)

### 10. Settings.json — Comprehensive Reference
**Dev kit covers:** Mentions settings in various skills but no unified reference.

**Missing from dev kit:** Unified reference for all settings.json fields across all 4 scopes (managed > user > project > local), especially:
- `sandbox` configuration object
- `env` for environment variables
- `statusLine` and `fileSuggestion` custom commands
- `spinnerVerbs` and `spinnerTips` customization
- Enterprise fields (`forceLoginMethod`, `companyAnnouncements`, etc.)
- `respectGitignore`, `terminalProgressBarEnabled`, `prefersReducedMotion`

### 11. Plugin System — Distribution & Enterprise
**Dev kit covers:** Plugin structure, creation, basic distribution.

**Missing from dev kit:**
- Full marketplace mechanics (GitHub, git, URL, npm, file, directory sources)
- `git-subdir` source for monorepo plugins
- `pathPattern` regex for scoped activation
- Enterprise marketplace controls (`strictKnownMarketplaces`, `blockedMarketplaces`)
- Plugin trust model and `pluginTrustMessage`
- LSP server support in plugins (mentioned but undocumented)
- `/reload-plugins` workflow

### 12. Skills System — Advanced Features
**Dev kit covers:** Skill authoring, frontmatter, structure.

**Missing from dev kit:**
- `context: fork` for isolated subagent execution
- Skill hot-reload behavior
- Skills auto-loading from `--add-dir`
- `disable-model-invocation` frontmatter field
- Built-in skills reference (`/simplify`, `/batch`, `/debug`)
- Frontmatter hooks within skills

---

## P2 — Nice to Have

### 13. CLAUDE.md Templates & Best Practices Gallery
Community has produced extensive templates (rohitg00 toolkit has 7 including monorepo). Official guidance says "under 200 lines" and recommends 10 sections. The dev kit's `managing-memory` skill covers structure but lacks practical templates users can copy.

### 14. Environment Variables Reference
Official docs reference 30+ env vars across different pages. No unified reference exists in the dev kit. Key ones: `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`, `CLAUDE_CODE_EFFORT_LEVEL`, `CLAUDE_CODE_MAX_OUTPUT_TOKENS`, `CLAUDE_CODE_DISABLE_*` flags, provider vars.

### 15. Chrome Integration
Official feature for connecting to Chrome browser — web app testing, console debugging, form automation. Not covered at all.

### 16. Remote Control & Teleport
Continue local sessions from mobile, `/teleport` to resume web sessions locally. Not covered.

### 17. Desktop App Features
Visual diff review, multi-session, scheduled tasks, cloud sessions, `/desktop` handoff.

### 18. IDE Integration Patterns
VS Code extension features (inline diffs, @-mentions, plan review), JetBrains plugin. Not covered — the dev kit focuses on terminal CLI.

### 19. Hook Recipes Cookbook
Community has shared valuable recipes:
- Auto-format after file edits (PostToolUse)
- Credential/API key filtering (UserPromptSubmit + PreToolUse)
- Session environment replication for remote (SessionStart)
- Notification hooks for idle/permission/auth events
- Pre-commit validation hooks
Source: `disler/claude-code-hooks-mastery` repo, Advent Calendar tips

### 20. Performance Optimization Guide
Community patterns not captured anywhere:
- `/clear` between distinct tasks (stale context hurts)
- Don't paste large code blocks (500 lines = 4K tokens)
- Give agents feedback loops (test commands, linters) for 2-3x quality improvement
- Only `ultrathink` triggers extended thinking
- Start new conversations for new topics

---

## P3 — Monitor

### 21. AGENTS.md Cross-Tool Standard
18.8k GitHub stars, supported by Cursor, Windsurf, Kilo Code, OpenAI Codex. Claude Code doesn't support it yet but the momentum is notable. Worth monitoring for interoperability.

### 22. Community Rules Directory
Cursor has `cursor.directory`, Windsurf has its directory, Copilot has `awesome-copilot`. No equivalent exists for Claude Code skills/rules. The dev kit could potentially serve as a seed for one.

### 23. Agent SDK (Separate from Claude Code)
The Agent SDK (`platform.claude.com/docs/en/agent-sdk`) lets developers build custom agents with Claude Code's tools. It's a separate product surface but the dev kit could reference it for advanced users building their own agent loops.

### 24. Claude Code Security
Enterprise vulnerability scanning feature (Feb 2026). Minimal public documentation so far.

### 25. Voice Mode
20 languages, rebindable push-to-talk, added Mar 2026. Too new to document fully.

---

## Coverage Matrix

| Topic | Official Docs | Dev Kit | Gap |
|-------|:---:|:---:|:---:|
| Authoring skills | Yes | **Yes** | - |
| Authoring agents | Yes | **Yes** | Minor (teams, isolation) |
| Authoring output styles | Yes | **Yes** | - |
| Creating commands | Yes | **Yes** | - |
| Creating plugins | Yes | **Yes** | Distribution depth |
| Using tools | Yes | **Yes** | - |
| Using commands | Yes | **Yes** | - |
| Understanding hooks | Yes | **Partial** | Newer events/types |
| Understanding auto-memory | Yes | **Yes** | - |
| Managing memory (CLAUDE.md) | Yes | **Yes** | Templates |
| Integrating MCPs | Yes | **Partial** | Tool Search, context cost |
| Resolving issues | Yes | **Yes** | - |
| Best practices reference | Yes | **Yes** | - |
| **Permissions & security** | Yes | **No** | **P0** |
| **Context & cost management** | Yes | **No** | **P0** |
| **Headless/SDK/CI mode** | Yes | **No** | **P0** |
| **Git worktree workflows** | Yes | **No** | **P0** |
| **Agent teams** | Yes | **No** | **P0** |
| **Interactive mode reference** | Yes | **No** | **P0** |
| **Model config & effort** | Yes | **No** | **P0** |
| Settings.json reference | Yes | **No** | P1 |
| Environment variables | Yes | **No** | P2 |
| Chrome integration | Yes | **No** | P2 |
| Remote control / Teleport | Yes | **No** | P2 |
| Desktop app | Yes | **No** | P2 |
| IDE integrations | Yes | **No** | P2 |
| CI/CD integrations | Yes | **No** | P1 |
| Hook recipes | Community | **No** | P2 |
| Performance patterns | Community | **No** | P2 |
| CLAUDE.md templates | Community | **No** | P2 |

---

## Recommended Priority Order

If addressing gaps incrementally, this order maximizes value:

1. **Context & Cost Management** (P0) — affects every user's daily experience
2. **Permissions & Security** (P0) — critical for plugin/skill authors
3. **Hooks System Update** (P1) — bring existing skill current with 18 events, 4 types
4. **Model Config & Effort** (P0) — practical daily decision
5. **Headless/SDK/CI** (P0) — unlocks automation use cases
6. **Settings.json Reference** (P1) — unified reference saves everyone time
7. **Git Worktrees** (P0) — enables parallel workflows
8. **Agent Teams** (P0) — emerging pattern, early adopter value
9. **MCP Advanced Patterns** (P1) — Tool Search alone saves 85% context
10. **Interactive Mode Reference** (P0) — user onboarding

---

## Sources

### Official Documentation
- code.claude.com/docs/en/* (20+ pages referenced)
- platform.claude.com/docs/en/agent-sdk
- github.com/anthropics/claude-code (releases, README)
- github.com/anthropics/claude-plugins-official

### Changelog Tracking
- claudelog.com/claude-code-changelog/
- claudefa.st/blog/guide/changelog
- github.com/anthropics/claude-code/releases

### Community Resources
- hesreallyhim/awesome-claude-code
- rohitg00/awesome-claude-code-toolkit (135 agents, 42 commands, 19 hooks)
- ykdojo/claude-code-tips (45 tips)
- disler/claude-code-hooks-mastery
- dev.to/oikon — 24 Claude Code Tips Advent Calendar
- claudefa.st/blog — deep dives on context buffer, worktrees
- institute.sfeir.com — structured Claude Code course

### Competitor Analysis
- cursor.directory — community rules marketplace
- github.com/agentsmd/agents.md — cross-tool standard (18.8k stars)
- GitHub Copilot Extensions SDK
- Continue.dev — open-source AI coding with custom providers
- Cline Memory Bank — structured persistence pattern
