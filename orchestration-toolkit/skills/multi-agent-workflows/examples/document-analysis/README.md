# Document Analysis Workflow Example

This example demonstrates using multi-agent workflows for **non-engineering tasks** like document analysis, research synthesis, and report generation.

## Use Case

Analyzing a large set of documents (reports, proposals, strategy docs) to extract insights and produce a synthesis.

## Workflow Structure

```
/orchestrate --think doc-review-q4

Phases: research → analysis → synthesis → recommendations
```

## Phase Breakdown

### Phase 1: Collection (Research)

**Goal:** Gather and organize source materials

**Agent prompt example:**
```
You are working in workflow: doc-review-q4
Phase: research

Task:
1. Read all documents in /source-docs/
2. Create an inventory of documents with metadata
3. Identify key themes and topics across documents
4. Output: research/document-inventory.md

Save output to: .development/workflows/doc-review-q4/active/research/
```

**Expected outputs:**
- `document-inventory.md` - List of all documents with summaries
- `themes.md` - Initial theme identification

### Phase 2: Extraction (Analysis)

**Goal:** Deep analysis of each document

**Agent prompt example:**
```
You are working in workflow: doc-review-q4
Phase: analysis

Context: Read research/document-inventory.md for document list

Task:
1. For each key document, extract:
   - Main arguments
   - Supporting evidence
   - Gaps or contradictions
2. Create analysis files per document
3. Output: analysis/document-{name}.md

Save output to: .development/workflows/doc-review-q4/active/analysis/
```

**Expected outputs:**
- `document-{name}.md` - Per-document analysis
- `cross-references.md` - Connections between documents

### Phase 3: Synthesis

**Goal:** Combine findings into coherent narrative

**Agent prompt example:**
```
You are working in workflow: doc-review-q4
Phase: synthesis

Context:
- Read all files in research/
- Read all files in analysis/

Task:
1. Synthesize findings across all documents
2. Identify patterns, trends, contradictions
3. Create unified narrative
4. Output: synthesis/findings.md

Save output to: .development/workflows/doc-review-q4/active/synthesis/
```

**Expected outputs:**
- `findings.md` - Synthesized findings
- `key-insights.md` - Top 5-10 insights

### Phase 4: Recommendations

**Goal:** Actionable recommendations based on analysis

**Agent prompt example:**
```
You are working in workflow: doc-review-q4
Phase: recommendations

Context: Read synthesis/findings.md

Task:
1. Based on synthesis, generate recommendations
2. Prioritize by impact and feasibility
3. Identify risks and mitigations
4. Output: recommendations/final-report.md

Save output to: .development/workflows/doc-review-q4/active/recommendations/
```

**Expected outputs:**
- `final-report.md` - Complete analysis report
- `action-items.md` - Prioritized next steps

## Workflow State Example

```yaml
workflow_id: doc-review-q4
type: thinking
created: 2025-12-06T10:00:00Z
status: in-progress

current_phase: analysis
phases:
  - name: research
    status: completed
  - name: analysis
    status: in-progress
  - name: synthesis
    status: pending
  - name: recommendations
    status: pending

agents:
  - id: research-agent-001
    phase: research
    status: completed
    output: research/document-inventory.md
  - id: analysis-agent-001
    phase: analysis
    status: in-progress

decisions:
  - date: 2025-12-06
    decision: Focus on Q4 strategy docs only
    rationale: Scope management
    phase: research
```

## Composing with Iterative Refinement

If you need approval gates (e.g., user reviews synthesis before recommendations):

```
Phase: synthesis
Use iterative-agent-refinement pattern:
1. Agent creates draft synthesis
2. PAUSE - present to user for review
3. User provides feedback
4. RESUME - agent refines based on feedback
5. Continue to recommendations phase
```

## Key Differences from Engineering Workflows

| Aspect | Engineering | Document Analysis |
|--------|-------------|-------------------|
| Phases | planning, execution, review | collection, extraction, synthesis, recommendations |
| Outputs | Code, tests | Documents, reports |
| Success criteria | Tests pass | Insights actionable |
| Tools | Bash, Edit, Write | Read, Write, AskUserQuestion |
