# Claude Code Development Kit — Expansion Roadmap

> **Created:** 2026-03-11
> **Source:** [Gap analysis](./2026-03-11-devkit-gap-analysis.md) from 4-stream parallel research
> **Maintainer mode:** `gaps` (run `/devkit-maintain gaps` to detect new untracked features)

---

## How to Use This Roadmap

Each **problem theme** groups related gaps by the user problem they solve. Each item within a theme includes:

1. **Problem statement** — what the user struggles with today
2. **Sub-problems** — specific knowledge gaps
3. **Investigation prompt** — a complete, self-contained prompt to kick off research and implementation
4. **Status** — `planned` | `in-progress` | `complete` | `blocked`

To work on any item: copy its investigation prompt into a new Claude Code session. The prompt is designed to run autonomously through research, synthesis, and implementation.

---

## Global Acceptance Criteria

Every new dev kit section (skill, reference, or schema addition) must satisfy ALL of these before merging:

### Content Criteria

- [ ] **Official source verified**: All claims traced to `code.claude.com/docs`, `github.com/anthropics/claude-code` releases, or reproducible local testing
- [ ] **Non-documented enhancements corroborated**: Any feature not in official docs must be verified by at least 2 independent community sources OR local reproduction
- [ ] **No speculative content**: Nothing based on "should work" or "probably supports" — only verified behaviour
- [ ] **Actionable examples**: At least 2 concrete, copy-pasteable examples per major concept
- [ ] **Anti-patterns documented**: At least 1 "don't do this" per major concept, sourced from real failure modes
- [ ] **Cross-references**: Links to related dev kit skills where concepts overlap (e.g., hooks skill links to permissions)

### Structural Criteria

- [ ] **Skill format**: SKILL.md with valid YAML frontmatter per `schemas/skill-frontmatter.json`
- [ ] **Reference files**: Deep-dive content in `references/` subdirectory, not crammed into SKILL.md
- [ ] **Under 500 lines**: SKILL.md body (excluding frontmatter) stays under 500 lines; overflow goes to references
- [ ] **Naming convention**: Follows existing verb-prefix pattern (`understanding-*`, `using-*`, `authoring-*`, `managing-*`)
- [ ] **Plugin.json**: No explicit component arrays (Claude Code auto-discovers)

### Validation Criteria

- [ ] **`validate-skill.sh` passes**: Frontmatter valid, line count within bounds, @path imports resolve
- [ ] **`validate-references.sh` passes**: All cross-file references resolve
- [ ] **`validate-plugin.sh` passes**: Full plugin validation after addition
- [ ] **`check-schema-drift.sh` passes**: No new drift introduced
- [ ] **Maintainer audit clean**: `devkit-maintain audit` reports no new errors or warnings related to the addition

### Review Criteria

- [ ] **Skill description triggers correctly**: Test that the skill's `description` field causes Claude to invoke it in the right contexts (and not wrong ones)
- [ ] **No overlap with existing skills**: Content doesn't duplicate what another skill already covers — extends or cross-references instead
- [ ] **Consistent terminology**: Uses the same terms as official docs (e.g., "subagent" not "sub-agent", "permission mode" not "access level")

---

## Investigation Prompt Template

All investigation prompts below follow this structure. When creating new roadmap items, use this template:

```
You are expanding the Claude Code Development Kit (a Claude Code plugin at
claude-code-development-kit/ in this repository).

## Task
Research, synthesise, and implement a new skill covering: {TOPIC}

## Research Phase
1. **Official docs**: Fetch and read the relevant pages from code.claude.com/docs/en/
   targeting these specific pages: {PAGE_LIST}
2. **Changelog verification**: Search github.com/anthropics/claude-code/releases for
   features related to {TOPIC} added since September 2025
3. **Community corroboration**: Search for community patterns, tips, and gotchas related
   to {TOPIC} from: awesome-claude-code repos, dev.to advent calendar, claudefa.st,
   Reddit r/ClaudeAI
4. **Local verification**: Where possible, verify claims by checking Claude Code's
   actual behaviour (e.g., test a setting, run a command, check a schema)

## Synthesis Phase
1. Create a structured outline covering: core concepts, configuration options,
   practical examples, anti-patterns, and cross-references to existing dev kit skills
2. Identify any features NOT in official docs but corroborated by 2+ community sources
3. Flag any conflicts between official docs and observed behaviour

## Implementation Phase
1. Create the skill at: claude-code-development-kit/skills/{SKILL_NAME}/SKILL.md
2. Create reference files at: claude-code-development-kit/skills/{SKILL_NAME}/references/
3. Follow the naming convention: {VERB_PREFIX}-{topic}
4. Ensure SKILL.md body stays under 500 lines; deep content goes to references/
5. Include at least 2 concrete examples and 1 anti-pattern per major concept
6. Add cross-references to related skills: {RELATED_SKILLS}

## Validation Phase
1. Run: bash claude-code-development-kit/evals/validate-skill.sh claude-code-development-kit/skills/{SKILL_NAME}/SKILL.md
2. Run: bash claude-code-development-kit/evals/validate-references.sh claude-code-development-kit/skills/{SKILL_NAME}/
3. Run: bash claude-code-development-kit/evals/validate-plugin.sh claude-code-development-kit/
4. Fix any errors before considering the task complete

## Output
- The new skill files
- A summary of what was added, what was verified, and any open questions
- Any schema updates needed (e.g., new enum values for tools-enum.json)
```

---

## Theme 1: Context Economics & Session Performance

