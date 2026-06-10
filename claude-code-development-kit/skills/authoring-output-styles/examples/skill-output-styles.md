# Skill Output Styles: Examples

This document provides concrete, copy-paste ready examples of output styles for different skill response types. Each style includes its purpose, structure, sample output, and when to use it.

---

## 1. Code Review Style

### Purpose
Structured code review output that provides actionable feedback with clear severity levels and specific recommendations.

### Structure
- **Summary**: High-level overview of changes reviewed
- **Issues Found**: Categorized by severity (Critical/High/Medium/Low)
- **Recommendations**: Specific improvements with code examples
- **Files Reviewed**: Complete list with line counts

### When to Use
- Pull request reviews
- Code quality assessments
- Security audits
- Architecture reviews

### Sample Output

```markdown
## Code Review Summary

Reviewed authentication refactor in PR #423. Overall structure is solid, but identified 2 critical security issues and 3 medium-priority improvements needed before merge.

**Stats**: 8 files changed, 847 additions, 312 deletions

---

## Issues Found

### Critical Severity

**[C-1] Password stored in plaintext in logs**
- File: `/src/auth/login.ts:45-47`
- Issue: User password logged during authentication failure
- Code:
  ```typescript
  logger.error(`Auth failed for ${email} with password ${password}`);
  ```
- Fix: Remove password from logs entirely
  ```typescript
  logger.error(`Auth failed for ${email}`);
  ```

**[C-2] SQL injection vulnerability in user lookup**
- File: `/src/auth/user-repository.ts:78`
- Issue: Raw string concatenation in query
- Code:
  ```typescript
  const query = `SELECT * FROM users WHERE email = '${email}'`;
  ```
- Fix: Use parameterized queries
  ```typescript
  const query = 'SELECT * FROM users WHERE email = ?';
  db.execute(query, [email]);
  ```

### Medium Severity

**[M-1] Missing rate limiting on login endpoint**
- File: `/src/routes/auth.ts:23`
- Impact: Vulnerable to brute force attacks
- Recommendation: Add express-rate-limit middleware

**[M-2] JWT tokens never expire**
- File: `/src/auth/token.ts:12`
- Issue: `expiresIn` not set in jwt.sign()
- Recommendation: Set 15-minute expiration with refresh token pattern

**[M-3] Error messages leak user existence**
- File: `/src/auth/login.ts:52-56`
- Issue: Different messages for "user not found" vs "wrong password"
- Fix: Use generic "Invalid credentials" for both cases

---

## Recommendations

### 1. Implement Refresh Token Pattern
Current implementation uses long-lived JWT tokens. Recommend:
- Short-lived access tokens (15 min)
- Refresh tokens stored in httpOnly cookies
- Token rotation on refresh

### 2. Add Request Validation
Missing input validation on auth endpoints:
```typescript
import { z } from 'zod';

const loginSchema = z.object({
  email: z.string().email().max(255),
  password: z.string().min(8).max(128)
});
```

### 3. Enhance Security Headers
Add helmet.js middleware for security headers:
```typescript
app.use(helmet({
  contentSecurityPolicy: true,
  hsts: { maxAge: 31536000 }
}));
```

---

## Files Reviewed

- `/src/auth/login.ts` (156 lines)
- `/src/auth/user-repository.ts` (234 lines)
- `/src/auth/token.ts` (89 lines)
- `/src/routes/auth.ts` (178 lines)
- `/src/middleware/auth-middleware.ts` (67 lines)
- `/src/types/auth.types.ts` (34 lines)
- `/tests/auth/login.test.ts` (312 lines)
- `/tests/auth/token.test.ts` (145 lines)

---

## Approval Status

**Blocked** - Address critical issues C-1 and C-2 before merge.
Medium-priority issues can be addressed in follow-up PR if needed.
```

---

## 2. Analysis Summary Style

### Purpose
Research and analysis results with quantitative metrics, clear insights, and actionable conclusions.

### Structure
- **Key Insights**: Top 3-5 findings
- **Data Points**: Quantitative metrics and measurements
- **Methodology**: How analysis was conducted
- **Conclusions**: Actionable recommendations based on data

### When to Use
- Performance analysis
- Codebase audits
- Dependency reviews
- Architecture assessments

