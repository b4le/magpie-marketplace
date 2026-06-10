# Memory Examples for Different Project Types

## Overview

Different project types benefit from different memory patterns. This guide provides specific examples and patterns optimized for common project types.

## Web Application

### Focus Areas
- Frontend/backend separation
- API conventions
- Styling approaches
- State management
- Authentication patterns

### Example Memory Structure

```markdown
# Web App Project

## Stack
- Next.js 14 (App Router)
- TypeScript
- Tailwind CSS
- PostgreSQL with Prisma

## Patterns
- Server Components by default
- Client Components only when needed (use "use client")
- API routes in `app/api/`
- Database queries in server components or server actions

## Styling
- Use Tailwind utility classes
- Create components in `components/ui/` for reusable UI
- Follow design tokens from `tailwind.config.ts`

## State Management
- Server state: React Server Components
- Client state: useState for local, Context for global
- Form state: React Hook Form

## Authentication
- NextAuth.js for authentication
- Session stored in JWT
- Protected routes use middleware
```

### Key Practices
- Emphasize component patterns (Server vs Client)
- Document API route conventions
- Specify styling approach clearly
- Define state management boundaries

---

## API/Backend Service

### Focus Areas
- Endpoint patterns
- Request validation
- Error handling
- Database access patterns
- API versioning

### Example Memory Structure

```markdown
# API Service

## Stack
- Node.js with Express
- TypeScript
- PostgreSQL
- Redis for caching

## Conventions
- RESTful API design
- OpenAPI/Swagger documentation
- All endpoints have request validation (Zod)
- All endpoints have error handling middleware
- Use repository pattern for data access

## Endpoints
- `/api/v1/` prefix for all routes
- Use proper HTTP methods and status codes
- Include pagination for list endpoints
- Standard response format: `{ success: boolean, data?: any, error?: string }`

## Error Handling
\`\`\`typescript
class ApiError extends Error {
  constructor(public statusCode: number, message: string) {
    super(message);
  }
}
// Global error handler catches all ApiErrors
\`\`\`

## Database Access
- All queries through repository pattern
- Use transactions for multi-step operations
- Connection pooling configured for [max connections]
```

### Key Practices
- Document consistent error handling
- Specify API response formats
- Define data access patterns
- Include versioning strategy

---

## Library/Package

### Focus Areas
- Export patterns
- Versioning strategy
- Documentation requirements
- Testing coverage
- Bundle configuration

### Example Memory Structure

```markdown
# Library Package

## Development
- Pure TypeScript (no framework dependencies)
- Comprehensive unit tests (>90% coverage)
- Bundle with tsup
- Export both ESM and CJS

## Conventions
- All exports must be typed
- Document all public APIs with JSDoc
- Include usage examples in docs
- Semantic versioning strictly

## Export Pattern
\`\`\`typescript
// Single index.ts with named exports
export { FunctionA, FunctionB } from './functions';
export type { TypeA, TypeB } from './types';
\`\`\`

## Testing
- Unit tests for all public APIs
- Integration tests for complex workflows
- Performance tests for critical paths
- Coverage requirement: >90%

## Publishing
- Automated via CI/CD
- Changelog generated from commits
- NPM provenance enabled
```

### Key Practices
- Emphasize TypeScript types for all exports
- Document versioning strictly
- High testing standards
- Clear export patterns

---

## CLI Tool

### Focus Areas
- Command patterns
- Argument handling
- Output formatting
- Error messages
- Help text

### Example Memory Structure

```markdown
# CLI Tool

## Stack
- Node.js
- Commander.js for CLI
- TypeScript

## Conventions
- All commands follow pattern: `tool <command> [options]`
- Include `--help` for all commands
- Use consistent exit codes (0 success, 1 error)
- Color output using chalk
- Verbose mode with `-v` or `--verbose`

## Command Pattern
\`\`\`typescript
program
  .command('deploy')
  .description('Deploy the application')
  .option('-e, --environment <env>', 'Target environment')
  .option('-v, --verbose', 'Verbose output')
  .action(async (options) => {
    // Command implementation
  });
\`\`\`

## Output Formatting
- Success: Green check mark + message
- Error: Red X + error message
- Warning: Yellow triangle + warning
- Info: Blue info icon + message

## Testing
- Test commands with fixtures
- Test help text generation
- Test error handling
- Test output formatting
```

### Key Practices
- Consistent command structure
- Clear help text
- Standardized exit codes
- Well-formatted output

---

## Mobile Application (React Native)

### Focus Areas
- Platform-specific code
- Navigation patterns
- State management
- API integration
- Native module usage

### Example Memory Structure

