# Agent Config Examples

Translate a work item's `agent_config` block from plan JSON into Agent tool parameters.

## Mapping Table

| `agent_config` field | Agent tool parameter | Transformation rule |
|---|---|---|
| `subagent_type` | `subagent_type` | Direct pass-through. If `missing_specialist: true`, use `"implementation-agent"` (file creation/modification work) or `"general-purpose"` (review/exploration/research only). |
| `skills` | _(in `prompt`)_ | Not a tool parameter. Add `"Invoke skill: {skill-name} before implementation"` to the prompt for each listed skill. |
| `model` | `model` | Direct pass-through (`"sonnet"`, `"opus"`, or `"haiku"`). |
| `mode` | `mode` | Direct pass-through (`"acceptEdits"`, `"bypassPermissions"`, `"default"`, `"dontAsk"`, `"plan"`). |
| `max_turns` | `max_turns` | Direct pass-through (integer). |
| `isolation` | `isolation` | Pass `"worktree"` when value is `"worktree"`. **Omit entirely** when value is `"none"`. |
| `missing_specialist` | _(fallback logic)_ | If `true`, override `subagent_type` to `"implementation-agent"` and add a note to the prompt: `"Note: no specialist agent is available for this task."` |

**Fixed derivations (not from `agent_config`):**

| Agent tool parameter | Source |
|---|---|
| `name` | `"wi-{id}-{slug}"` where slug is kebab-case of the work item title (max 4 words) |
| `description` | Work item title, truncated to 5 words |
| `prompt` | Populated from `work-item-template.md` |
| `run_in_background` | `true` in fan-out mode; `false` (omit) in sequential mode |

---

## Examples

### Example 1: TypeScript specialist with skills and worktree isolation

**Work item `agent_config`:**
```json
{
  "agent_config": {
    "subagent_type": "typescript-pro",
    "skills": ["javascript-testing-patterns"],
    "model": "sonnet",
    "mode": "acceptEdits",
    "max_turns": 30,
    "missing_specialist": false,
    "isolation": "worktree"
  }
}
```

**Resulting Agent tool call:**
```json
{
  "name": "wi-3-auth-token-service",
  "subagent_type": "typescript-pro",
  "model": "sonnet",
  "mode": "acceptEdits",
  "max_turns": 30,
  "isolation": "worktree",
  "description": "Implement auth token service",
  "run_in_background": true,
  "prompt": "## Work Item: WI-3 — Implement Auth Token Service\n\nInvoke skill: javascript-testing-patterns before implementation\n\n### Scope\nImplement the AuthTokenService class with refresh logic and expiry checks.\n\n### Your Files (you own these exclusively)\n- `src/services/auth-token.service.ts` — create: TokenService class with refresh and validate methods\n- `src/services/auth-token.service.test.ts` — create: unit tests for all public methods\n\n### Pipeline\nFollow these steps in order:\n1. Read `src/services/` for existing service patterns\n2. Implement AuthTokenService per the interface contract below\n3. Write unit tests using javascript-testing-patterns conventions\n4. Run `npx tsc --noEmit` and fix type errors\n5. Run `npm test -- auth-token` and fix failures\n\n### Context\nRead these files for context before starting:\n- `src/services/user.service.ts`\n- `src/types/auth.ts`\n\n### Interface Contracts\n**You must provide (others depend on):**\n- `AuthTokenService` exported from `src/services/auth-token.service.ts`\n- `validateToken(token: string): boolean` method\n- `refreshToken(token: string): Promise<string>` method\n\n### Done Criteria\nYour work is complete when ALL of these are true:\n- [ ] `src/services/auth-token.service.ts` exists and compiles with no type errors\n- [ ] `npm test -- auth-token` passes with coverage ≥ 80%\n\n### Constraints\n- Only create or modify files listed in \"Your Files\" above\n- Do not modify any other files in the repository\n- If you discover a file you need to edit that isn't in your list, note it in your completion message rather than editing it\n- Follow existing code patterns and conventions in the codebase"
}
```

---

### Example 2: Simple implementation, no specialist, no isolation

**Work item `agent_config`:**
```json
{
  "agent_config": {
    "subagent_type": "implementation-agent",
    "skills": [],
    "model": "sonnet",
    "mode": "acceptEdits",
    "max_turns": 20,
    "missing_specialist": false,
    "isolation": "none"
  }
}
```