### Sample Output

```markdown
## Performance Analysis: API Response Times

Analysis of production API performance over 7-day period (Nov 29 - Dec 5, 2025) across 2.4M requests.

---

## Key Insights

1. **Database queries are the primary bottleneck** - 78% of request time spent in DB layer, with top 3 slow queries accounting for 45% of total latency

2. **/api/users/search endpoint is critically slow** - p95 response time of 3.2s, 12x slower than other endpoints; causes 67% of user-reported timeouts

3. **N+1 query pattern in user dashboard** - Each dashboard load triggers 15-30 separate DB queries; could be reduced to 2 queries with proper joins

4. **Redis cache hit rate is low** - Only 23% cache hits vs 85% target; cache TTLs too short and invalidation too aggressive

5. **No query result pagination** - Endpoints return full datasets; /api/posts endpoint averages 450 records per request (should be max 50)

---

## Data Points

### Response Times (p50/p95/p99)
- `/api/users/search`: 890ms / 3,200ms / 5,800ms
- `/api/posts`: 340ms / 1,200ms / 2,100ms
- `/api/dashboard`: 520ms / 1,800ms / 3,400ms
- `/api/profile`: 120ms / 340ms / 680ms

### Database Metrics
- Average query time: 245ms
- Slow query count (>1s): 23,450 (0.97% of total)
- Top slow query: `getUserWithPosts` - 1,840ms average
- Connection pool saturation: 78% average, 95% peak
- N+1 query occurrences: 8,900 requests

### Cache Performance
- Redis hit rate: 23%
- Average cache lookup time: 8ms
- Cache memory usage: 2.1GB / 8GB
- Evictions per hour: 340
- Most cached keys: session data (45%), user profiles (32%)

### Error Rates
- 504 Gateway Timeout: 0.8% of requests
- 500 Internal Server Error: 0.2% of requests
- Database connection errors: 34 occurrences
- Peak error rate: 2.1% during 2pm-3pm EST

---

## Methodology

### Data Collection
- APM: New Relic distributed tracing (7-day window)
- Database: PostgreSQL slow query log + pg_stat_statements
- Cache: Redis slowlog + INFO stats
- Application: Custom performance middleware with request/response timing

### Analysis Approach
1. Identified endpoints with p95 > 1s as critical
2. Traced slow requests to isolate bottleneck layers
3. Analyzed slow query logs for patterns
4. Correlated cache misses with DB load spikes
5. Reviewed code for common anti-patterns (N+1, missing indexes)

### Environment
- Production cluster: 6 Node.js instances (v20.10)
- Database: PostgreSQL 15.3 (8 vCPU, 32GB RAM)
- Cache: Redis 7.2 (4GB memory limit)
- Load: ~14K requests/hour average, 28K peak

---

## Conclusions

### Immediate Actions (High Impact, Low Effort)
1. **Add pagination to /api/posts endpoint**
   - Expected impact: 60% reduction in response time
   - Implementation: 2 hours

2. **Fix N+1 queries in dashboard**
   - File: `/src/controllers/dashboard.ts`
   - Replace 15-30 queries with 2 JOIN queries
   - Expected impact: 70% faster dashboard loads
   - Implementation: 4 hours

3. **Increase Redis cache TTLs**
   - Increase user profile TTL: 5min → 30min
   - Increase post list TTL: 2min → 15min
   - Expected cache hit rate: 23% → 65%
   - Implementation: 30 minutes

### Medium-Term Actions (High Impact, Medium Effort)
4. **Optimize /api/users/search query**
   - Add full-text search index on users.name
   - Implement query result caching
   - Expected impact: 3.2s → 400ms p95
   - Implementation: 1 day

5. **Implement database connection pooling adjustments**
   - Increase pool size: 20 → 35 connections
   - Add connection timeout monitoring
   - Implementation: 2 hours

### Long-Term Recommendations
6. Consider read replicas for dashboard queries
7. Evaluate GraphQL DataLoader pattern for batching
8. Implement query result streaming for large datasets

---

## Next Steps

1. Create tickets for immediate actions (target: complete by Dec 13)
2. Schedule performance testing session after fixes deployed
3. Set up automated alerting for p95 > 1s on any endpoint
4. Review findings with backend team in weekly sync
```