```markdown
# Mobile App (React Native)

## Stack
- React Native
- TypeScript
- React Navigation
- Redux Toolkit
- Axios for API

## File Structure
\`\`\`
src/
├── screens/        # Screen components
├── components/     # Reusable components
├── navigation/     # Navigation configuration
├── store/          # Redux store
├── services/       # API services
├── utils/          # Utilities
└── types/          # TypeScript types
\`\`\`

## Platform-Specific Code
- Use `.ios.tsx` and `.android.tsx` for platform-specific components
- Platform checks: `Platform.OS === 'ios'`
- Keep platform-specific code minimal

## Navigation
- Tab navigation for main sections
- Stack navigation within sections
- Deep linking configured for all screens

## State Management
- Redux Toolkit for global state
- RTK Query for API calls
- Local state with useState for component-specific

## API Integration
- Centralized API client in `services/api.ts`
- Error handling with interceptors
- Retry logic for failed requests
```

### Key Practices
- Document platform-specific patterns
- Clear navigation structure
- Centralized API handling
- State management boundaries

---

## Monorepo

### Focus Areas
- Workspace organization
- Shared dependencies
- Build orchestration
- Code sharing patterns
- Testing strategy

### Example Memory Structure

```markdown
# Monorepo Project

## Structure
\`\`\`
packages/
├── web/            # Web application
├── mobile/         # Mobile application
├── api/            # Backend API
├── shared/         # Shared utilities
└── ui/             # Shared UI components
\`\`\`

## Workspace Management
- Package manager: pnpm with workspaces
- Versioning: Independent versioning per package
- Scripts: Use workspace protocol for dependencies

## Shared Code
- `@company/shared` - Utilities, types, constants
- `@company/ui` - Shared React components
- Import pattern: `import { util } from '@company/shared'`

## Building
- Turborepo for build orchestration
- Cache builds across CI and local
- Run tasks: `turbo run build --filter=web`

## Testing
- Unit tests: Per-package in `packages/*/src/**/*.test.ts`
- Integration tests: In `packages/integration/`
- E2E tests: In `apps/e2e/`

## Conventions
- Consistent structure across packages
- Shared ESLint and TypeScript config
- Shared prettier config
- Commit scope includes package name
```

### Key Practices
- Clear package organization
- Documented code sharing patterns
- Build orchestration strategy
- Consistent tooling across packages

---

## Data Science / Python Project

### Focus Areas
- Virtual environment
- Notebook organization
- Data pipeline patterns
- Model versioning
- Reproducibility

### Example Memory Structure

```markdown
# Data Science Project

## Environment
- Python 3.11
- Poetry for dependency management
- Jupyter for notebooks

## Project Structure
\`\`\`
src/
├── data/              # Data loading and processing
├── features/          # Feature engineering
├── models/            # Model definitions
├── training/          # Training scripts
├── evaluation/        # Evaluation metrics
└── utils/             # Utilities

notebooks/             # Jupyter notebooks
data/
├── raw/               # Original data (never modify)
├── processed/         # Cleaned data
└── external/          # External datasets

models/                # Trained models
\`\`\`

## Data Processing
- Never modify raw data
- All processing in reproducible scripts
- Document data sources and versions
- Use DVC for data versioning

## Notebooks
- Use for exploration only
- Production code in `src/`
- Clear naming: `01-exploration.ipynb`, `02-cleaning.ipynb`
- Include markdown cells explaining process

## Model Training
\`\`\`python
# Standard training pattern
def train_model(config: TrainingConfig):
    # Load data
    # Process features
    # Train model
    # Evaluate
    # Save model with metadata
\`\`\`

## Reproducibility
- Pin all dependencies
- Set random seeds
- Document hardware requirements
- Version models with metrics
```

### Key Practices
- Emphasize reproducibility
- Clear data pipeline
- Notebook organization
- Model versioning

---

## Choosing the Right Pattern

### Questions to Ask

1. **What's the primary output?**
   - User interface → Web/Mobile App
   - API endpoints → Backend Service
   - Reusable code → Library
   - Command execution → CLI Tool

2. **Who are the users?**
   - End users → App patterns
   - Other developers → Library patterns
   - System administrators → CLI patterns

3. **What's the deployment target?**
   - Web browsers → Web App
   - Mobile devices → Mobile App
   - NPM registry → Library
   - Servers/containers → Backend Service

4. **How complex is the codebase?**
   - Single package → Standard patterns
   - Multiple packages → Monorepo patterns

### Mixing Patterns

Many projects combine patterns:
- **Full-stack app:** Web App + Backend Service patterns
- **Developer tool:** CLI Tool + Library patterns
- **Platform:** Monorepo + multiple app types

Create sections for each pattern and clearly separate concerns.

## Tips for All Project Types

1. **Start with the basics:**
   - Technology stack
   - Common commands
   - One or two key conventions

2. **Grow over time:**
   - Add patterns as they emerge
   - Document decisions when made
   - Remove obsolete patterns

3. **Keep it practical:**
   - Real code examples
   - Actual commands that work
   - Patterns that are actually used

4. **Make it scannable:**
   - Use headers and lists
   - Code blocks for examples
   - Tables for comparisons

5. **Update regularly:**
   - Review monthly
   - Update after major changes
   - Remove deprecated content