> **Problem:** Users burn through context windows, hit degraded performance mid-session, and overspend — without understanding why or how to prevent it.

### 1.1 Understanding Context Windows — `understanding-context`
**Status:** `planned` | **Priority:** P0

**Sub-problems:**
- Users don't know about the hidden 33-45K token reserve (16-22% of 200K)
- Context rot after compaction causes repeated work and contradictions
- No guidance on when to `/clear` vs `/compact` vs start a new session
- MCP tools silently consume 8-30% of context just by being available
- Large file reads and pasted code blocks waste tokens on irrelevant content

**Investigation prompt:**
```
You are expanding the Claude Code Development Kit (a Claude Code plugin at
claude-code-development-kit/ in this repository).

## Task
Research, synthesise, and implement a new skill covering: Context window mechanics,
compaction behaviour, and session performance patterns.

## Research Phase
1. **Official docs**: Fetch and read:
   - code.claude.com/docs/en/costs
   - code.claude.com/docs/en/settings (CLAUDE_AUTOCOMPACT_PCT_OVERRIDE, MAX_OUTPUT_TOKENS)
   - code.claude.com/docs/en/interactive-mode (/compact, /context, /clear, /cost)
2. **Changelog verification**: Search github.com/anthropics/claude-code/releases for
   features related to compaction, context, token management added since September 2025
3. **Community corroboration**: Search for context management patterns from:
   - claudefa.st/blog/guide/mechanics/context-buffer-management (hidden buffer)
   - vincentvandeth.nl/blog/context-rot (compaction degradation)
   - institute.sfeir.com/en/claude-code/claude-code-context-management/
   - dev.to/oikon advent calendar tips on context
4. **Local verification**: Test /context, /cost, /compact commands. Verify
   CLAUDE_AUTOCOMPACT_PCT_OVERRIDE behaviour. Check MCP tool context overhead
   with /context before and after enabling MCP servers.

## Synthesis Phase
1. Create a structured outline covering: context window anatomy (usable vs reserved),
   compaction mechanics (when/how/what's lost), cost monitoring commands, MCP context
   overhead, token-saving strategies, session lifecycle patterns
2. Identify any features NOT in official docs but corroborated by 2+ community sources
3. Flag any conflicts between official docs and observed behaviour

## Implementation Phase
1. Create the skill at: claude-code-development-kit/skills/understanding-context/SKILL.md
2. Create reference files at: claude-code-development-kit/skills/understanding-context/references/
   - context-anatomy.md (window structure, reserves, usable space)
   - compaction-guide.md (when to compact, what's preserved, context rot mitigation)
   - cost-optimization.md (token-saving patterns, MCP overhead, file read strategies)
3. Follow the naming convention: understanding-context
4. Ensure SKILL.md body stays under 500 lines; deep content goes to references/
5. Include at least 2 concrete examples and 1 anti-pattern per major concept
6. Add cross-references to related skills: using-tools, integrating-mcps, managing-memory

## Validation Phase
1. Run: bash claude-code-development-kit/evals/validate-skill.sh claude-code-development-kit/skills/understanding-context/SKILL.md
2. Run: bash claude-code-development-kit/evals/validate-references.sh claude-code-development-kit/skills/understanding-context/
3. Run: bash claude-code-development-kit/evals/validate-plugin.sh claude-code-development-kit/
4. Fix any errors before considering the task complete

## Output
- The new skill files
- A summary of what was added, what was verified, and any open questions
- Any schema updates needed (e.g., new enum values for tools-enum.json)
```

---

### 1.2 Model Selection & Effort Tuning — `choosing-models`
**Status:** `planned` | **Priority:** P0

**Sub-problems:**
- Users don't know when to use low/medium/high effort or how it affects output
- Fast mode (2.5x speed, higher cost) vs normal mode trade-offs unclear
- Extended thinking (Alt+T) usage guidance missing
- Subagent model selection has no guidance (when haiku vs sonnet vs opus)
- Third-party provider setup (Bedrock, Vertex, Foundry) undocumented
- `ultrathink` is the only keyword that triggers extended thinking — previous keywords disabled

**Investigation prompt:**
```
You are expanding the Claude Code Development Kit (a Claude Code plugin at
claude-code-development-kit/ in this repository).

## Task
Research, synthesise, and implement a new skill covering: Model selection, effort
levels, fast mode, extended thinking, and provider configuration.

## Research Phase
1. **Official docs**: Fetch and read:
   - code.claude.com/docs/en/model-config
   - code.claude.com/docs/en/fast-mode
   - code.claude.com/docs/en/settings (model-related fields)
2. **Changelog verification**: Search github.com/anthropics/claude-code/releases for
   effort levels, fast mode, ultrathink, model switching, Bedrock/Vertex/Foundry
3. **Community corroboration**: Search for model selection advice from:
   - dev.to/oikon advent calendar (tip #4 on ultrathink)
   - Community discussions on haiku vs sonnet vs opus for subagents
4. **Local verification**: Test /model command, Alt+P switching, effort level
   adjustment. Verify env vars: ANTHROPIC_MODEL, CLAUDE_CODE_EFFORT_LEVEL,
   CLAUDE_CODE_SUBAGENT_MODEL.

## Synthesis Phase
1. Create a structured outline covering: model aliases and tiers, effort levels
   (low/medium/high), fast mode mechanics, extended thinking activation, subagent
   model selection guide, third-party provider setup, env var reference
2. Identify any features NOT in official docs but corroborated by 2+ community sources
3. Flag any conflicts between official docs and observed behaviour

## Implementation Phase
1. Create the skill at: claude-code-development-kit/skills/choosing-models/SKILL.md
2. Create reference files at: claude-code-development-kit/skills/choosing-models/references/
   - effort-levels.md (low/medium/high behaviour and use cases)
   - provider-setup.md (Bedrock, Vertex, Foundry configuration)
   - subagent-model-guide.md (decision matrix for agent model selection)
3. Follow the naming convention: choosing-models
4. Ensure SKILL.md body stays under 500 lines; deep content goes to references/
5. Include at least 2 concrete examples and 1 anti-pattern per major concept
6. Add cross-references to related skills: authoring-agents, best-practices-reference

## Validation Phase
1. Run: bash claude-code-development-kit/evals/validate-skill.sh claude-code-development-kit/skills/choosing-models/SKILL.md
2. Run: bash claude-code-development-kit/evals/validate-references.sh claude-code-development-kit/skills/choosing-models/
3. Run: bash claude-code-development-kit/evals/validate-plugin.sh claude-code-development-kit/
4. Fix any errors before considering the task complete

## Output
- The new skill files
- A summary of what was added, what was verified, and any open questions
- Any schema updates needed
```