---

## 3. Error Report Style

### Purpose
Comprehensive error documentation that captures root cause, impact, resolution, and prevention strategies.

### Structure
- **Error Summary**: What happened and when
- **Root Cause**: Why it happened (technical details)
- **Impact**: Who/what was affected
- **Resolution Steps**: How it was fixed
- **Prevention**: How to avoid recurrence

### When to Use
- Bug investigation reports
- Incident postmortems
- Production issue documentation
- Debugging summaries

### Sample Output

```markdown
## Error Report: Database Connection Pool Exhaustion

**Date**: December 5, 2025, 14:23 UTC
**Duration**: 12 minutes
**Severity**: Critical
**Status**: Resolved

---

## Error Summary

Production API experienced complete outage from 14:23-14:35 UTC. All requests returned 500 errors with message "Cannot acquire database connection". Monitoring showed 100% connection pool saturation and 2,847 queued requests at peak.

### Timeline
- **14:23 UTC**: First connection timeout errors appear
- **14:24 UTC**: Error rate reaches 15%, PagerDuty alert fires
- **14:25 UTC**: Connection pool fully saturated (50/50 connections in use)
- **14:26 UTC**: Team begins investigation
- **14:30 UTC**: Root cause identified (leaked connections)
- **14:32 UTC**: Emergency fix deployed
- **14:35 UTC**: Service fully recovered, error rate back to 0%

---

## Root Cause

### Technical Analysis

**Primary Cause**: Connection leak in `/src/repositories/user-repository.ts`

The `getUserActivity()` method acquired a database connection but failed to release it when an error occurred:

```typescript
// BEFORE (buggy code)
async getUserActivity(userId: string) {
  const connection = await pool.getConnection();

  try {
    const activities = await connection.query(
      'SELECT * FROM activities WHERE user_id = ?',
      [userId]
    );

    // Process activities
    const processed = this.processActivities(activities);
    connection.release();  // ← Only released on success path

    return processed;
  } catch (error) {
    logger.error('Failed to get user activity', error);
    throw error;  // ← Connection leaked on error path
  }
}
```

**Trigger**: Malformed user IDs in activity requests caused SQL errors, triggering the error path. Over time, leaked connections accumulated until pool exhausted.

**Contributing Factor**: Connection pool size (50) too small for production traffic (14K req/hour). Masked the leak until recent traffic spike (+40% from marketing campaign).

### Evidence
- Database logs: 2,340 connections opened, only 1,893 closed in 10-min window
- APM traces: getUserActivity() average duration 15s (normally 200ms)
- Code review: connection.release() missing in 4 error handling paths

---

## Impact

### Affected Services
- **API**: 100% of requests failed for 12 minutes
- **Web Application**: Unable to load user dashboards, login succeeded but data fetch failed
- **Mobile App**: Displayed "Service temporarily unavailable" error

### User Impact
- **Total users affected**: ~3,200 (based on failed request count)
- **Active sessions interrupted**: 847
- **Failed login attempts**: 234
- **Customer support tickets**: 12 (increase from baseline of 0-2/hour)

### Business Impact
- **Estimated revenue loss**: $4,300 (based on avg transaction value × failed checkout attempts)
- **SLA breach**: 99.9% uptime target violated (11 minutes of allowed downtime used)

---

## Resolution Steps

### Immediate Fix (Deployed 14:32 UTC)

Fixed connection leak by ensuring release in finally block:

```typescript
// AFTER (fixed code)
async getUserActivity(userId: string) {
  const connection = await pool.getConnection();

  try {
    const activities = await connection.query(
      'SELECT * FROM activities WHERE user_id = ?',
      [userId]
    );

    const processed = this.processActivities(activities);
    return processed;
  } catch (error) {
    logger.error('Failed to get user activity', error);
    throw error;
  } finally {
    connection.release();  // ← Always released
  }
}
```

**Files Changed**:
- `/src/repositories/user-repository.ts` (3 methods fixed)
- `/src/repositories/post-repository.ts` (1 method fixed)
- `/src/repositories/comment-repository.ts` (2 methods fixed)

### Additional Actions Taken
1. Restarted API servers to clear connection backlog
2. Increased connection pool size: 50 → 100 (temporary mitigation)
3. Added connection leak detection logging
4. Reviewed all repository files for similar patterns

---

## Prevention

### Code-Level Prevention

**1. Implement Connection Wrapper**

Created utility to enforce connection cleanup:

```typescript
// /src/utils/db-connection.ts
export async function withConnection<T>(
  callback: (connection: PoolConnection) => Promise<T>
): Promise<T> {
  const connection = await pool.getConnection();
  try {
    return await callback(connection);
  } finally {
    connection.release();
  }
}

