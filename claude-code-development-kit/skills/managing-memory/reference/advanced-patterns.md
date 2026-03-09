# Advanced Memory Patterns

## Overview

Advanced techniques for organizing and optimizing memory files for complex scenarios.

---

## Pattern 1: Conditional Memory

### Use Case
Different patterns or conventions apply in different contexts (development vs production, different environments, different workflows).

### Implementation

```markdown
# Project Memory

## Environment-Specific Patterns

### Development Environment
When working locally:
- Use mock data from `fixtures/`
- Enable verbose logging
- Hot reload enabled
- Use local database (SQLite)

\`\`\`typescript
const config = {
  apiBase: 'http://localhost:3000',
  logLevel: 'debug',
  enableMocks: true,
};
\`\`\`

### Staging Environment
When deploying to staging:
- Use staging API endpoints
- Moderate logging level
- Feature flags enabled
- Use staging database (PostgreSQL)

\`\`\`typescript
const config = {
  apiBase: 'https://staging-api.example.com',
  logLevel: 'info',
  enableMocks: false,
};
\`\`\`

### Production Environment
When deploying to production:
- Use production API endpoints
- Error logging to external service (Sentry)
- Optimized builds
- All feature flags disabled by default

\`\`\`typescript
const config = {
  apiBase: 'https://api.example.com',
  logLevel: 'error',
  enableMocks: false,
};
\`\`\`
```

### Benefits
- Clear context-specific guidance
- Reduces confusion about which pattern to use when
- Documents environment differences

---

## Pattern 2: Role-Based Memory

### Use Case
Large teams with different roles (frontend, backend, DevOps) need role-specific guidance.

### Implementation

```markdown
# Team Workflows

## Frontend Developers

### Primary Focus
- Components in `src/components/`
- Pages in `src/pages/`
- Styles in `src/styles/`

### Workflow
1. Create component in appropriate directory
2. Add TypeScript types
3. Add unit tests
4. Add to Storybook
5. Use in page

### Resources
- Design system: @docs/design-system.md
- Component patterns: @docs/frontend/component-patterns.md
- Styling guide: @docs/frontend/styling-guide.md

## Backend Developers

### Primary Focus
- API routes in `src/api/`
- Services in `src/services/`
- Database models in `src/models/`

### Workflow
1. Define API endpoint (OpenAPI spec)
2. Implement controller
3. Implement service layer
4. Add database migrations if needed
5. Write integration tests

### Resources
- API standards: @docs/backend/api-standards.md
- Database patterns: @docs/backend/database-patterns.md
- Service architecture: @docs/backend/service-architecture.md

## DevOps / SRE

### Primary Focus
- Infrastructure as Code in `infrastructure/`
- CI/CD pipelines in `.github/workflows/`
- Deployment configs in `deploy/`

### Workflow
1. Make infrastructure changes in Terraform
2. Test in staging environment
3. Update documentation
4. Create deployment PR
5. Monitor rollout

### Resources
- Deployment guide: @docs/devops/deployment.md
- Monitoring: @docs/devops/monitoring.md
- Incident response: @docs/devops/incident-response.md
```

### Benefits
- Each role finds relevant information quickly
- Reduces noise from irrelevant details
- Clear separation of concerns

---

## Pattern 3: Task-Specific Memory

### Use Case
Common tasks have well-defined workflows that should be followed consistently.

### Implementation