---

## Theme 2: Security & Permission Architecture

> **Problem:** Extension authors create skills, agents, and hooks without understanding the permission model they operate within — leading to broken workflows, over-permissioned agents, or confused users.

### 2.1 Understanding Permissions — `understanding-permissions`
**Status:** `planned` | **Priority:** P0

**Sub-problems:**
- 5 permission modes exist (`default`, `acceptEdits`, `plan`, `dontAsk`, `bypassPermissions`) but no dev kit guidance on when to use each
- Tool specifier syntax (`Bash(npm run *)`, `Read(path)`) undocumented in dev kit
- Deny-first evaluation order not explained
- `permissionMode` in agent frontmatter affects all subagent operations but this isn't covered in the agents skill
- Managed settings enforcement for enterprise deployments unknown to plugin authors

**Investigation prompt:**
```
You are expanding the Claude Code Development Kit (a Claude Code plugin at
claude-code-development-kit/ in this repository).

## Task
Research, synthesise, and implement a new skill covering: Permission modes, tool
specifiers, sandbox configuration, and the security model for extension authors.

## Research Phase
1. **Official docs**: Fetch and read:
   - code.claude.com/docs/en/permissions
   - code.claude.com/docs/en/settings (permissions, sandbox sections)
   - code.claude.com/docs/en/sub-agents (permissionMode field)
2. **Changelog verification**: Search github.com/anthropics/claude-code/releases for
   permission modes, sandbox, managed settings, security features since September 2025
3. **Community corroboration**: Search for permission/security patterns from:
   - dev.to/oikon advent calendar (tips #12-13 on permissions.deny and /sandbox)
   - Community hook recipes for credential filtering
4. **Local verification**: Test permission mode cycling (Shift+Tab), verify tool
   specifier syntax in settings.json, check sandbox behaviour.

## Synthesis Phase
1. Create a structured outline covering: permission mode descriptions and use cases,
   tool specifier pattern syntax, settings.json permission rules (allow/ask/deny),
   sandbox configuration (filesystem + network), managed settings for enterprise,
   permission mode in agent frontmatter, interaction with hooks
2. Identify any features NOT in official docs but corroborated by 2+ community sources
3. Flag any conflicts between official docs and observed behaviour

## Implementation Phase
1. Create the skill at: claude-code-development-kit/skills/understanding-permissions/SKILL.md
2. Create reference files at: claude-code-development-kit/skills/understanding-permissions/references/
   - permission-modes.md (5 modes with use cases and trade-offs)
   - tool-specifiers.md (pattern syntax, examples, deny-first evaluation)
   - sandbox-config.md (filesystem rules, network rules, auto-allow)
   - enterprise-controls.md (managed settings, forced login, MCP restrictions)
3. Follow the naming convention: understanding-permissions
4. Ensure SKILL.md body stays under 500 lines; deep content goes to references/
5. Include at least 2 concrete examples and 1 anti-pattern per major concept
6. Add cross-references to related skills: authoring-agents, understanding-hooks, integrating-mcps

## Validation Phase
1. Run: bash claude-code-development-kit/evals/validate-skill.sh claude-code-development-kit/skills/understanding-permissions/SKILL.md
2. Run: bash claude-code-development-kit/evals/validate-references.sh claude-code-development-kit/skills/understanding-permissions/
3. Run: bash claude-code-development-kit/evals/validate-plugin.sh claude-code-development-kit/
4. Fix any errors before considering the task complete

## Output
- The new skill files
- A summary of what was added, what was verified, and any open questions
- Any schema updates needed
```

---

## Theme 3: Automation & Programmatic Usage

> **Problem:** Users who want Claude Code in CI pipelines, scripts, or custom tooling have no dev kit guidance — they're reading raw CLI docs and figuring it out alone.

### 3.1 Headless Mode & CI Integration — `using-headless-mode`
**Status:** `planned` | **Priority:** P0

**Sub-problems:**
- `-p`/`--print` mode mechanics (single prompt, exit codes, output formats) not covered
- Structured output via `--json-schema` enables validated responses but is undocumented
- `--max-turns` and `--max-budget-usd` for cost control in automation
- GitHub Actions (`anthropics/claude-code-action`) and GitLab CI integration patterns
- `--system-prompt` and `--append-system-prompt` for custom agent behaviour in pipelines
- Stream JSON format for real-time output processing

