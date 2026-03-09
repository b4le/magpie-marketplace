---
name: document-report
purpose: Template for analysis, status, and technical reports
category: document
version: 1.0.0
---

# Report Document Template

A standardized template for creating analysis, status, and technical reports with consistent structure and clear communication.

## Template Structure

```markdown
---
title: {{title}}
type: {{type}}  # analysis | status | technical
date: {{date}}
audience: {{audience}}
author: {{author}}
status: {{status}}  # draft | review | final
---

# {{title}}

## TL;DR / Executive Summary

- {{summary_point_1}}
- {{summary_point_2}}
- {{summary_point_3}}

## Key Findings

1. **{{finding_1_title}}**: {{finding_1_description}}
   - Evidence: {{finding_1_evidence}}
   - Impact: {{finding_1_impact}}

2. **{{finding_2_title}}**: {{finding_2_description}}
   - Evidence: {{finding_2_evidence}}
   - Impact: {{finding_2_impact}}

3. **{{finding_3_title}}**: {{finding_3_description}}
   - Evidence: {{finding_3_evidence}}
   - Impact: {{finding_3_impact}}

## Analysis

### {{analysis_section_1}}

{{analysis_section_1_content}}

**Key observations:**
- {{observation_1}}
- {{observation_2}}
- {{observation_3}}

### {{analysis_section_2}}

{{analysis_section_2_content}}

**Implications:**
- {{implication_1}}
- {{implication_2}}

### {{analysis_section_3}}

{{analysis_section_3_content}}

## Recommendations

### Priority 1: Critical
- **{{recommendation_p1_1}}**: {{recommendation_p1_1_description}}
  - Timeline: {{recommendation_p1_1_timeline}}
  - Owner: {{recommendation_p1_1_owner}}

### Priority 2: High
- **{{recommendation_p2_1}}**: {{recommendation_p2_1_description}}
  - Timeline: {{recommendation_p2_1_timeline}}
  - Owner: {{recommendation_p2_1_owner}}

### Priority 3: Medium
- **{{recommendation_p3_1}}**: {{recommendation_p3_1_description}}
  - Timeline: {{recommendation_p3_1_timeline}}
  - Owner: {{recommendation_p3_1_owner}}

## Data & Evidence

### {{data_section_1}}

| Metric | Current | Target | Delta | Status |
|--------|---------|--------|-------|--------|
| {{metric_1}} | {{metric_1_current}} | {{metric_1_target}} | {{metric_1_delta}} | {{metric_1_status}} |
| {{metric_2}} | {{metric_2_current}} | {{metric_2_target}} | {{metric_2_delta}} | {{metric_2_status}} |
| {{metric_3}} | {{metric_3_current}} | {{metric_3_target}} | {{metric_3_delta}} | {{metric_3_status}} |

### {{data_section_2}}

{{data_section_2_content}}

## Next Steps

**Immediate (0-2 weeks):**
1. {{next_step_immediate_1}}
2. {{next_step_immediate_2}}

**Short-term (2-4 weeks):**
1. {{next_step_short_1}}
2. {{next_step_short_2}}

**Long-term (1-3 months):**
1. {{next_step_long_1}}
2. {{next_step_long_2}}

## Appendix

### A. {{appendix_section_1}}

{{appendix_section_1_content}}

### B. {{appendix_section_2}}

{{appendix_section_2_content}}

### C. References

- {{reference_1}}
- {{reference_2}}
- {{reference_3}}
```

## Format Guidelines

### Lead with Conclusions
- Start with findings and recommendations, not methodology
- Executive summary should be scannable in 30 seconds
- Use the inverted pyramid: most important information first

### Tables for Comparisons
- Use tables for metrics, comparisons, and status tracking
- Include status indicators (on track, at risk, blocked)
- Add delta columns to show change over time

### Code References
- Include file paths and line numbers for technical reports
- Example: `/src/components/Auth.tsx:45-67`
- Use code blocks with syntax highlighting

### Evidence-Based
- Every finding must cite specific evidence
- Link to tickets, PRs, metrics dashboards
- Include timestamps for time-sensitive data

### Actionable Recommendations
- Each recommendation needs owner and timeline
- Prioritize using P1/P2/P3 or similar system
- Include success criteria where applicable

## Usage Examples

**Analysis Report:**
- Performance analysis
- Security audit findings
- Architecture review
- Code quality assessment

**Status Report:**
- Project status updates
- Sprint retrospectives
- Incident post-mortems
- Migration progress

**Technical Report:**
- System design proposals
- Integration assessments
- Dependency audits
- Technical debt analysis