```markdown
# Common Tasks

## Adding a New Feature

### Checklist
- [ ] Create feature branch: `feature/TICKET-description`
- [ ] Implement feature
- [ ] Add tests (unit + integration)
- [ ] Update documentation
- [ ] Add feature flag (if applicable)
- [ ] Create PR using template
- [ ] Get code review
- [ ] Merge to main
- [ ] Monitor deployment

### Detailed Steps

1. **Create Branch**
   \`\`\`bash
   git checkout main
   git pull
   git checkout -b feature/TICKET-123-user-profile
   \`\`\`

2. **Implement Feature**
   - Follow architecture patterns in @docs/architecture.md
   - Use existing components when possible
   - Maintain consistency with codebase style

3. **Write Tests**
   - Unit tests for new functions
   - Integration tests for new endpoints
   - E2E tests for user-facing features
   - Target: 80% coverage minimum

4. **Documentation**
   - Update API docs if adding endpoints
   - Update README if changing setup
   - Add inline comments for complex logic

5. **Create PR**
   - Use PR template
   - Include screenshots for UI changes
   - Link to ticket/issue
   - Request reviewers

## Debugging Production Issues

### Immediate Actions
1. Check error tracking (Sentry) for stack traces
2. Review recent deployments
3. Check monitoring dashboards
4. Review logs in CloudWatch

### Workflow
\`\`\`bash
# 1. Reproduce locally if possible
npm run build:production
npm start

# 2. Check logs
aws logs tail /aws/lambda/production --follow

# 3. Check metrics
# Open Datadog dashboard

# 4. Roll back if critical
# Follow incident response guide
\`\`\`

### Resources
- Incident response: @docs/incident-response.md
- Runbook: @docs/runbook.md
- On-call procedures: @docs/oncall.md

## Database Migrations

### Before You Start
- [ ] Backup production database
- [ ] Test migration on copy of production data
- [ ] Plan rollback strategy
- [ ] Schedule maintenance window (if needed)

### Workflow
\`\`\`bash
# 1. Create migration
npx prisma migrate dev --name add_user_roles

# 2. Test locally
npm run test:db

# 3. Review migration SQL
cat prisma/migrations/*_add_user_roles/migration.sql

# 4. Deploy to staging
npm run deploy:staging

# 5. Verify staging
npm run verify:migration

# 6. Deploy to production (during maintenance window)
npm run deploy:production
\`\`\`

### Migration Checklist
- [ ] Both up and down migrations included
- [ ] Idempotent (can run multiple times safely)
- [ ] Handles existing data appropriately
- [ ] Includes proper indexes
- [ ] Tested with production data volume
```

### Benefits
- Reduces errors from forgotten steps
- Ensures consistency across team
- Speeds up common tasks
- Built-in knowledge transfer

---

## Pattern 4: Layered Memory with Imports

### Use Case
Very large projects need to organize memory across many files while keeping the main file scannable.

### Implementation

**Main CLAUDE.md:**
```markdown
# Platform Project

## Quick Reference

- Stack: Node.js, React, PostgreSQL
- Package Manager: pnpm
- Node Version: 20 LTS

## Core Documentation

### Architecture
@docs/architecture/overview.md

### Development Workflows
@docs/workflows/development.md
@docs/workflows/testing.md
@docs/workflows/deployment.md

### Standards and Conventions
@docs/standards/coding.md
@docs/standards/api-design.md
@docs/standards/database.md

### Team Guides
@docs/team/onboarding.md
@docs/team/code-review.md
@docs/team/incident-response.md

## Common Commands

| Command | Purpose |
|---------|---------|
| `pnpm dev` | Start all services |
| `pnpm test` | Run all tests |
| `pnpm build` | Build for production |

## Emergency Contacts

- Tech Lead: @username (Slack)
- On-Call Rotation: Check PagerDuty
- #engineering channel for questions
```

**Supporting files structure:**
```
.claude/
├── CLAUDE.md (main file, ~100 lines)
└── docs/
    ├── architecture/
    │   ├── overview.md
    │   ├── frontend.md
    │   └── backend.md
    ├── workflows/
    │   ├── development.md
    │   ├── testing.md
    │   └── deployment.md
    ├── standards/
    │   ├── coding.md
    │   ├── api-design.md
    │   └── database.md
    └── team/
        ├── onboarding.md
        ├── code-review.md
        └── incident-response.md
```

### Benefits
- Main file stays under 150 lines
- Easy to navigate (clear table of contents)
- Detailed content available when needed
- Easy to maintain (edit specific file)
- Can update sections independently

---

## Pattern 5: Shared Base + Project-Specific Overrides

### Use Case
Monorepo or multi-project setup where some conventions are shared but each project has specifics.

### Implementation

**Shared base (.claude/shared.md):**
```markdown
# Shared Standards

## TypeScript Standards
- Strict mode enabled
- No implicit any
- Explicit return types for exports

## Testing Standards
- Minimum 80% coverage
- Unit tests for all utilities
- Integration tests for APIs

## Git Standards
- Conventional commits
- Branch naming: type/ticket-description
- Squash merge to main
```

**Web app (.claude/CLAUDE.md):**
```markdown
# Web Application

## Shared Standards
@shared.md

## Web-Specific Patterns

### React Conventions
- Functional components only
- Hooks for state management
- Component file structure:
  \`\`\`
  Component/
  ├── Component.tsx
  ├── Component.test.tsx
  ├── Component.module.css
  └── index.ts
  \`\`\`

### State Management
- React Query for server state
- Context for global client state
- Local state with useState
```