**Investigation prompt:**
```
You are expanding the Claude Code Development Kit (a Claude Code plugin at
claude-code-development-kit/ in this repository).

## Task
Research, synthesise, and implement a new skill covering: Headless/SDK mode, CI/CD
integration, structured outputs, and programmatic Claude Code usage.

## Research Phase
1. **Official docs**: Fetch and read:
   - code.claude.com/docs/en/headless
   - code.claude.com/docs/en/github-actions
   - code.claude.com/docs/en/gitlab-ci-cd
   - code.claude.com/docs/en/cli-reference (print mode flags)
2. **Changelog verification**: Search github.com/anthropics/claude-code/releases for
   headless mode, json-schema, stream-json, CI integration since September 2025
3. **Community corroboration**: Search for CI/automation patterns from:
   - institute.sfeir.com/en/claude-code/claude-code-headless-mode-and-ci-cd/
   - Community GitHub Actions workflows using claude-code-action
4. **Local verification**: Test `claude -p "hello" --output-format json`, verify
   exit codes, test --max-turns behaviour.

## Synthesis Phase
1. Create a structured outline covering: headless mode basics, output formats
   (text/json/stream-json), structured output with --json-schema, cost controls
   (--max-turns, --max-budget-usd), system prompt customization, GitHub Actions
   setup, GitLab CI setup, common automation recipes
2. Identify any features NOT in official docs but corroborated by 2+ community sources
3. Flag any conflicts between official docs and observed behaviour

## Implementation Phase
1. Create the skill at: claude-code-development-kit/skills/using-headless-mode/SKILL.md
2. Create reference files at: claude-code-development-kit/skills/using-headless-mode/references/
   - output-formats.md (text, json, stream-json with examples)
   - ci-recipes.md (GitHub Actions, GitLab CI, generic CI patterns)
   - structured-outputs.md (--json-schema usage, validation, error handling)
3. Follow the naming convention: using-headless-mode
4. Ensure SKILL.md body stays under 500 lines; deep content goes to references/
5. Include at least 2 concrete examples and 1 anti-pattern per major concept
6. Add cross-references to related skills: using-tools, understanding-permissions

## Validation Phase
1. Run: bash claude-code-development-kit/evals/validate-skill.sh claude-code-development-kit/skills/using-headless-mode/SKILL.md
2. Run: bash claude-code-development-kit/evals/validate-references.sh claude-code-development-kit/skills/using-headless-mode/
3. Run: bash claude-code-development-kit/evals/validate-plugin.sh claude-code-development-kit/
4. Fix any errors before considering the task complete

## Output
- The new skill files
- A summary of what was added, what was verified, and any open questions
- Any schema updates needed
```

---

## Theme 4: Parallel Work & Isolation

> **Problem:** Users working on multiple features, running parallel agents, or coordinating team workflows have no dev kit guidance on isolation, worktrees, or agent teams.

### 4.1 Git Worktree Workflows — `using-worktrees`
**Status:** `planned` | **Priority:** P0

**Sub-problems:**
- `--worktree` / `-w` flag creates isolated branches but workflow patterns not documented
- `isolation: worktree` in agent frontmatter for automatic subagent isolation
- `WorktreeCreate`/`WorktreeRemove` hook events for custom setup/teardown
- Mental model: subagents for same-branch concurrency, worktrees for different-branch parallelism
- Real-world patterns (incident.io runs 4-5 parallel agents on worktrees)

**Investigation prompt:**
```
You are expanding the Claude Code Development Kit (a Claude Code plugin at
claude-code-development-kit/ in this repository).

## Task
Research, synthesise, and implement a new skill covering: Git worktree workflows,
parallel agent isolation, and multi-branch development patterns.

## Research Phase
1. **Official docs**: Fetch and read:
   - code.claude.com/docs/en/common-workflows (worktree sections)
   - code.claude.com/docs/en/sub-agents (isolation: worktree)
   - code.claude.com/docs/en/hooks (WorktreeCreate, WorktreeRemove events)
2. **Changelog verification**: Search github.com/anthropics/claude-code/releases for
   worktree, isolation, ExitWorktree since September 2025
3. **Community corroboration**: Search for worktree patterns from:
   - incident.io/blog/shipping-faster-with-claude-code-and-git-worktrees
   - claudefa.st/blog/guide/development/worktree-guide
   - github.com/nwiizo/ccswarm, github.com/spillwavesolutions/parallel-worktrees
4. **Local verification**: Test `claude -w`, verify worktree creation location,
   check cleanup behaviour on session end.

## Synthesis Phase
1. Create a structured outline covering: worktree basics (flag, location, cleanup),
   agent isolation (frontmatter field), hook events for custom setup, mental model
   (same-branch vs cross-branch parallelism), real-world workflow patterns
2. Identify any features NOT in official docs but corroborated by 2+ community sources
3. Flag any conflicts between official docs and observed behaviour

## Implementation Phase
1. Create the skill at: claude-code-development-kit/skills/using-worktrees/SKILL.md
2. Create reference files at: claude-code-development-kit/skills/using-worktrees/references/
   - worktree-patterns.md (parallel development workflows, case studies)
   - agent-isolation.md (frontmatter config, cleanup, hook integration)
3. Follow the naming convention: using-worktrees
4. Ensure SKILL.md body stays under 500 lines; deep content goes to references/
5. Include at least 2 concrete examples and 1 anti-pattern per major concept
6. Add cross-references to related skills: authoring-agents, understanding-hooks

## Validation Phase
1. Run: bash claude-code-development-kit/evals/validate-skill.sh claude-code-development-kit/skills/using-worktrees/SKILL.md
2. Run: bash claude-code-development-kit/evals/validate-references.sh claude-code-development-kit/skills/using-worktrees/
3. Run: bash claude-code-development-kit/evals/validate-plugin.sh claude-code-development-kit/
4. Fix any errors before considering the task complete

## Output
- The new skill files
- A summary of what was added, what was verified, and any open questions
- Any schema updates needed
```