// Usage
async getUserActivity(userId: string) {
  return withConnection(async (connection) => {
    const activities = await connection.query(
      'SELECT * FROM activities WHERE user_id = ?',
      [userId]
    );
    return this.processActivities(activities);
  });
}
```

**2. Added ESLint Rule**

Custom rule to detect manual connection.getConnection() usage:

```javascript
// Warns if getConnection() used without withConnection wrapper
'custom/require-connection-wrapper': 'error'
```

### Monitoring Improvements

**3. Connection Pool Monitoring**

Added Datadog metrics:
- `db.pool.active_connections` (alert if > 80 for 2 min)
- `db.pool.queued_requests` (alert if > 10)
- `db.pool.connection_acquire_time` (alert if p95 > 1s)

**4. Leak Detection**

Connection acquisition now logged with stack trace:
```typescript
connection.acquiredAt = Date.now();
connection.acquiredStack = new Error().stack;

// Alert if any connection held > 30s
```

### Process Improvements

**5. Code Review Checklist Updated**

Added required checks:
- [ ] All database connections use `withConnection()` wrapper
- [ ] No manual `connection.release()` calls
- [ ] Error paths tested for resource cleanup

**6. Load Testing**

Added to CI/CD pipeline:
- Simulate connection leak scenarios
- Verify graceful degradation under pool saturation
- Test connection timeout behavior

---

## Follow-Up Tasks

- [x] Deploy immediate fix (COMPLETED 14:32 UTC)
- [x] Audit all repository files (COMPLETED 16:45 UTC, 6 issues fixed)
- [ ] Implement withConnection() wrapper (IN PROGRESS, due Dec 6)
- [ ] Add connection pool monitoring (SCHEDULED Dec 7)
- [ ] Update code review guidelines (SCHEDULED Dec 8)
- [ ] Conduct incident postmortem meeting (SCHEDULED Dec 9, 2pm EST)
- [ ] Update runbook with connection pool debugging steps (DUE Dec 10)

**Incident Report**: JIRA-5834
**Postmortem Doc**: [Link to Google Doc]
```

---

## 4. Migration Guide Style

### Purpose
Step-by-step migration or upgrade instructions with clear validation points and rollback procedures.

### Structure
- **Overview**: What's changing and why
- **Prerequisites**: Requirements before starting
- **Migration Steps**: Numbered, sequential instructions
- **Validation**: How to verify success
- **Rollback**: How to revert if needed

### When to Use
- Framework upgrades
- Database migrations
- Deployment procedures
- Configuration changes

### Sample Output

```markdown
## Migration Guide: React 17 → React 18

This guide covers upgrading from React 17.0.2 to React 18.2.0, including new features (concurrent rendering, automatic batching) and breaking changes.

**Estimated Time**: 2-3 hours for medium-sized app
**Risk Level**: Medium (breaking changes in render behavior)
**Recommended Approach**: Staged rollout with feature flags

---

## Overview

### What's Changing

**Major Changes**:
- New root API (`createRoot` replaces `ReactDOM.render`)
- Automatic batching in event handlers and async code
- Concurrent rendering features (Suspense, Transitions)
- Stricter hydration error reporting

**Breaking Changes**:
- `ReactDOM.render` deprecated (still works with warning)
- `unmountComponentAtNode` replaced with `root.unmount()`
- Consistent `useEffect` timing (may reveal timing bugs)
- Stricter prop type checking in dev mode

### Why Migrate

- **Performance**: 30-40% faster renders with concurrent features
- **Developer Experience**: Better error messages, improved DevTools
- **Future-Proof**: Required for React 19+ and ecosystem libraries
- **Security**: React 17 end-of-support in Q2 2026

---

## Prerequisites

### Environment Requirements
- [ ] Node.js >= 16.14.0 (React 18 requires Node 16+)
- [ ] TypeScript >= 4.7.0 (if using TypeScript)
- [ ] Test coverage >= 70% (to catch breaking changes)

### Dependency Updates
Check these packages need React 18-compatible versions:

```bash
# Check current versions
npm list react-dom react-router-dom @testing-library/react

