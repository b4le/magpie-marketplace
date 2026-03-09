# Complete Real-World Memory Examples

## Overview

This document provides complete, production-ready memory file examples from real projects. These are not templates but actual examples you can learn from and adapt.

---

## Example 1: React SPA with TypeScript

### Project Context
- Single-page application with client-side routing
- Medium-sized team (5-8 developers)
- Established patterns and conventions

### Complete CLAUDE.md

```markdown
# React Dashboard Application

Modern dashboard application for data visualization and analytics.

## Architecture
Single-page application with client-side routing and RESTful API backend.

## Stack
- **Frontend:** React 18 with TypeScript
- **Build Tool:** Vite
- **Routing:** React Router v6
- **Data Fetching:** TanStack Query
- **Styling:** Tailwind CSS
- **State:** Context API (minimal)
- **Testing:** Vitest + Testing Library
- **E2E:** Playwright

## Coding Conventions

### Components
- Functional components with hooks only (no class components)
- Props interface exported and documented
- One component per file
- Co-locate styles if using CSS modules

Example:
\`\`\`typescript
// components/Button/Button.tsx
export interface ButtonProps {
  label: string;
  onClick: () => void;
  variant?: 'primary' | 'secondary';
  disabled?: boolean;
}

export const Button: React.FC<ButtonProps> = ({
  label,
  onClick,
  variant = 'primary',
  disabled = false,
}) => {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={clsx(
        'px-4 py-2 rounded',
        variant === 'primary' ? 'bg-blue-600 text-white' : 'bg-gray-200'
      )}
    >
      {label}
    </button>
  );
};
\`\`\`

### TypeScript
- Strict mode enabled
- No `any` types (use `unknown` if needed)
- Explicit return types for exported functions
- Props interfaces always exported

### State Management
- **Local State:** `useState` for component-specific state
- **Server State:** TanStack Query for all API data
- **Global State:** Context API only when necessary (user preferences, theme)
- **Form State:** React Hook Form

### File Structure
\`\`\`
src/
├── components/
│   └── Button/
│       ├── Button.tsx
│       ├── Button.test.tsx
│       └── index.ts
├── pages/
│   ├── Dashboard.tsx
│   ├── Settings.tsx
│   └── Reports.tsx
├── hooks/
│   ├── useAuth.ts
│   └── useData.ts
├── utils/
│   ├── api.ts
│   └── formatters.ts
├── types/
│   └── index.ts
└── App.tsx
\`\`\`

## API Integration

All API calls use centralized client:

\`\`\`typescript
// utils/api.ts
import { QueryClient } from '@tanstack/react-query';

const API_BASE = import.meta.env.VITE_API_BASE;

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000, // 5 minutes
      retry: 1,
    },
  },
});

export async function fetchData<T>(endpoint: string): Promise<T> {
  const response = await fetch(\`\${API_BASE}\${endpoint}\`, {
    headers: {
      'Content-Type': 'application/json',
      Authorization: \`Bearer \${getToken()}\`,
    },
  });

  if (!response.ok) {
    throw new Error(\`HTTP \${response.status}\`);
  }

  return response.json();
}
\`\`\`

## Testing

### Unit Tests
- All utility functions
- All custom hooks
- Complex component logic

### Component Tests
- User interactions
- Conditional rendering
- Props handling
- Error states

### E2E Tests
- Critical user flows
- Authentication
- Data submission
- Navigation

**Coverage Target:** 80% overall, 90% for utilities

## Common Commands

\`\`\`bash
npm run dev           # Start dev server (http://localhost:5173)
npm test             # Run unit tests
npm run test:watch   # Run tests in watch mode
npm run test:e2e     # Run E2E tests
npm run lint         # Run ESLint
npm run typecheck    # Run TypeScript compiler check
npm run build        # Build for production
\`\`\`

## Git Workflow

- **Branch Naming:** `feature/TICKET-description`, `fix/TICKET-description`
- **Commit Format:** Conventional commits (feat:, fix:, docs:, etc.)
- **PR Requirements:**
  - All tests passing
  - No TypeScript errors
  - Code review from 1 team member
  - Updated documentation if needed

## Environment Variables

Required in `.env`:
\`\`\`
VITE_API_BASE=http://localhost:3000/api
VITE_AUTH_DOMAIN=your-auth-domain
\`\`\`

## Version History

### 2025-01-15
- Updated to React 18
- Migrated from Jest to Vitest
- Added Playwright for E2E tests

### 2024-11-01
- Initial project setup
- Established core patterns
\`\`\`

### Key Learnings

**What works well:**
- Clear component patterns reduce confusion
- TanStack Query eliminates most state management
- Strict TypeScript catches bugs early
- Co-located tests encourage testing

**What to emphasize:**
- One component per file (enforced)
- Export props interfaces (makes them reusable)
- Specific state management rules (prevents confusion)
- Concrete code examples (faster onboarding)

---

## Example 2: Express API with PostgreSQL

### Project Context
- RESTful API backend
- Microservice in larger system
- Team of 3-5 developers
- High reliability requirements

### Complete CLAUDE.md

```markdown
# Express API Service