---

### 4.2 Agent Teams — `using-agent-teams`
**Status:** `planned` | **Priority:** P0

**Sub-problems:**
- Agent teams are experimental (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) but represent a new collaboration paradigm
- Shared task lists, peer messaging via `SendMessage`, `TeamCreate`/`TeamDelete` lifecycle
- `--teammate-mode` display options (`auto`, `in-process`, `tmux`)
- `TeammateIdle` and `TaskCompleted` hook events for team coordination
- No dev kit guidance on designing team-aware skills or agents

**Investigation prompt:**
```
You are expanding the Claude Code Development Kit (a Claude Code plugin at
claude-code-development-kit/ in this repository).

## Task
Research, synthesise, and implement a new skill covering: Agent teams, shared task
lists, team messaging, and designing team-aware extensions.

## Research Phase
1. **Official docs**: Fetch and read:
   - code.claude.com/docs/en/agent-teams
   - code.claude.com/docs/en/hooks (TeammateIdle, TaskCompleted events)
   - code.claude.com/docs/en/sub-agents (team-related fields)
2. **Changelog verification**: Search github.com/anthropics/claude-code/releases for
   agent teams, SendMessage, TeamCreate, teammate-mode since February 2026
3. **Community corroboration**: Search for team patterns from:
   - Anthropic demos (16 parallel agents building a C compiler)
   - Community team orchestration tools (ccswarm, ccpm)
4. **Local verification**: Check env var CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS,
   test TeamCreate if available.

## Synthesis Phase
1. Create a structured outline covering: team creation and lifecycle, task list
   sharing, messaging patterns, hook events for teams, teammate display modes,
   designing team-aware agents and skills, current limitations (experimental)
2. Identify any features NOT in official docs but corroborated by 2+ community sources
3. Flag any conflicts between official docs and observed behaviour

## Implementation Phase
1. Create the skill at: claude-code-development-kit/skills/using-agent-teams/SKILL.md
2. Create reference files at: claude-code-development-kit/skills/using-agent-teams/references/
   - team-lifecycle.md (create, manage, shutdown patterns)
   - team-messaging.md (SendMessage, broadcast, idle handling)
   - team-aware-extensions.md (designing skills/agents for team contexts)
3. Follow the naming convention: using-agent-teams
4. Ensure SKILL.md body stays under 500 lines; deep content goes to references/
5. Include at least 2 concrete examples and 1 anti-pattern per major concept
6. Add cross-references to related skills: authoring-agents, using-worktrees

## Validation Phase
1. Run: bash claude-code-development-kit/evals/validate-skill.sh claude-code-development-kit/skills/using-agent-teams/SKILL.md
2. Run: bash claude-code-development-kit/evals/validate-references.sh claude-code-development-kit/skills/using-agent-teams/
3. Run: bash claude-code-development-kit/evals/validate-plugin.sh claude-code-development-kit/
4. Fix any errors before considering the task complete

## Output
- The new skill files
- A summary of what was added, what was verified, and any open questions
- Any schema updates needed
```

---

## Theme 5: Keeping Existing Skills Current

> **Problem:** Claude Code ships features weekly. The dev kit's existing skills fall behind — covering base concepts but missing newer events, types, and configuration options.

### 5.1 Hooks System Refresh — update `understanding-hooks`
**Status:** `planned` | **Priority:** P1

**Sub-problems:**
- Dev kit covers basic hooks but misses 4 hook types (command, http, prompt, agent)
- Missing events: `Setup`, `InstructionsLoaded`, `ConfigChange`, `WorktreeCreate`/`WorktreeRemove`, `PreCompact`, `TeammateIdle`, `TaskCompleted`, `SubagentStart`, `SubagentStop`, `Notification`
- JSON output with `hookSpecificOutput` for permission decisions undocumented
- Input modification via PreToolUse hooks (tool input rewriting)
- Async hooks, subagent-scoped hooks (in agent frontmatter)
- Community hook recipes not captured (auto-format, credential filtering, session replication)