# Known compatibility requirements
react-router-dom >= 6.4.0
@testing-library/react >= 13.0.0
react-redux >= 8.0.0
```

### Backup Checklist
- [ ] Create git branch: `git checkout -b upgrade/react-18`
- [ ] Tag current version: `git tag pre-react-18-upgrade`
- [ ] Backup package-lock.json: `cp package-lock.json package-lock.json.backup`
- [ ] Document current render behavior (screenshot key pages)

---

## Migration Steps

### Step 1: Update React Packages

```bash
npm install react@18.2.0 react-dom@18.2.0

# If using TypeScript
npm install --save-dev @types/react@18.2.0 @types/react-dom@18.2.0
```

**Verify installation**:
```bash
npm list react react-dom
# Should show 18.2.0 for both
```

### Step 2: Update Root Rendering (Breaking Change)

**Before (React 17)**:
```typescript
// src/index.tsx
import ReactDOM from 'react-dom';
import App from './App';

ReactDOM.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
  document.getElementById('root')
);
```

**After (React 18)**:
```typescript
// src/index.tsx
import { createRoot } from 'react-dom/client';
import App from './App';

const container = document.getElementById('root');
const root = createRoot(container!); // TypeScript: ! asserts non-null

root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```

### Step 3: Update Test Setup

**Before (React 17)**:
```typescript
// src/setupTests.ts
import { render } from '@testing-library/react';

// Tests using render() directly
```

**After (React 18)**:
```typescript
// src/setupTests.ts
import { render } from '@testing-library/react';

// No changes needed! @testing-library/react@13+ handles React 18 automatically
// But update version:
// npm install --save-dev @testing-library/react@14.0.0
```

### Step 4: Fix Automatic Batching Issues (If Applicable)

React 18 batches state updates everywhere, not just in event handlers. This can reveal bugs where code assumed immediate updates.

**Common Issue**: Testing code that expects immediate state updates

```typescript
// This might break in React 18
it('updates state immediately', () => {
  const { getByText } = render(<Counter />);

  act(() => {
    fireEvent.click(getByText('Increment'));
  });

  expect(getByText('Count: 1')).toBeInTheDocument();
});

// Fix: Wrap in act() or use waitFor()
it('updates state immediately', async () => {
  const { getByText } = render(<Counter />);

  fireEvent.click(getByText('Increment'));

  await waitFor(() => {
    expect(getByText('Count: 1')).toBeInTheDocument();
  });
});
```

### Step 5: Update Third-Party Libraries

```bash
# React Router (if using v5, upgrade to v6)
npm install react-router-dom@6.20.0

# Redux (if using)
npm install react-redux@8.1.3

# Testing Library
npm install --save-dev @testing-library/react@14.1.0

# Check for other React-dependent packages
npm outdated | grep -E "react|@types/react"
```

### Step 6: Fix TypeScript Type Errors (If Using TypeScript)

**Common Type Change**: Children prop now explicit

```typescript
// Before: children implicitly allowed
interface Props {
  title: string;
}

// After: must explicitly declare children
interface Props {
  title: string;
  children?: React.ReactNode;  // Add this
}
```

**Common Type Change**: Function component return type

```typescript
// Before: FC includes children by default
const Component: React.FC<Props> = ({ title }) => { ... };

// After: Use explicit return type
const Component = ({ title }: Props): JSX.Element => { ... };
// Or use PropsWithChildren for components that accept children
const Component = ({ title, children }: PropsWithChildren<Props>) => { ... };
```

### Step 7: Enable Concurrent Features (Optional)

```typescript
// Enable Suspense for data fetching
import { Suspense } from 'react';

function App() {
  return (
    <Suspense fallback={<Loading />}>
      <DataComponent />
    </Suspense>
  );
}

// Use useTransition for non-urgent updates
import { useTransition } from 'react';