**Resulting Agent tool call:**
```json
{
  "name": "wi-1-update-readme",
  "subagent_type": "implementation-agent",
  "model": "sonnet",
  "mode": "acceptEdits",
  "max_turns": 20,
  "description": "Update README installation section",
  "prompt": "## Work Item: WI-1 — Update README Installation Section\n\n### Scope\nRewrite the installation section of README.md to reflect the new Docker-based setup.\n\n### Your Files (you own these exclusively)\n- `README.md` — modify: update the Installation section only\n\n### Pipeline\nFollow these steps in order:\n1. Read `README.md` to understand current structure\n2. Read `docker-compose.yml` to understand the new setup steps\n3. Rewrite the Installation section with accurate Docker instructions\n\n### Context\nRead these files for context before starting:\n- `docker-compose.yml`\n- `docs/setup-guide.md`\n\n### Done Criteria\nYour work is complete when ALL of these are true:\n- [ ] README.md Installation section reflects Docker setup steps\n- [ ] No other sections of README.md are modified\n\n### Constraints\n- Only create or modify files listed in \"Your Files\" above\n- Do not modify any other files in the repository\n- If you discover a file you need to edit that isn't in your list, note it in your completion message rather than editing it\n- Follow existing code patterns and conventions in the codebase"
}
```

Note: `isolation` is omitted entirely because the plan value is `"none"`. `run_in_background` is omitted because this is sequential mode.

---

### Example 3: Missing specialist fallback

**Work item `agent_config`:**
```json
{
  "agent_config": {
    "subagent_type": "elixir-pro",
    "skills": [],
    "model": "opus",
    "mode": "acceptEdits",
    "max_turns": 40,
    "missing_specialist": true,
    "isolation": "none"
  }
}
```

**Resulting Agent tool call:**
```json
{
  "name": "wi-2-add-genserver-cache",
  "subagent_type": "implementation-agent",
  "model": "opus",
  "mode": "acceptEdits",
  "max_turns": 40,
  "description": "Add GenServer cache module",
  "run_in_background": true,
  "prompt": "## Work Item: WI-2 — Add GenServer Cache Module\n\nNote: no specialist agent is available for this task. The plan requested \"elixir-pro\" but no Elixir specialist is installed. Proceeding as a general implementation agent — apply extra care with language idioms.\n\n### Scope\nImplement a GenServer-based in-memory cache module with TTL support.\n\n### Your Files (you own these exclusively)\n- `lib/my_app/cache.ex` — create: GenServer cache with get/put/delete and TTL expiry\n\n### Pipeline\nFollow these steps in order:\n1. Read `lib/my_app/` for existing module patterns\n2. Implement Cache GenServer following OTP conventions\n3. Register the module in `lib/my_app/application.ex` supervision tree\n\n### Context\nRead these files for context before starting:\n- `lib/my_app/application.ex`\n- `lib/my_app/repo.ex`\n\n### Done Criteria\nYour work is complete when ALL of these are true:\n- [ ] `lib/my_app/cache.ex` exists with a working GenServer implementation\n- [ ] Cache process starts cleanly under the application supervisor\n\n### Constraints\n- Only create or modify files listed in \"Your Files\" above\n- Do not modify any other files in the repository\n- If you discover a file you need to edit that isn't in your list, note it in your completion message rather than editing it\n- Follow existing code patterns and conventions in the codebase"
}
```

`subagent_type` is overridden from `"elixir-pro"` to `"implementation-agent"`. The gap is surfaced in the prompt so the agent compensates with extra care. The plan already specified `"opus"` — when a plan specifies `"sonnet"` or `"haiku"` and `missing_specialist: true`, consider upgrading to `"opus"` to compensate.

---

## Guidance for Orchestrators

- **`name` format:** `"wi-{id}-{slug}"`. Slug is the work item title in kebab-case, trimmed to the first 4 meaningful words. Example: `"wi-5-parse-csv-headers"`.
- **`description` format:** Work item title truncated to 5 words. Example: `"Parse CSV header row"`.
- **`prompt` construction:** Fill in `work-item-template.md` from the plan's work item fields. The template is static; execution fills placeholders.
- **Skills go in the prompt, not as a tool parameter.** For each skill in `agent_config.skills`, prepend to the prompt body: `"Invoke skill: {skill-name} before implementation"`. One line per skill.
- **`isolation: "none"` means omit the parameter.** Do not pass `isolation: "none"` to the Agent tool — simply leave the parameter out.
- **`run_in_background` is mode-driven:** fan-out sets it `true`; sequential mode omits it.
- **`missing_specialist: true` requires two changes:** override `subagent_type` to `"implementation-agent"` if the work creates/modifies files, or `"general-purpose"` if it's review/exploration only; then add the gap note to the prompt. Consider upgrading `model` to `"opus"` to compensate.
- **Do not invent parameters.** Only pass the Agent tool parameters listed in the mapping table. No additional fields.