**Investigation prompt:**
```
You are expanding the Claude Code Development Kit (a Claude Code plugin at
claude-code-development-kit/ in this repository).

## Task
Audit and update the existing understanding-hooks skill to cover all hook types,
events, and patterns available as of March 2026.

## Research Phase
1. **Official docs**: Fetch and read:
   - code.claude.com/docs/en/hooks
   - code.claude.com/docs/en/hooks-guide
2. **Changelog verification**: Search github.com/anthropics/claude-code/releases for
   hook-related features: new events, hook types, HTTP hooks, prompt hooks, agent hooks
3. **Community corroboration**: Search for hook recipes from:
   - github.com/disler/claude-code-hooks-mastery
   - dev.to/oikon advent calendar (tips #14-15 on hooks)
   - Community auto-format and credential filtering patterns
4. **Local verification**: Read the current skill at
   claude-code-development-kit/skills/understanding-hooks/ and diff against official docs.

## Synthesis Phase
1. Identify specific gaps between current skill content and official docs
2. List new events, types, and patterns not covered
3. Compile community hook recipes worth including

## Implementation Phase
1. Update: claude-code-development-kit/skills/understanding-hooks/SKILL.md
2. Add/update reference files as needed for:
   - Complete event reference (all 18+ events with matchers)
   - Hook type guide (command, http, prompt, agent)
   - Hook recipes cookbook (community patterns)
   - Subagent-scoped hooks guide
3. Preserve existing content that's still accurate — extend, don't rewrite
4. Add cross-references to: understanding-permissions, authoring-agents, using-agent-teams

## Validation Phase
1. Run: bash claude-code-development-kit/evals/validate-skill.sh claude-code-development-kit/skills/understanding-hooks/SKILL.md
2. Run: bash claude-code-development-kit/evals/validate-references.sh claude-code-development-kit/skills/understanding-hooks/
3. Run: bash claude-code-development-kit/evals/validate-plugin.sh claude-code-development-kit/
4. Fix any errors before considering the task complete

## Output
- Updated skill files with diff summary
- List of what was added vs what was already covered
- Any schema updates needed
```

---

### 5.2 MCP Advanced Patterns — update `integrating-mcps`
**Status:** `planned` | **Priority:** P1

**Sub-problems:**
- MCP Tool Search (deferred tool loading, 85% context savings) not covered
- MCP prompts as commands (`/mcp__<server>__<prompt>`) not covered
- Context overhead warning (8-30% of context from tool descriptions) missing
- `--strict-mcp-config` for CI/testing not covered
- Subagent MCP access patterns (name reference vs inline definition)
- Enterprise controls (`allowedMcpServers`, `deniedMcpServers`) missing

**Investigation prompt:**
```
You are expanding the Claude Code Development Kit (a Claude Code plugin at
claude-code-development-kit/ in this repository).

## Task
Audit and update the existing integrating-mcps skill to cover advanced MCP patterns
available as of March 2026.

## Research Phase
1. **Official docs**: Fetch and read:
   - code.claude.com/docs/en/mcp
   - code.claude.com/docs/en/settings (MCP-related fields)
   - code.claude.com/docs/en/sub-agents (mcpServers field)
2. **Changelog verification**: Search github.com/anthropics/claude-code/releases for
   MCP Tool Search, auto:N, list_changed, strict-mcp-config, MCP prompts
3. **Community corroboration**: Search for MCP patterns from:
   - dev.to/oikon advent calendar (tip #7 on MCP context overhead)
   - Community MCP server recommendations (Context7, Sequential Thinking)
   - claudefa.st MCP extension guides
4. **Local verification**: Read the current skill at
   claude-code-development-kit/skills/integrating-mcps/ and diff against official docs.
   Test /mcp command to see tool search behaviour.

## Synthesis Phase
1. Identify specific gaps between current skill content and official docs
2. List advanced patterns not covered (Tool Search, prompts-as-commands, enterprise)
3. Compile context overhead data and mitigation strategies

## Implementation Phase
1. Update: claude-code-development-kit/skills/integrating-mcps/SKILL.md
2. Add/update reference files as needed for:
   - Tool Search / deferred loading guide
   - Context overhead and mitigation
   - Enterprise MCP controls
   - Subagent MCP access patterns
3. Preserve existing content that's still accurate — extend, don't rewrite
4. Add cross-references to: understanding-context, authoring-agents, understanding-permissions

## Validation Phase
1. Run: bash claude-code-development-kit/evals/validate-skill.sh claude-code-development-kit/skills/integrating-mcps/SKILL.md
2. Run: bash claude-code-development-kit/evals/validate-references.sh claude-code-development-kit/skills/integrating-mcps/
3. Run: bash claude-code-development-kit/evals/validate-plugin.sh claude-code-development-kit/
4. Fix any errors before considering the task complete

## Output
- Updated skill files with diff summary
- List of what was added vs what was already covered
- Any schema updates needed
```

---

## Theme 6: Configuration & Reference

> **Problem:** Claude Code has 50+ settings, 30+ env vars, and 48+ slash commands — but no unified reference in the dev kit. Users hunt across multiple docs pages.

### 6.1 Settings Reference — `configuring-settings`
**Status:** `planned` | **Priority:** P1

**Sub-problems:**
- 4 settings scopes (managed > user > project > local) with precedence rules
- 50+ settings.json fields with no unified dev kit reference
- Sandbox configuration (filesystem allowWrite/denyWrite/denyRead, network domains)
- Enterprise fields (forceLoginMethod, companyAnnouncements, allowManagedHooksOnly)
- Customization fields (statusLine, fileSuggestion, spinnerVerbs, spinnerTips)