**Mobile app (.claude/CLAUDE.md):**
```markdown
# Mobile Application

## Shared Standards
@shared.md

## Mobile-Specific Patterns

### React Native Conventions
- Use StyleSheet.create for styles
- Platform-specific code in .ios.tsx and .android.tsx
- Navigation with React Navigation

### State Management
- Redux Toolkit for global state
- RTK Query for API calls
- Persist state with redux-persist
```

### Benefits
- Shared standards stay in sync
- Project-specific details don't clutter shared base
- Easy to update shared conventions once
- Clear inheritance/override pattern

---

## Pattern 6: Version-Specific Memory

### Use Case
Memory needs to reflect different versions of the project (major refactors, API versions, migration periods).

### Implementation

```markdown
# API Service

## Current Version: v2.0

**Migration Status:** v1 deprecated, v2 current, v3 in development

## Version 2 (Current - Use This)

### Endpoints
- Prefix: `/api/v2/`
- Authentication: JWT in Authorization header
- Response format: JSON:API spec

### Changes from v1
- New authentication mechanism (JWT instead of sessions)
- Standardized error responses
- Pagination required for all list endpoints

## Version 1 (Deprecated - Sunset: 2025-06-01)

Still supported for existing clients but:
- No new features
- Security patches only
- Migrate to v2 ASAP

Migration guide: @docs/migrations/v1-to-v2.md

## Version 3 (In Development)

Preview features:
- GraphQL endpoint at `/graphql`
- WebSocket support
- Batch operations

Development docs: @docs/v3/overview.md
```

### Benefits
- Clear which version to use
- Migration path documented
- Deprecated features clearly marked
- Future direction visible

---

## Pattern 7: Metric-Driven Memory

### Use Case
Performance, quality, or operational metrics that should inform development decisions.

### Implementation

```markdown
# Performance Standards

## Current Metrics (as of 2025-01-15)

### Web Vitals
- LCP: 1.2s (target: <2.5s) ✅
- FID: 45ms (target: <100ms) ✅
- CLS: 0.08 (target: <0.1) ✅

### API Performance
- P50: 120ms
- P95: 450ms
- P99: 1200ms

**Target:** All endpoints under 500ms P95

### Bundle Size
- Main bundle: 245KB (target: <300KB) ✅
- Vendor bundle: 180KB (target: <200KB) ✅

## Performance Requirements

### Images
- Use WebP format
- Maximum size: 500KB
- Lazy load below fold
- Use \`<picture>\` for responsive images

### Code Splitting
- Route-based splitting required
- Component lazy loading for:
  - Modals
  - Admin panels
  - Heavy charts/visualizations

### Lighthouse Scores
Minimum acceptable scores:
- Performance: 90
- Accessibility: 95
- Best Practices: 90
- SEO: 90

CI fails if scores drop below these thresholds.

## Monitoring

Dashboard: https://metrics.example.com/frontend

Review metrics:
- Daily: Team lead
- Weekly: Full team
- Monthly: Stakeholder report
```

### Benefits
- Concrete, measurable standards
- Regular metric reviews
- Performance regressions visible
- Data-driven decisions

---

## Pattern 8: External Resource Integration

### Use Case
Memory references external systems, APIs, or documentation that may change.

### Implementation

```markdown
# External Integrations

## Stripe Payment Integration

### Documentation
- API Reference: https://stripe.com/docs/api
- Webhooks: https://stripe.com/docs/webhooks
- Testing: https://stripe.com/docs/testing

### Our Implementation
- Integration guide: @docs/integrations/stripe.md
- Test mode: Use test keys in `.env.test`
- Webhook endpoint: `/api/webhooks/stripe`

### Test Cards
\`\`\`
Success: 4242 4242 4242 4242
Decline: 4000 0000 0000 0002
Requires authentication: 4000 0025 0000 3155
\`\`\`

### Key Contacts
- Stripe Account Manager: account@stripe.com
- Internal Champion: @jane (Slack)

## AWS Services

### Services We Use
- **S3:** File storage (bucket: `app-uploads-prod`)
- **Lambda:** Serverless functions
- **RDS:** PostgreSQL database
- **CloudFront:** CDN

### Documentation
- Internal AWS guide: @docs/aws/overview.md
- Access management: @docs/aws/iam.md

### Credentials
- Stored in: AWS Secrets Manager
- Access via: IAM roles (no keys in code)
- Rotation: Automatic, every 90 days

## Internal APIs

### User Service
- Base URL: `https://api-internal.example.com/users`
- OpenAPI Spec: @docs/apis/user-service.yaml
- Swagger UI: https://api-internal.example.com/docs

