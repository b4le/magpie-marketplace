---
name: document-brief
purpose: Template for product/project briefs
category: document
version: 1.0.0
---

# Product/Project Brief Template

## Template Structure

```markdown
---
title: {{title}}
author: {{author}}
date: {{date}}
status: {{status}}
---

# {{title}}

## Executive Summary

{{executive_summary}}

## Problem Statement

{{problem}}

## Proposed Solution

{{solution}}

## Success Metrics

{{metrics}}

## Scope

### In Scope
{{in_scope}}

### Out of Scope
{{out_of_scope}}

## Timeline

{{timeline}}

## Risks & Mitigations

{{risks}}

## Dependencies

{{dependencies}}

## Open Questions

{{open_questions}}
```

## Variable Definitions

- `{{title}}`: Project or product name
- `{{author}}`: Document author(s)
- `{{date}}`: Creation date (YYYY-MM-DD)
- `{{status}}`: Document status (draft/review/approved)
- `{{executive_summary}}`: 2-3 sentence high-level overview
- `{{problem}}`: Clear description of the problem being solved
- `{{solution}}`: High-level approach to solving the problem
- `{{metrics}}`: Measurable success criteria
- `{{in_scope}}`: What will be delivered
- `{{out_of_scope}}`: What explicitly won't be delivered
- `{{timeline}}`: Key phases and milestones
- `{{risks}}`: Top 3 risks with mitigation strategies
- `{{dependencies}}`: External blockers or requirements
- `{{open_questions}}`: Unresolved items requiring decisions

## Example Output

```markdown
---
title: Content Moderation Automation
author: Product Team
date: 2025-12-06
status: draft
---

# Content Moderation Automation

## Executive Summary

Implement automated content moderation to reduce manual review time by 60% while maintaining accuracy above 95%. This will enable the moderation team to focus on complex edge cases and improve overall platform safety response times.

## Problem Statement

Our moderation team manually reviews 100K+ pieces of content daily, leading to:
- 24-48 hour response times for policy violations
- Moderator burnout from repetitive tasks
- Inconsistent application of community guidelines
- Inability to scale with platform growth

## Proposed Solution

Deploy ML-based content classification system that:
- Automatically approves/rejects clear-cut cases (estimated 60% of volume)
- Flags edge cases for human review with context
- Learns from moderator decisions to improve accuracy
- Integrates with existing moderation dashboard

## Success Metrics

- **Primary**: Reduce manual review volume by 60% within 3 months
- **Quality**: Maintain 95%+ accuracy on auto-decisions (measured via spot checks)
- **Speed**: Average policy violation response time under 6 hours
- **Adoption**: 90%+ moderator satisfaction with flagged context quality

## Scope

### In Scope
- Text content classification (comments, posts, bios)
- Integration with existing moderation queue
- Moderator feedback loop for model improvement
- Dashboard analytics for auto-moderation metrics

### Out of Scope
- Image/video content moderation (Phase 2)
- Appeal workflow automation
- Third-party moderation service integration
- Historical content re-classification

## Timeline

- **Phase 1 (Weeks 1-4)**: Model training and validation
- **Phase 2 (Weeks 5-8)**: Integration with moderation dashboard
- **Phase 3 (Weeks 9-12)**: Pilot with 10% traffic, iterate on feedback
- **Phase 4 (Weeks 13-16)**: Full rollout and optimization

## Risks & Mitigations

1. **Risk**: Model bias leading to unfair moderation
   - **Mitigation**: Diverse training data, bias testing framework, human oversight on all auto-rejections for first month

2. **Risk**: Moderators resist adoption due to trust issues
   - **Mitigation**: Transparent accuracy metrics, opt-in pilot phase, regular feedback sessions

3. **Risk**: Edge cases slip through causing PR incidents
   - **Mitigation**: Conservative auto-approval thresholds, escalation path for user appeals, 24/7 on-call coverage

## Dependencies

- ML infrastructure team for model deployment pipeline
- Legal review of auto-moderation decision logging
- Data team for training dataset preparation
- Engineering bandwidth for dashboard integration

## Open Questions

- What confidence threshold should trigger auto-approval vs. human review?
- Should we auto-approve or only auto-reject initially?
- How do we handle appeals of automated decisions?
- What's the rollback plan if accuracy drops below 90%?
```