**Investigation prompt:**
```
You are expanding the Claude Code Development Kit (a Claude Code plugin at
claude-code-development-kit/ in this repository).

## Task
Research, synthesise, and implement a new skill providing a unified settings.json
reference with scope hierarchy, field descriptions, and practical examples.

## Research Phase
1. **Official docs**: Fetch and read:
   - code.claude.com/docs/en/settings (comprehensive — this is the primary source)
2. **Changelog verification**: Search github.com/anthropics/claude-code/releases for
   new settings fields added since September 2025
3. **Community corroboration**: Search for settings tips and configurations from
   community resources
4. **Local verification**: Check actual settings.json schema in Claude Code.
   Examine ~/.claude/settings.json for field format examples.

## Synthesis Phase
1. Create a structured outline covering: scope hierarchy with precedence, field
   reference grouped by category (permissions, sandbox, model, UI, enterprise),
   practical configuration recipes, common mistakes
2. Identify any settings NOT in official docs but corroborated by 2+ community sources
3. Flag any deprecated or renamed settings

## Implementation Phase
1. Create the skill at: claude-code-development-kit/skills/configuring-settings/SKILL.md
2. Create reference files at: claude-code-development-kit/skills/configuring-settings/references/
   - scope-hierarchy.md (4 scopes, precedence, file locations)
   - field-reference.md (all fields grouped by category)
   - sandbox-config.md (filesystem and network rules with examples)
   - enterprise-settings.md (managed settings, restrictions, announcements)
3. Follow the naming convention: configuring-settings
4. Ensure SKILL.md body stays under 500 lines; deep content goes to references/
5. Include at least 2 concrete examples and 1 anti-pattern per major concept
6. Add cross-references to related skills: understanding-permissions, integrating-mcps

## Validation Phase
1. Run: bash claude-code-development-kit/evals/validate-skill.sh claude-code-development-kit/skills/configuring-settings/SKILL.md
2. Run: bash claude-code-development-kit/evals/validate-references.sh claude-code-development-kit/skills/configuring-settings/
3. Run: bash claude-code-development-kit/evals/validate-plugin.sh claude-code-development-kit/
4. Fix any errors before considering the task complete

## Output
- The new skill files
- A summary of what was added, what was verified, and any open questions
- Any schema updates needed
```

---

### 6.2 Environment Variables Reference — `reference: env-vars`
**Status:** `planned` | **Priority:** P2

**Sub-problems:**
- 30+ env vars scattered across docs with no unified listing
- Model overrides, context controls, feature flags, provider selection, timeout tuning
- Some vars are undocumented but widely used in community

**Investigation prompt:**
```
You are expanding the Claude Code Development Kit (a Claude Code plugin at
claude-code-development-kit/ in this repository).

## Task
Research and create a comprehensive environment variables reference, either as a
standalone skill or as a reference file within configuring-settings.

## Research Phase
1. **Official docs**: Fetch and read:
   - code.claude.com/docs/en/settings (env vars section)
   - code.claude.com/docs/en/cli-reference
   - code.claude.com/docs/en/model-config
   - code.claude.com/docs/en/costs
2. **Changelog verification**: Search github.com/anthropics/claude-code/releases for
   new environment variables added since September 2025
3. **Community corroboration**: Search for env var tips from community resources
4. **Local verification**: Test key env vars locally to verify behaviour

## Synthesis Phase
1. Compile complete env var list grouped by function: model, context, features,
   providers, performance, debugging
2. For each: name, type, default, description, example

## Implementation Phase
1. Create as: claude-code-development-kit/skills/configuring-settings/references/env-vars.md
   (reference file under the settings skill)
2. Structured as a table with name, default, description, and example columns
3. Add cross-references from SKILL.md

## Validation Phase
1. Run: bash claude-code-development-kit/evals/validate-references.sh claude-code-development-kit/skills/configuring-settings/
2. Run: bash claude-code-development-kit/evals/validate-plugin.sh claude-code-development-kit/
3. Fix any errors before considering the task complete

## Output
- The reference file
- A summary of verified vs unverified env vars
```

---

## Theme 7: Interactive Experience

> **Problem:** The dev kit focuses on extension authoring but ignores the daily interactive experience — the 48+ commands, keyboard shortcuts, vim mode, and productivity features that make Claude Code powerful.

### 7.1 Interactive Mode Reference — `using-interactive-mode`
**Status:** `planned` | **Priority:** P0

**Sub-problems:**
- 48+ slash commands with no dev kit coverage beyond the commands skill
- Keyboard shortcuts (Alt+P, Alt+T, Shift+Tab, Ctrl+T, Ctrl+B, Ctrl+R, Ctrl+G)
- Vim mode activation and keybindings
- Custom keybindings via `keybindings.json`
- Checkpointing and rewind (Esc+Esc, `/rewind`)
- Task list, prompt suggestions, output styles, themes
- `!` bash mode, `@` file mentions, image paste

**Investigation prompt:**
```
You are expanding the Claude Code Development Kit (a Claude Code plugin at
claude-code-development-kit/ in this repository).

## Task
Research, synthesise, and implement a new skill covering: Interactive mode features,
keyboard shortcuts, slash commands, and productivity patterns.

## Research Phase
1. **Official docs**: Fetch and read:
   - code.claude.com/docs/en/interactive-mode
   - code.claude.com/docs/en/checkpointing
   - code.claude.com/docs/en/features-overview
2. **Changelog verification**: Search github.com/anthropics/claude-code/releases for
   interactive features: vim mode, keybindings, task list, /btw, prompt suggestions
3. **Community corroboration**: Search for interactive mode tips from:
   - dev.to/oikon advent calendar
   - ykdojo/claude-code-tips
   - Community keybinding configurations
4. **Local verification**: Test key features: /context, /diff, Esc+Esc rewind,
   Ctrl+T task list, vim mode toggle.

## Synthesis Phase
1. Create a structured outline covering: command reference (grouped by function),
   keyboard shortcut cheatsheet, vim mode guide, custom keybindings,
   checkpointing/rewind workflow, output styles, themes
2. Identify any features NOT in official docs but corroborated by 2+ community sources
3. Flag any deprecated commands or changed shortcuts

## Implementation Phase
1. Create the skill at: claude-code-development-kit/skills/using-interactive-mode/SKILL.md
2. Create reference files at: claude-code-development-kit/skills/using-interactive-mode/references/
   - command-reference.md (all commands grouped by function)
   - keyboard-shortcuts.md (complete shortcut cheatsheet)
   - checkpointing-guide.md (rewind workflow and patterns)
3. Follow the naming convention: using-interactive-mode
4. Ensure SKILL.md body stays under 500 lines; deep content goes to references/
5. Include at least 2 concrete examples and 1 anti-pattern per major concept
6. Add cross-references to related skills: using-commands, using-tools

## Validation Phase
1. Run: bash claude-code-development-kit/evals/validate-skill.sh claude-code-development-kit/skills/using-interactive-mode/SKILL.md
2. Run: bash claude-code-development-kit/evals/validate-references.sh claude-code-development-kit/skills/using-interactive-mode/
3. Run: bash claude-code-development-kit/evals/validate-plugin.sh claude-code-development-kit/
4. Fix any errors before considering the task complete

## Output
- The new skill files
- A summary of what was added, what was verified, and any open questions
- Any schema updates needed
```

