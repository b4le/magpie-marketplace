---
name: product-brief
purpose: Output style for product briefs targeted at mixed technical and business audiences
category: document
version: 1.0.0
---

# Product Brief Template

## Template Structure

```markdown
---
title: {{title}}
author: {{author}}
date: {{date}}
audience: {{audience}}
status: {{status}}
---

# {{title}}

## Summary

{{summary}}

## Key Points

{{key_points}}

## Recommendations

{{recommendations}}

## Next Steps

{{next_steps}}
```

## Variable Definitions

- `{{title}}`: Name of the product, feature, or initiative
- `{{author}}`: Document author or owning team
- `{{date}}`: Creation date (YYYY-MM-DD)
- `{{audience}}`: Target readers (e.g., "Engineering leads and Product")
- `{{status}}`: Document state (draft / review / approved)
- `{{summary}}`: 2-4 sentences covering the problem, proposed solution, and expected outcome
- `{{key_points}}`: 3-5 bullets capturing the most important context or constraints
- `{{recommendations}}`: Numbered list of actionable proposals in priority order
- `{{next_steps}}`: Short list of concrete actions with owners and target dates

## Formatting Rules

- Summary must be prose, not bullets
- Key Points uses dashes, one point per line
- Recommendations uses numbered list, ordered by priority (highest first)
- Next Steps format: `- [Owner] Action by YYYY-MM-DD`
- Avoid jargon; write for a mixed technical and business audience
- Maximum 400 words for the full document

## Example Output

```markdown
---
title: Offline Playback for Free Tier Users
author: Consumer Product Team
date: 2025-11-15
audience: Engineering leads and Product stakeholders
status: draft
---

# Offline Playback for Free Tier Users

## Summary

Free tier users currently cannot download content for offline listening, creating
friction for users in low-connectivity regions and driving churn to competitors.
This brief proposes a time-limited offline cache (24-hour window, 10 tracks) gated
behind ad engagement, enabling offline access without undermining premium conversion.

## Key Points

- Competitor analysis shows three of five top streaming apps offer limited offline access on free plans
- Internal surveys indicate 34% of churned free users cite offline access as a primary reason for leaving
- Ad-gated model tested in two markets showed no statistically significant impact on premium conversion
- Implementation requires changes to the download service, DRM layer, and cache eviction logic
- Legal review of license agreements is required before any external announcement

## Recommendations

1. Proceed with a limited pilot in two markets with highest mobile-only usage (Brazil, India)
2. Gate offline cache on completion of one pre-roll ad per download session
3. Set cache window to 24 hours with a maximum of 10 tracks to preserve premium differentiation
4. Instrument all cache events for conversion funnel analysis before broader rollout

## Next Steps

- [DRM Engineering] Confirm license terms allow offline caching for free tier by 2025-12-01
- [Product] Define success metrics and baseline conversion rates by 2025-12-05
- [Data] Instrument offline playback events in analytics pipeline by 2025-12-10
- [Legal] Complete license review and provide written clearance by 2025-12-15
```