User management API service for the platform.

## Architecture

RESTful API with PostgreSQL database and Redis caching layer.

### Components
- **Express:** HTTP server and routing
- **Prisma:** Database ORM
- **Redis:** Session storage and caching
- **Bull:** Background job processing

## Stack
- **Runtime:** Node.js 20 LTS
- **Framework:** Express with TypeScript
- **Database:** PostgreSQL 15
- **ORM:** Prisma
- **Cache:** Redis
- **Testing:** Jest
- **API Docs:** OpenAPI 3.0

## API Conventions

### Endpoints
- **Prefix:** `/api/v1/`
- **Resources:** Plural nouns (`/users`, `/posts`)
- **HTTP Methods:** GET, POST, PUT, DELETE (no PATCH)
- **Status Codes:** 200 (success), 201 (created), 400 (bad request), 401 (unauthorized), 404 (not found), 500 (server error)

### Request Validation

All endpoints use Zod for validation:

\`\`\`typescript
import { z } from 'zod';

const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
  age: z.number().int().min(0).optional(),
});

router.post('/users', validate(CreateUserSchema), async (req, res) => {
  // req.body is typed and validated
  const user = await userService.create(req.body);
  res.status(201).json({ success: true, data: user });
});
\`\`\`

### Response Format

Consistent response structure:

\`\`\`typescript
// Success
{
  success: true,
  data: any
}

// Error
{
  success: false,
  error: string,
  details?: any
}

// List with pagination
{
  success: true,
  data: any[],
  pagination: {
    page: number,
    pageSize: number,
    total: number,
    totalPages: number
  }
}
\`\`\`

### Error Handling

Global error handler:

\`\`\`typescript
class ApiError extends Error {
  constructor(
    public statusCode: number,
    message: string,
    public details?: any
  ) {
    super(message);
  }
}

// Usage
if (!user) {
  throw new ApiError(404, 'User not found');
}

// Middleware catches all ApiErrors
app.use((err, req, res, next) => {
  if (err instanceof ApiError) {
    res.status(err.statusCode).json({
      success: false,
      error: err.message,
      details: err.details,
    });
  } else {
    logger.error('Unexpected error', err);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});
\`\`\`

## Database

### Prisma Patterns

- **Migrations:** `npx prisma migrate dev`
- **Generate Client:** `npx prisma generate`
- **Studio:** `npx prisma studio`

### Repository Pattern

All database access through repositories:

\`\`\`typescript
class UserRepository {
  async findById(id: string) {
    return prisma.user.findUnique({ where: { id } });
  }

  async create(data: CreateUserData) {
    return prisma.user.create({ data });
  }

  async update(id: string, data: UpdateUserData) {
    return prisma.user.update({ where: { id }, data });
  }

  async delete(id: string) {
    return prisma.user.delete({ where: { id } });
  }
}
\`\`\`

### Transactions

Multi-step operations use transactions:

\`\`\`typescript
await prisma.$transaction(async (tx) => {
  const user = await tx.user.create({ data: userData });
  await tx.profile.create({ data: { userId: user.id, ...profileData } });
  return user;
});
\`\`\`

## File Structure

\`\`\`
src/
├── routes/           # Express routes
├── controllers/      # Request handlers
├── services/         # Business logic
├── repositories/     # Database access
├── middleware/       # Express middleware
├── utils/           # Utilities
├── types/           # TypeScript types
├── config/          # Configuration
└── server.ts        # Entry point

prisma/
├── schema.prisma    # Database schema
└── migrations/      # Migration files
\`\`\`

## Testing

### Unit Tests
- All services
- All repositories
- All utilities

### Integration Tests
- All endpoints
- Database operations
- Redis operations

**Test Database:** Uses `test.db` in SQLite mode for speed

**Coverage:** Minimum 85%

## Common Commands

\`\`\`bash
npm run dev              # Start with nodemon
npm test                # Run tests
npm run test:watch      # Run tests in watch mode
npm run test:coverage   # Run tests with coverage
npm run lint            # Run ESLint
npm run typecheck       # TypeScript type check
npm run build           # Build for production
npm start               # Start production build
npm run migrate         # Run database migrations
\`\`\`

## Environment Variables

\`\`\`
NODE_ENV=development
PORT=3000
DATABASE_URL=postgresql://user:password@localhost:5432/dbname
REDIS_URL=redis://localhost:6379
JWT_SECRET=your-secret-key
LOG_LEVEL=debug
\`\`\`

## Deployment

- **Platform:** Docker on AWS ECS
- **Database:** AWS RDS PostgreSQL
- **Cache:** AWS ElastiCache Redis
- **Health Check:** `GET /health`
- **Metrics:** Prometheus endpoint at `/metrics`

## Version History

### 2025-01-10
- Added Bull for background jobs
- Implemented rate limiting
- Updated to Node 20 LTS

### 2024-09-15
- Initial service setup
- Core CRUD endpoints
\`\`\`

### Key Learnings

**What works well:**
- Repository pattern isolates database logic
- Zod validation catches issues early
- Consistent error handling simplifies debugging
- Transaction support prevents data inconsistencies

**What to emphasize:**
- Strict error handling patterns
- Consistent response formats
- Repository pattern (no direct Prisma calls in controllers)
- Transaction usage for multi-step operations

---

## Example 3: Monorepo with Multiple Apps

### Project Context
- Multiple related applications
- Shared component library
- 10+ developers across teams

### Complete CLAUDE.md

```markdown
# Platform Monorepo