---

## Theme 8: Plugin Distribution & Enterprise

> **Problem:** Plugin authors can create plugins but lack guidance on distribution mechanics, marketplace publishing, enterprise deployment, and trust management.

### 8.1 Plugin Distribution — update `creating-plugins`
**Status:** `planned` | **Priority:** P1

**Sub-problems:**
- 6 marketplace source types (GitHub, git, URL, npm, file, directory) but only basic coverage
- `git-subdir` source for monorepo plugin extraction
- `pathPattern` regex for scoped plugin activation
- Enterprise controls (`strictKnownMarketplaces`, `blockedMarketplaces`, `pluginTrustMessage`)
- `/reload-plugins` workflow for development iteration
- Plugin trust model and approval flow

**Investigation prompt:**
```
You are expanding the Claude Code Development Kit (a Claude Code plugin at
claude-code-development-kit/ in this repository).

## Task
Audit and update the existing creating-plugins skill to cover distribution
mechanics, marketplace publishing, and enterprise deployment as of March 2026.

## Research Phase
1. **Official docs**: Fetch and read:
   - code.claude.com/docs/en/plugins
   - code.claude.com/docs/en/plugins-reference
   - code.claude.com/docs/en/discover-plugins
   - code.claude.com/docs/en/settings (plugin-related fields)
2. **Changelog verification**: Search github.com/anthropics/claude-code/releases for
   plugin features: git-subdir, pathPattern, marketplace, trust since October 2025
3. **Community corroboration**: Search for plugin distribution patterns from community
4. **Local verification**: Read the current skill at
   claude-code-development-kit/skills/creating-plugins/ and diff against official docs.

## Synthesis Phase
1. Identify specific gaps between current skill content and official docs
2. List distribution mechanics not covered (source types, enterprise controls)
3. Compile trust model and approval flow documentation

## Implementation Phase
1. Update: claude-code-development-kit/skills/creating-plugins/SKILL.md
2. Add/update reference files as needed for:
   - Distribution guide (all 6 source types with examples)
   - Enterprise deployment (managed marketplaces, trust settings)
   - Plugin development workflow (/reload-plugins, iteration patterns)
3. Preserve existing content that's still accurate — extend, don't rewrite
4. Add cross-references to: understanding-permissions, configuring-settings

## Validation Phase
1. Run: bash claude-code-development-kit/evals/validate-skill.sh claude-code-development-kit/skills/creating-plugins/SKILL.md
2. Run: bash claude-code-development-kit/evals/validate-references.sh claude-code-development-kit/skills/creating-plugins/
3. Run: bash claude-code-development-kit/evals/validate-plugin.sh claude-code-development-kit/
4. Fix any errors before considering the task complete

## Output
- Updated skill files with diff summary
- List of what was added vs what was already covered
- Any schema updates needed
```

---

## Maintenance: Gap Detection Mode

> The maintainer agent gains a new `gaps` mode that cross-references this roadmap against
> the latest Claude Code features to identify untracked capabilities.

See: Enhancement to `agents/devkit-maintainer.md` — adds `gaps` mode with:
1. Fetch latest changelog/releases
2. Cross-reference against this roadmap's coverage
3. Cross-reference against existing skills
4. Report: new features not mapped to any roadmap item or existing skill
5. Suggest: which theme the new feature belongs to, or if a new theme is needed

---

## Roadmap Summary

| # | Item | Theme | Type | Priority | Status |
|---|------|-------|------|----------|--------|
| 1.1 | `understanding-context` | Context Economics | New skill | P0 | planned |
| 1.2 | `choosing-models` | Context Economics | New skill | P0 | planned |
| 2.1 | `understanding-permissions` | Security | New skill | P0 | planned |
| 3.1 | `using-headless-mode` | Automation | New skill | P0 | planned |
| 4.1 | `using-worktrees` | Parallel Work | New skill | P0 | planned |
| 4.2 | `using-agent-teams` | Parallel Work | New skill | P0 | planned |
| 5.1 | `understanding-hooks` refresh | Keeping Current | Update | P1 | planned |
| 5.2 | `integrating-mcps` refresh | Keeping Current | Update | P1 | planned |
| 6.1 | `configuring-settings` | Configuration | New skill | P1 | planned |
| 6.2 | env vars reference | Configuration | Reference | P2 | planned |
| 7.1 | `using-interactive-mode` | Interactive | New skill | P0 | planned |
| 8.1 | `creating-plugins` refresh | Distribution | Update | P1 | planned |
