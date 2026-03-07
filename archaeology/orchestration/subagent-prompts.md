---
generated: 2026-02-26
project: .claude
pattern_types: [subagent]
source_count: 40
---

# Subagent Prompts

Verbatim prompts extracted from successful subagent invocations.

## Pattern: Role-Based Content Pipeline

### Analyst Role
```yaml
subagent_type: "general-purpose"
description: "Analyst - catalog sensitive links"
```

**Prompt:**
```yaml
You are the ANALYST on a team creating case study pages.

Analyze the index.html playground file and catalog:
1. ALL Sources sections with external links
2. ALL references to internal systems or tools
3. ALL mentions of specific teams or individuals
4. ALL data points that could identify the organization

Output: JSON inventory of findings with line numbers and sensitivity rating (HIGH/MEDIUM/LOW)
```

### Content Creator Role
```yaml
subagent_type: "general-purpose"
description: "Content creator - build case studies"
```

**Prompt:**
```bash
You are the CONTENT CREATOR on a team creating case study pages.

Wait for Analyst findings before proceeding.

Create standalone HTML case study pages from the inventory:
1. Use the playground template structure
2. Replace sensitive items per the redaction map
3. Maintain narrative flow while anonymizing
4. Add [REDACTED] markers for items needing review

Output: Complete HTML files ready for review
```

### Security Reviewer Role
```bash
subagent_type: "general-purpose"
description: "Security reviewer - check for leaks"
```

**Prompt:**
```bash
You are the SECURITY REVIEWER on a team creating case study pages.

Review ALL output from Content Creator and ensure:
1. NO sensitive information is leaked
2. NO internal URLs remain
3. NO team or individual names appear
4. NO proprietary system names are exposed

Output: Security report with PASS/FAIL per file and specific line citations for failures
```

### Content Editor Role
```yaml
subagent_type: "general-purpose"
description: "Content editor - add Spotify context"
```

**Prompt:**
```bash
You are the CONTENT EDITOR on a team creating case study pages.

Current content is OVER-ANONYMIZED. Your audience: Engineers and PMs in Spotify's Content Platform.

Add appropriate internal context:
1. Reference internal tools by name where safe
2. Add links to internal docs where helpful
3. Restore team names that are public knowledge
4. Maintain security boundaries

Output: Edited HTML files with tracked changes
```

---

## Pattern: Parallel Domain Expert Reviews

### Frontend Developer Audit
```yaml
subagent_type: "application-performance:frontend-developer"
description: "Frontend audit of case study template"
```

**Prompt:**
```bash
Audit the case study HTML template for:
1. Accessibility (WCAG 2.1 AA compliance)
2. Responsive design (mobile/tablet/desktop)
3. Performance (asset loading, CSS efficiency)
4. Browser compatibility (Chrome, Safari, Firefox)

Provide specific line-level recommendations with severity ratings.
```

### Prompt Engineer Review
```yaml
subagent_type: "llm-application-dev:prompt-engineer"
description: "Content strategy review of case study"
```

**Prompt:**
```bash
Review the case study content for:
1. Narrative clarity and flow
2. Technical accuracy of AI/LLM descriptions
3. Appropriate level of detail for target audience
4. Consistency of terminology across sections

Provide editorial recommendations with rationale.
```

### Claude Code Expert Review
```yaml
subagent_type: "claude-code-guide"
description: "Claude Code expert review"
```

**Prompt:**
```bash
Review the case study for Claude Code best practices:
1. Tool usage patterns described accurately
2. Subagent/team patterns correctly explained
3. No deprecated features referenced
4. Alignment with current Claude Code capabilities

Flag any inaccuracies with corrections.
```

---

## Pattern: Evidence Verification

### Claim Verification
```yaml
subagent_type: "Explore"
description: "Verify reuse claim against findings"
```

**Prompt:**
```bash
Analyze the findings data in .development/findings/ to verify this claim:

"The same two-phase parallel research approach was later reused for CoCaM delivery planning, compliance audits, and cross-squad dependency analysis"

Search for:
1. Evidence of the two-phase pattern
2. Instances where it was applied to other domains
3. Variations or adaptations of the pattern

Output: Verification status (CONFIRMED/UNCONFIRMED/PARTIAL) with citations
```

### Origin Tracing
```yaml
subagent_type: "Explore"
description: "Trace Collaborative System Build origin"
```

**Prompt:**
```bash
Analyze the findings data to identify:

What is "Collaborative System Build" (Case Study 02) actually based on?

Search for:
1. Original project or initiative
2. Key participants
3. Timeline of events
4. Deliverables produced

Output: Source documentation with file paths and relevant excerpts
```

---

## Pattern: Parallel Research Agents

### Multi-Source Research
```bash
# Launch 3 agents in parallel (single message, multiple Task calls)

Agent 1:
  subagent_type: "Explore"
  description: "Research Plugin Workshop orchestration patterns"

Agent 2:
  subagent_type: "Explore"
  description: "Research Miyazaki TS→Go orchestration patterns"

Agent 3:
  subagent_type: "Explore"
  description: "Research animation-studio team patterns"
```

**Common Prompt Structure:**
```bash
Search ~/.claude/projects/ for orchestration patterns in [PROJECT_NAME].

Extract:
1. Task tool invocations with parameters
2. Subagent types used
3. Coordination mechanisms
4. Success/failure outcomes

Output: Structured findings with file:line citations
```

---

## Pattern: Legal System Design Review

### Innovative UX Designer
```yaml
subagent_type: "general-purpose"
description: "UX Designer - Innovative perspective"
```

**Prompt:**
```bash
You are an INNOVATIVE UX/UI DESIGNER with an experimental mindset.

Project Context: We're building a legal advice system for employees (prioritizing Sweden and UK).

Your Task: Explore and document innovative UX approaches for this system. Consider:

1. Input Experience - How might we reimagine gathering the user's situation?
2. Report Interactivity Model - How can the report be more than a static document?
3. Context Expansion - How do users add more context mid-report?
4. Innovative Ideas - What cutting-edge patterns could we apply?

Output: Design explorations with mockup descriptions and rationale
```

---

## Anti-Patterns

**DO NOT:**
- Use vague prompts ("help with this")
- Skip role identity establishment
- Omit output format specifications
- Launch dependent tasks in parallel
- Use `run_in_background: true` for coordinated work

**DO:**
- Establish clear role identity
- Specify exact output format
- Include success criteria
- Use `run_in_background: false` for blocking execution
- Launch independent tasks in parallel with multiple Task calls
