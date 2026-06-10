# Auto-Triggering Criteria Reference

**Version**: 1.0.0
**Last Updated**: 2025-11-24
**Purpose**: Comprehensive guide for when the multi-agent-workflows skill should automatically activate

---

## Table of Contents

1. [Auto-Triggering Overview](#auto-triggering-overview)
2. [Trigger Patterns](#trigger-patterns)
3. [Trigger Conditions](#trigger-conditions)
4. [Detection Logic](#detection-logic)
5. [Examples](#examples)
6. [Manual Invocation](#manual-invocation)
7. [Decision Matrix](#decision-matrix)

---

## Auto-Triggering Overview

### What is Auto-Triggering?

Auto-triggering means the multi-agent-workflows skill **automatically activates** when Claude detects specific patterns or complexity thresholds in a user's request—without requiring explicit invocation (e.g., `/orchestrate` or "use orchestrator").

### Why Auto-Trigger?

**Philosophy**: Complex, multi-phase workflows should **default to orchestration** for:
- **Context efficiency**: Main orchestrator stays under 5K tokens
- **Scalability**: 5+ sub-agents coordinated without bloat
- **Persistence**: Work survives interruptions via `.development/` state
- **Clarity**: Structured phases prevent chaos in large implementations

**User experience**: Users shouldn't need to understand orchestration mechanics to benefit from them. When they request "implement full authentication system", auto-triggering ensures best practices are applied automatically.

### How It Differs from Manual Invocation

| Aspect | Auto-Triggered | Manual Invocation |
|--------|----------------|-------------------|
| **User action** | Describes complex task naturally | Explicitly requests orchestration |
| **Activation** | Pattern/condition matching | Commands like `/orchestrate` or "use orchestrator" |
| **Use case** | Clear complexity signals (10+ files, 5+ steps) | User prefers orchestration for simpler tasks |
| **Examples** | "Implement full auth system" | "Orchestrate this 3-step refactor" |

---

## Trigger Patterns

### Pattern Matching (from SKILL.md frontmatter)

The skill auto-triggers when user requests match these regex patterns:

| Pattern | Regex | Explanation |
|---------|-------|-------------|
| **Feature implementation** | `implement .* (feature\|system\|architecture)` | Indicates complete feature build (not small change) |
| **Full builds** | `build .* (full\|complete\|entire)` | Signals comprehensive construction effort |
| **Architecture refactors** | `refactor .* (architecture\|system)` | Implies multi-file, multi-phase restructuring |
| **Migrations** | `migrate .* (codebase\|system)` | Suggests moving entire system (not single file) |

### Pattern Matching Examples

#### ✅ Should Match

| User Request | Pattern Matched | Reasoning |
|-------------|----------------|-----------|
| "Implement authentication feature" | `implement .* feature` | Full feature implementation |
| "Build complete API system" | `build .* complete` | Comprehensive system build |
| "Refactor the entire architecture" | `refactor .* architecture` | Large-scale refactor |
| "Migrate our codebase to TypeScript" | `migrate .* codebase` | System-wide migration |
| "Implement user permission system" | `implement .* system` | Full system implementation |

#### ❌ Should NOT Match

| User Request | Why It Doesn't Match | Correct Tool |
|-------------|---------------------|--------------|
| "Implement this function" | "function" not in pattern (feature/system/architecture) | Direct Task tool |
| "Build a quick prototype" | "quick" contradicts "full/complete/entire" | Direct execution |
| "Refactor this file" | "file" not "architecture/system" | Direct Edit tool |
| "Migrate one component" | "one component" not "codebase/system" | Direct Task tool |

### Pattern Nuances

**Keyword Modifiers** (strengthen trigger confidence):
- "full", "complete", "entire" → High confidence
- "comprehensive", "end-to-end" → High confidence
- "quick", "simple", "single" → Suppress trigger (even if pattern matches)

**Context Matters**:
```
"Implement authentication feature for our SaaS app"
→ Triggers (feature + system context)

"Implement the login button feature"
→ May not trigger (trivial scope, despite "feature")
```

---

## Trigger Conditions

### Complexity Thresholds (from SKILL.md frontmatter)

The skill auto-triggers when user requests imply:

| Condition | Threshold | Detection Strategy |
|-----------|-----------|-------------------|
| **Implementation steps** | 5+ steps mentioned | Count discrete actions in request |
| **Files affected** | 10+ files estimated | Infer from scope (e.g., "full auth" → models, routes, middleware, tests) |
| **Multi-phase workflow** | Keywords present | Detect "planning", "research", "design", "implementation", "review" |

### Step Counting Guide

**What counts as a step?**
- Creating a new file/module
- Modifying existing functionality
- Setting up infrastructure (database, API routes)
- Writing tests
- Configuring external services (OAuth, email)

**Example**:
```
User: "Implement full authentication system with OAuth, email verification,
       password reset, and role-based access control"

Steps detected:
1. OAuth integration (Google/GitHub providers)
2. User model with auth fields
3. Auth routes (login, signup, logout)
4. Email verification flow
5. Password reset flow
6. Role/permission system
7. Auth middleware
8. Tests for all flows
→ 8 steps detected → TRIGGER ✅
```

### File Estimation Guide

**How to estimate files affected?**

Use domain knowledge to infer scope:

| Request Type | Typical Files Affected |
|-------------|----------------------|
| "Full auth system" | 10-15 files (models, routes, middleware, migrations, tests, config) |
| "Complete API" | 15-20 files (routes, controllers, models, validators, docs, tests) |
| "Entire frontend refactor" | 20+ files (components, pages, hooks, context, styles, tests) |
| "Migrate to TypeScript" | All existing files + type definitions |
| "Single feature" | 3-5 files (typically below threshold) |

**Example**:
```
User: "Build complete REST API for blog platform"

Estimated files:
- /routes/posts.js (1)
- /routes/users.js (1)
- /routes/comments.js (1)
- /controllers/*.js (3)
- /models/*.js (3)
- /middleware/*.js (2)
- /validators/*.js (3)
- /tests/*.test.js (6)
- /config/api.js (1)
- /docs/api-spec.yaml (1)
→ ~22 files estimated → TRIGGER ✅
```

### Multi-Phase Keywords

**Workflow phases mentioned in request?**

| Keyword | Phase | Example |
|---------|-------|---------|
| "plan", "design", "architect" | Planning/Design | "First, let's plan the database schema" |
| "research", "investigate", "analyze" | Research | "Research best practices for OAuth 2.1" |
| "implement", "build", "code" | Execution | "Then implement the auth routes" |
| "test", "validate", "review" | Review | "Finally, test all flows end-to-end" |

**Trigger when 2+ phases mentioned**:
```
User: "First research how Next.js handles auth, then design our schema,
       and finally implement the system"
→ 3 phases detected (research, design, implement) → TRIGGER ✅
```

---

## Detection Logic

### Step-by-Step Detection Algorithm

When a user makes a request, analyze it using this logic:

```
1. PATTERN CHECK
   ├─ Does request match any trigger patterns?
   │  ├─ Yes → Increase confidence by 30%
   │  └─ No → Continue to conditions
   │
2. STEP COUNT
   ├─ Parse request for discrete actions
   ├─ Count total steps
   │  ├─ 5+ steps? → Increase confidence by 30%
   │  └─ <5 steps? → Decrease confidence by 10%
   │
3. FILE ESTIMATION
   ├─ Infer scope from domain knowledge
   ├─ Estimate files affected
   │  ├─ 10+ files? → Increase confidence by 30%
   │  └─ <10 files? → Decrease confidence by 10%
   │
4. PHASE DETECTION
   ├─ Search for multi-phase keywords
   ├─ Count distinct phases mentioned
   │  ├─ 2+ phases? → Increase confidence by 20%
   │  └─ 0-1 phases? → No change
   │
5. MODIFIER CHECK
   ├─ Look for scope modifiers
   │  ├─ "full/complete/entire" → Increase confidence by 10%
   │  └─ "quick/simple/single" → Decrease confidence by 20%
   │
6. FINAL DECISION
   ├─ Confidence ≥ 50%? → AUTO-TRIGGER
   ├─ Confidence 30-49%? → ASK USER ("Would you like me to orchestrate this?")
   └─ Confidence <30%? → USE DIRECT TOOLS
```

### Confidence Scoring Example

```
User Request: "Implement complete authentication system with OAuth and email verification"

Step 1: Pattern Check
  - Matches "implement .* system" → +30% (total: 30%)

Step 2: Step Count
  - OAuth setup (1)
  - User model (2)
  - Auth routes (3)
  - Email verification (4)
  - Email templates (5)
  - Auth middleware (6)
  - Tests (7)
  → 7 steps → +30% (total: 60%)

Step 3: File Estimation
  - Auth routes, user model, middleware, email service, templates, tests, config
  → ~12 files → +30% (total: 90%)

Step 4: Phase Detection
  - No explicit phases mentioned → 0% (total: 90%)

Step 5: Modifier Check
  - "complete" detected → +10% (total: 100%)

Step 6: Final Decision
  - 100% confidence → AUTO-TRIGGER ✅
```

### Edge Case Handling

| Scenario | Confidence Score | Action |
|----------|-----------------|--------|
| **Clear match** | 70%+ | Auto-trigger silently |
| **Borderline** | 40-69% | Ask user: "This looks complex—would you like me to use the orchestrator?" |
| **Unclear** | 30-39% | Proceed with direct tools, monitor for blockers |
| **Simple** | <30% | Use direct tools (Read/Edit/Task) |

---

## Examples

### Example Analysis (10+ scenarios)

#### ✅ Should Trigger: High Confidence

**Example 1: Full System Implementation**
```
User: "Implement a complete user authentication system with OAuth (Google, GitHub),
       email verification, password reset, and role-based access control"

Analysis:
- Pattern: "implement .* system" ✓
- Steps: OAuth (1), email verify (2), password reset (3), RBAC (4),
         user model (5), routes (6), middleware (7), tests (8) = 8 steps ✓
- Files: ~15 files (models, routes, middleware, services, tests, config) ✓
- Phases: Implementation implied (1 phase)
- Modifiers: "complete" ✓
Confidence: 90% → AUTO-TRIGGER ✅
```

**Example 2: Architecture Refactor**
```
User: "Refactor our monolith architecture to microservices with API gateway,
       service discovery, and event bus"

Analysis:
- Pattern: "refactor .* architecture" ✓
- Steps: API gateway (1), service split (2-5), discovery (6), event bus (7),
         migration (8), tests (9) = 9+ steps ✓
- Files: 30+ files (all services affected) ✓
- Phases: Planning and implementation implied (2 phases) ✓
- Modifiers: "architecture" suggests large scope ✓
Confidence: 100% → AUTO-TRIGGER ✅
```

**Example 3: Multi-Phase Explicit**
```
User: "First, research Next.js 13 app router patterns. Then design our page structure.
       Finally, implement the new routing system and migrate existing pages."

Analysis:
- Pattern: "implement .* system" (in text) ✓
- Steps: Research (1), design (2), implement routing (3), migrate pages (4-6) = 6 steps ✓
- Files: 15+ pages + layouts ✓
- Phases: Research, design, implementation (3 phases) ✓
- Modifiers: None
Confidence: 85% → AUTO-TRIGGER ✅
```

#### ⚠️ Borderline: Should Ask User

**Example 4: Medium Complexity**
```
User: "Add pagination, filtering, and sorting to our product list API endpoint"

Analysis:
- Pattern: No match
- Steps: Pagination logic (1), filter params (2), sort logic (3),
         update tests (4) = 4 steps (below threshold)
- Files: 2-3 files (route, controller, tests)
- Phases: None explicit
- Modifiers: "add" (not "implement/build/refactor")
Confidence: 35% → ASK USER
Response: "This looks moderately complex with 4 steps across a few files.
           Would you like me to orchestrate this with sub-agents, or handle it directly?"
```

**Example 5: Unclear Scope**
```
User: "Improve our authentication security"

Analysis:
- Pattern: No match ("improve" not "implement/refactor")
- Steps: Unclear (need investigation)
- Files: Unknown
- Phases: None
- Modifiers: None
Confidence: 20% → INVESTIGATE FIRST
Response: "I'll investigate the current auth implementation to determine scope,
           then recommend orchestration if needed."
```

#### ❌ Should NOT Trigger: Low Confidence

**Example 6: Single File Edit**
```
User: "Add email validation to the user signup form"

Analysis:
- Pattern: No match
- Steps: Add validation (1) = 1 step
- Files: 1 file (signup form component)
- Phases: None
- Modifiers: "add" (small scope)
Confidence: 10% → USE DIRECT TOOLS
```

**Example 7: Quick Prototype**
```
User: "Build a quick prototype of a login form"

Analysis:
- Pattern: "build" matches, but "quick prototype" contradicts
- Steps: Create form (1), add fields (2), style (3) = 3 steps
- Files: 1-2 files
- Phases: None
- Modifiers: "quick" (suppresses trigger)
Confidence: 15% → USE DIRECT TOOLS
```

**Example 8: Single Component**
```
User: "Refactor the UserProfile component to use hooks instead of class"

Analysis:
- Pattern: "refactor" matches, but "component" not "architecture/system"
- Steps: Convert to function (1), replace state (2), test (3) = 3 steps
- Files: 1 file + test
- Phases: None
- Modifiers: "component" (small scope)
Confidence: 20% → USE DIRECT TOOLS
```

#### 🔍 Special Cases

**Example 9: Migration (High Trigger Potential)**
```
User: "Migrate our entire codebase from JavaScript to TypeScript"

Analysis:
- Pattern: "migrate .* codebase" ✓
- Steps: Setup TS (1), convert files (2-100+), fix types (101-200+),
         update build (201), tests (202+) = 200+ steps ✓✓✓
- Files: ALL files in codebase ✓✓✓
- Phases: Planning (tsconfig), execution (conversion), review (type checking) ✓
- Modifiers: "entire" ✓
Confidence: 100% → AUTO-TRIGGER ✅ (definitely needs orchestration)
```

**Example 10: Vague but Likely Complex**
```
User: "Set up our backend infrastructure"

Analysis:
- Pattern: No exact match, but "set up" + "infrastructure" suggests system-level
- Steps: Unknown (could be 1 or 20)
- Files: Unknown
- Phases: None explicit
- Modifiers: "infrastructure" (suggests complexity)
Confidence: 40% → ASK USER
Response: "Setting up infrastructure can range from simple to complex.
           Can you clarify what this includes? (database, API, auth, deployment, etc.)"
```

---

## Manual Invocation

### When Users Explicitly Request Orchestration

Even if auto-trigger conditions aren't met, **always activate** when users explicitly request:

| Command/Phrase | Example |
|---------------|---------|
| `/orchestrate` | `/orchestrate implement user settings page` |
| "use orchestrator" | "Use the orchestrator to refactor these 3 files" |
| "orchestrate this workflow" | "Orchestrate this workflow: add caching to our API" |
| "use the multi-agent-workflows skill" | Direct skill name invocation |

### Override for Simpler Tasks

**User preference trumps auto-detection**:
```
User: "Orchestrate this: add a logout button"

Analysis:
- Normally wouldn't trigger (1 step, 1 file)
- But user explicitly requested orchestration
→ ACTIVATE SKILL ✅

Rationale: User may want:
- Practice with orchestration
- Consistency with other workflows
- Persistent state for later extension
```

### Opt-In Pattern

**Recommended response when unsure**:
```
"I can handle this with direct tools (faster for simple tasks) or use
 orchestration (better for complex, multi-phase work).

 This request appears to be [simple/moderate/complex].
 Would you like me to orchestrate it?"
```

---

## Decision Matrix

### Quick Reference Table

Use this table for rapid trigger decisions:

| Characteristic | Direct Tools | Ask User | Auto-Trigger |
|---------------|--------------|----------|--------------|
| **Steps** | 1-2 | 3-4 | 5+ |
| **Files** | 1-2 | 3-9 | 10+ |
| **Phases mentioned** | 0-1 | 1 | 2+ |
| **Pattern match** | No | Partial | Yes |
| **Scope modifiers** | "quick", "simple" | Neutral | "full", "complete", "entire" |
| **Example** | "Add button" | "Add filtering to API" | "Implement full auth system" |

### Decision Flowchart (Text-Based)

```
User Request Received
    |
    ├─ Explicit invocation? (/orchestrate, "use orchestrator")
    │  └─ YES → AUTO-TRIGGER
    │
    ├─ Pattern match? (implement .* system, etc.)
    │  ├─ YES → Confidence +30%
    │  └─ NO → Continue
    │
    ├─ 5+ steps detected?
    │  ├─ YES → Confidence +30%
    │  └─ NO → Confidence -10%
    │
    ├─ 10+ files estimated?
    │  ├─ YES → Confidence +30%
    │  └─ NO → Confidence -10%
    │
    ├─ 2+ phases mentioned?
    │  ├─ YES → Confidence +20%
    │  └─ NO → Continue
    │
    ├─ Scope modifiers?
    │  ├─ "full/complete/entire" → Confidence +10%
    │  └─ "quick/simple/single" → Confidence -20%
    │
    └─ Final Confidence Score:
        ├─ ≥70% → AUTO-TRIGGER
        ├─ 40-69% → ASK USER
        └─ <40% → USE DIRECT TOOLS
```

### Edge Case Guidelines

| Situation | Guideline |
|-----------|-----------|
| **User says "simple" but scope suggests complex** | Ask user to clarify expectations |
| **Pattern match but contradictory modifiers** | Modifiers win (e.g., "quick refactor" → don't trigger) |
| **Uncertain file count** | Ask user for clarification or investigate first |
| **Migration tasks** | Almost always trigger (rarely simple) |
| **First-time user** | Provide explanation when auto-triggering |
| **Nested requests** | Trigger if ANY sub-request meets threshold |

### When to Ask for Clarification

**Always ask when**:
- Confidence score 30-50%
- Scope is ambiguous ("improve our system")
- User intent unclear ("make it better")
- Technical details missing ("set up auth" without specifics)

**Example clarification prompts**:
```
"This could be simple (2-3 files) or complex (10+ files).
 Can you specify which components need changes?"

"I can handle this directly or orchestrate with sub-agents.
 Do you expect this to require planning, research, or multiple phases?"

"This request suggests [X steps]. Does that sound right,
 or am I over/under-estimating scope?"
```

---

## Summary Checklist

Use this checklist when evaluating trigger decisions:

- [ ] Check for explicit invocation (`/orchestrate`, "use orchestrator")
- [ ] Match against trigger patterns (implement/build/refactor/migrate)
- [ ] Count implementation steps (5+ → trigger)
- [ ] Estimate files affected (10+ → trigger)
- [ ] Detect multi-phase keywords (2+ phases → trigger)
- [ ] Identify scope modifiers (full/complete → trigger; quick/simple → suppress)
- [ ] Calculate confidence score
- [ ] Make final decision (auto-trigger / ask user / direct tools)
- [ ] If auto-triggering, explain briefly to user
- [ ] If asking, provide clear options with reasoning

---

**Version History**

- **v1.0.0** (2025-11-24): Initial release with pattern matching, condition detection, examples, and decision matrix