### Notification Service
- Base URL: `https://api-internal.example.com/notifications`
- OpenAPI Spec: @docs/apis/notification-service.yaml
```

### Benefits
- Central reference for external dependencies
- Links stay current
- Credentials managed securely
- Integration guides accessible

---

## Pattern 9: Progressive Memory Evolution

### Use Case
Memory file grows with project - start small, add detail over time.

### Implementation Strategy

**Month 1 (Minimal):**
```markdown
# New Project

## Stack
- React, TypeScript, Node.js

## Commands
\`\`\`bash
npm run dev
npm test
\`\`\`
```

**Month 3 (Growing):**
```markdown
# New Project

## Stack
- React 18, TypeScript 5, Node.js 20
- Vite, Vitest, Playwright

## Commands
\`\`\`bash
npm run dev    # http://localhost:5173
npm test       # Unit tests
npm run e2e    # E2E tests
\`\`\`

## Conventions
- Functional components only
- TypeScript strict mode
- Tests co-located with source
```

**Month 6 (Established):**
```markdown
# New Project

## Stack
@docs/stack.md

## Conventions
@docs/conventions.md

## Workflows
@docs/workflows.md

## Architecture
@docs/architecture.md
```

### Approach
1. Start with basics only
2. Document patterns as they emerge
3. Extract to @path imports when sections grow
4. Continuously refine based on team feedback

### Benefits
- No upfront overhead
- Grows organically with project
- Reflects actual patterns (not theoretical)
- Easy to maintain (evolves naturally)

---

## Pattern 10: Multi-Language Projects

### Use Case
Project uses multiple programming languages with different conventions for each.

### Implementation

```markdown
# Full-Stack Platform

## Project Structure
\`\`\`
platform/
├── frontend/     # TypeScript/React
├── backend/      # Python/FastAPI
├── mobile/       # Kotlin (Android) / Swift (iOS)
└── shared/       # Protocol Buffers
\`\`\`

## Language-Specific Conventions

### TypeScript (Frontend)
@docs/conventions/typescript.md

Quick reference:
- Strict mode enabled
- Functional components
- Props interfaces exported

### Python (Backend)
@docs/conventions/python.md

Quick reference:
- Type hints required
- Black formatting
- pytest for testing

### Kotlin (Android)
@docs/conventions/kotlin.md

Quick reference:
- Material Design 3
- MVVM architecture
- Jetpack Compose

### Swift (iOS)
@docs/conventions/swift.md

Quick reference:
- SwiftUI for UI
- MVVM architecture
- Combine for reactive code

## Cross-Language Standards

### API Contracts
- Protocol Buffers in `shared/proto/`
- Generate clients: `make generate-clients`
- Versioning: Semantic

### Error Handling
All languages use standard error codes:
\`\`\`
1000-1999: Client errors
2000-2999: Server errors
3000-3999: Business logic errors
\`\`\`

### Testing
- Minimum 80% coverage (all languages)
- Integration tests in `tests/integration/`
- Contract tests for API boundaries
```

### Benefits
- Each language gets appropriate conventions
- Cross-language standards enforced
- Clear separation of concerns
- Consistent where it matters

---

## Choosing the Right Pattern

### Questions to Ask

1. **How complex is the project?**
   - Simple → Basic memory
   - Complex → Layered with imports

2. **How large is the team?**
   - Small (1-5) → Simple, single file
   - Medium (5-15) → Role-based sections
   - Large (15+) → Layered, role-based, task-specific

3. **How diverse are the workflows?**
   - Uniform → Single workflow
   - Varied → Task-specific patterns

4. **How much external integration?**
   - Minimal → Brief references
   - Extensive → Dedicated integration pattern

5. **How mature is the project?**
   - New → Progressive evolution
   - Established → Comprehensive documentation

### Pattern Combinations

Many projects benefit from combining patterns:
- **Large monorepo:** Layered + Role-based + Shared base
- **Multi-environment product:** Conditional + Metric-driven
- **Enterprise project:** External resources + Version-specific + Task-specific

Start simple, add patterns as needed.