Monorepo containing web app, mobile app, API, and shared packages.

## Structure

\`\`\`
apps/
├── web/              # Next.js web application
├── mobile/           # React Native mobile app
└── api/              # Express API

packages/
├── ui/               # Shared React components
├── utils/            # Shared utilities
├── types/            # Shared TypeScript types
└── config/           # Shared configs (ESLint, TS, etc.)
\`\`\`

## Workspace Management

- **Package Manager:** pnpm with workspaces
- **Build Tool:** Turborepo
- **Versioning:** Independent per package

### Installing Dependencies

\`\`\`bash
# Root dependencies
pnpm add -w <package>

# Workspace dependencies
pnpm add <package> --filter web

# Internal dependencies (use workspace protocol)
pnpm add @platform/ui --filter mobile
\`\`\`

## Shared Packages

### @platform/ui

Shared React components for web and mobile.

\`\`\`typescript
import { Button, Card } from '@platform/ui';
\`\`\`

**Guidelines:**
- No framework-specific code (works in Next.js and React Native)
- Fully typed with TypeScript
- Documented with Storybook
- Tested with Vitest

### @platform/utils

Shared utility functions.

\`\`\`typescript
import { formatDate, validateEmail } from '@platform/utils';
\`\`\`

### @platform/types

Shared TypeScript types and interfaces.

\`\`\`typescript
import type { User, Post } from '@platform/types';
\`\`\`

## Building and Running

### Development

\`\`\`bash
# Run all apps
pnpm dev

# Run specific app
pnpm dev --filter web
pnpm dev --filter mobile
pnpm dev --filter api
\`\`\`

### Building

\`\`\`bash
# Build all
pnpm build

# Build specific
pnpm build --filter web

# Build with dependencies
turbo run build --filter=web...
\`\`\`

### Testing

\`\`\`bash
# Test all
pnpm test

# Test specific workspace
pnpm test --filter ui
\`\`\`

## Conventions

### Naming
- Apps: Single word (web, mobile, api)
- Packages: Scoped with @platform/ prefix

### Imports
- Internal packages: `@platform/<name>`
- Relative imports: Only within same package

### Versioning
- Apps: Independent versioning
- Packages: Semantic versioning
- Publish only packages, not apps

### Code Sharing

**Do:**
- Share types across all workspaces
- Share UI components between web/mobile
- Share utilities for common operations
- Share config files (tsconfig, eslint)

**Don't:**
- Share app-specific logic
- Create circular dependencies
- Put app code in shared packages

## Scripts

All workspaces have consistent scripts:

\`\`\`json
{
  "scripts": {
    "dev": "...",
    "build": "...",
    "test": "...",
    "lint": "...",
    "typecheck": "tsc --noEmit"
  }
}
\`\`\`

## Version History

### 2025-01-01
- Migrated to pnpm workspaces
- Added Turborepo for builds
- Extracted @platform/ui package

### 2024-10-15
- Initial monorepo setup
\`\`\`

### Key Learnings

**What works well:**
- Turborepo dramatically speeds up builds
- Shared configs ensure consistency
- Workspace protocol simplifies internal dependencies
- Clear boundaries between apps and packages

**What to emphasize:**
- When to share code (types, utilities, UI) vs when not to (app logic)
- Consistent script names across all packages
- Using --filter for workspace-specific commands
- Import conventions (@platform/ for internal packages)

---

## Common Patterns Across Examples

### All Examples Include:

1. **Technology Stack** - Specific versions and tools
2. **Common Commands** - Copy-pasteable commands
3. **Code Examples** - Real, working code
4. **File Structure** - Visual directory tree
5. **Conventions** - Specific, enforced patterns

### All Examples Avoid:

1. **Vague Guidance** - "Write good code"
2. **Generic Advice** - Applicable to any project
3. **Outdated Info** - Old package versions
4. **Missing Context** - Why decisions were made

### Best Practices Demonstrated:

- Start with overview and stack
- Show actual code, not pseudocode
- Include "why" with "what"
- Document version history
- Provide complete, working examples
- Use tables and lists for scannability
- Include practical commands that work
