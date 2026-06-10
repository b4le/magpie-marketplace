# Team Roles Reference

Common roles for agent teams. Use these as starting points—adapt based on project needs.

## Role Overview

| Role | Agent Type | Best For |
|------|------------|----------|
| Team Lead | main thread | Coordination, task assignment, user communication |
| Researcher | `Explore` | Investigation, documentation, codebase analysis |
| Architect | `Plan` | System design, technical decisions, architecture |
| Engineer | general-purpose | Implementation, building features |
| Reviewer | general-purpose | Validation, testing, quality checks |
| PM | general-purpose | Requirements, coordination, user-facing docs |
| Analyst | general-purpose | Data analysis, pattern finding |
| Writer | general-purpose | Documentation, synthesis, reports |

## Role Descriptions

### Team Lead

**When to use:** Always present—the Team Lead is the main Claude thread, not a spawned agent.

**Agent type:** main thread (not spawned)

**Responsibilities:**
- Create teams and spawn agents
- Assign tasks and manage dependencies
- Monitor progress via TaskList
- Communicate with the user
- Coordinate phase transitions
- Handle blockers and escalations
- Update state files (README.md, workflow-state.yaml)
- Shut down agents and clean up teams when complete

**Key pattern:** The Team Lead orchestrates but doesn't do implementation work directly. Delegate to specialized agents and synthesize their outputs.

### Researcher

**When to use:** Investigating existing systems, gathering information, exploring codebases.

**Agent type:** `Explore`

**Example prompt:**
```
Research the authentication implementation in this codebase.

Requirements:
1. Find all auth-related files (middleware, routes, models)
2. Identify the auth strategy (JWT, sessions, OAuth)
3. Document the authentication flow step-by-step
4. Note any security concerns

Output:
- Summary of findings in outputs/auth-research.md
- Include file paths and line numbers for key code
```

### Architect

**When to use:** Making design decisions, planning system structure, defining interfaces.

**Agent type:** `Plan`

**Example prompt:**
```
Design the architecture for user data export feature.

Requirements:
1. Review existing export patterns in codebase
2. Define data flow from request to file generation
3. Specify interfaces between components
4. Document scalability considerations

Output:
- Architecture document in outputs/export-architecture.md
- Include diagrams (ASCII/Mermaid)
- List key decisions with rationale
```

### Engineer

**When to use:** Building features, implementing designs, writing code.

**Agent type:** general-purpose

**Example prompt:**
```
Implement the PDF export service based on architecture doc.

Requirements:
1. Read outputs/export-architecture.md for design
2. Create service following existing patterns
3. Add appropriate error handling
4. Include unit tests

Output:
- Implementation files in project
- Summary of changes in outputs/implementation-summary.md
```

### Reviewer

**When to use:** Validating work, testing functionality, quality checks.

**Agent type:** general-purpose

**Example prompt:**
```
Review the PDF export implementation.

Requirements:
1. Check code against architecture document
2. Verify error handling is comprehensive
3. Run tests and report results
4. Identify any security concerns

Output:
- Review findings in outputs/review-findings.md
- List of issues (if any) with severity
- Recommendations for improvement
```

### PM (Product Manager)

**When to use:** Gathering requirements, writing specs, coordinating work.

**Agent type:** general-purpose

**Example prompt:**
```
Create requirements document for user export feature.

Requirements:
1. Research similar features in competitor products
2. Define user stories with acceptance criteria
3. Identify edge cases and constraints
4. Prioritize features for MVP vs future

Output:
- Requirements doc in outputs/requirements.md
- User stories in standard format
```

### Analyst

**When to use:** Processing data, finding patterns, analyzing results.

**Agent type:** general-purpose

**Example prompt:**
```
Analyze error patterns in application logs.

Requirements:
1. Parse log files for error messages
2. Categorize by type and frequency
3. Identify root causes where possible
4. Recommend fixes by priority

Output:
- Analysis report in outputs/error-analysis.md
- Prioritized list of issues to address
```

### Writer

**When to use:** Creating documentation, synthesizing information, writing reports.

**Agent type:** general-purpose

**Example prompt:**
```
Create user documentation for export feature.

Requirements:
1. Review implementation and test results
2. Write step-by-step user guide
3. Document error messages and solutions
4. Include screenshots or examples

Output:
- User guide in outputs/export-user-guide.md
- FAQ section for common issues
```

## Role Combinations by Project Type

### Engineering Project

| Phase | Roles | Parallel? |
|-------|-------|-----------|
| Planning | Researcher, Architect | Yes |
| Execution | Engineers (2-3) | Yes |
| Review | Reviewer | No |

### Research Project

| Phase | Roles | Parallel? |
|-------|-------|-----------|
| Research | Researchers (2-3) | Yes |
| Analysis | Analyst | No |
| Synthesis | Writer | No |
| Recommendations | PM | No |

### Creative Project

| Phase | Roles | Parallel? |
|-------|-------|-----------|
| Exploration | Researcher | No |
| Ideation | Multiple brainstormers | Yes |
| Refinement | Reviewer | No |
| Production | Writer/Engineer | No |

## Adapting Roles

Roles are suggestions, not requirements. Adapt based on:

- **Project complexity:** Small projects need fewer roles
- **Domain expertise:** Combine roles that overlap
- **Parallelism:** Split roles that can work independently
- **User preference:** Honor explicit role requests

**Example adaptation:**
User says: "I just need someone to research and implement"
→ Use 1 Researcher (Explore) + 1 Engineer (general-purpose)