function SearchComponent() {
  const [isPending, startTransition] = useTransition();
  const [query, setQuery] = useState('');

  const handleChange = (e) => {
    startTransition(() => {
      setQuery(e.target.value);  // Non-urgent update
    });
  };

  return <input onChange={handleChange} />;
}
```

---

## Validation

### Automated Checks

```bash
# 1. Run full test suite
npm test

# 2. Run type checking (if TypeScript)
npm run type-check

# 3. Run linter
npm run lint

# 4. Build production bundle
npm run build

# 5. Check bundle size (should be similar or smaller)
npm run build -- --stats
```

### Manual Testing Checklist

- [ ] Application loads without console errors
- [ ] All routes render correctly
- [ ] Form submissions work as expected
- [ ] Async data fetching displays correctly
- [ ] Authentication flow works
- [ ] No hydration errors in SSR (if applicable)
- [ ] DevTools show React 18 in console

### Performance Validation

```bash
# Run Lighthouse audit
npm install -g lighthouse
lighthouse http://localhost:3000 --view

# Compare metrics to pre-upgrade baseline:
# - First Contentful Paint should be similar or better
# - Time to Interactive should improve
# - Total Blocking Time should decrease
```

---

## Rollback Procedure

If critical issues found after deployment:

### Quick Rollback (Revert Deployment)

```bash
# 1. Revert to previous git tag
git checkout pre-react-18-upgrade

# 2. Restore dependencies
cp package-lock.json.backup package-lock.json
npm ci

# 3. Rebuild and redeploy
npm run build
# Deploy using your standard process
```

### Partial Rollback (Keep React 18, Disable Features)

If issue is with concurrent features, not React 18 itself:

```typescript
// Disable concurrent rendering temporarily
import { createRoot } from 'react-dom/client';

const container = document.getElementById('root');
const root = createRoot(container, {
  // This opts out of concurrent features
  unstable_strictMode: false
});
```

---

## Troubleshooting

### Issue: "Warning: ReactDOM.render is no longer supported"

**Solution**: Update to createRoot API (see Step 2)

### Issue: Tests failing with "act() warning"

**Solution**: Update @testing-library/react to v13+ and wrap state updates in act()

### Issue: Hydration errors in SSR

**Cause**: React 18 stricter about client/server HTML matching

**Solution**: Check for browser-only code running during SSR:
```typescript
// Before
const isClient = typeof window !== 'undefined';

// After: use useEffect to run client-only code
useEffect(() => {
  // This only runs on client
}, []);
```

### Issue: Performance regression

**Cause**: May need to opt into concurrent features to see benefits

**Solution**: Gradually enable Suspense and useTransition (see Step 7)

---

## Additional Resources

- [React 18 Official Upgrade Guide](https://react.dev/blog/2022/03/08/react-18-upgrade-guide)
- [React 18 Working Group Discussions](https://github.com/reactwg/react-18/discussions)
- [TypeScript React 18 Migration](https://github.com/DefinitelyTyped/DefinitelyTyped/pull/56210)

**Migration Support**: #react-upgrades Slack channel or react-upgrades@company.com
```

---

## Using These Styles

### Adaptation Guidelines

1. **Copy the structure**, modify the content to match your specific use case
2. **Preserve section hierarchy** - the headings create scannable structure
3. **Include real code examples** - never use TODO or placeholder code
4. **Add specific file paths** - absolute paths help readers locate context
5. **Use concrete metrics** - "3.2s p95" not "slow response times"

### Style Selection Matrix

| Task Type | Recommended Style | Key Characteristics |
|-----------|------------------|---------------------|
| PR review | Code Review | Severity levels, code snippets, specific line numbers |
| Performance investigation | Analysis Summary | Metrics, methodology, data-driven conclusions |
| Bug postmortem | Error Report | Timeline, root cause, impact quantification |
| Framework upgrade | Migration Guide | Step-by-step, validation points, rollback plan |

### Quality Checklist

- [ ] All code examples are complete and runnable
- [ ] File paths are absolute, not relative
- [ ] Metrics include units and context
- [ ] Recommendations are specific and actionable
- [ ] Structure uses consistent heading levels
- [ ] No placeholder content (TODO, XXX, etc.)
