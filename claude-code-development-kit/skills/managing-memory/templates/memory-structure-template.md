# Memory Structure Template

## Purpose

This template provides a complete, production-ready structure for CLAUDE.md files. Copy and customize for your project.

## Usage

1. Copy this entire template
2. Replace placeholders with your project details
3. Remove sections that don't apply
4. Add project-specific sections as needed

## Template

```markdown
# [Project Name]

[Brief 1-2 sentence description of the project]

## Architecture

[Overview of project architecture - high-level components, how they interact]

### Frontend
[Frontend architecture details if applicable]

### Backend
[Backend architecture details if applicable]

### Database
[Database architecture and schema approach if applicable]

## Technology Stack

- **Frontend:** [e.g., React 18, TypeScript, Tailwind CSS]
- **Backend:** [e.g., Node.js, Express, TypeScript]
- **Database:** [e.g., PostgreSQL with Prisma ORM]
- **Testing:** [e.g., Jest, React Testing Library, Playwright]
- **Deployment:** [e.g., Vercel, Docker, AWS]

## Coding Conventions

### [Language 1 - e.g., TypeScript]

- Use strict mode
- Prefer [specific patterns]
- [Other conventions]

### [Framework 1 - e.g., React]

- Use functional components with hooks
- Keep components small and focused
- Co-locate tests with components
- [Other framework conventions]

### [Framework 2 - e.g., API Design]

- RESTful endpoints
- Consistent error handling
- [Other API conventions]

## File Structure

\`\`\`
src/
├── components/          # React components
│   └── [Component]/
│       ├── Component.tsx
│       ├── Component.test.tsx
│       └── index.ts
├── hooks/              # Custom hooks
├── utils/              # Utility functions
├── types/              # TypeScript types
├── api/                # API routes/clients
└── tests/              # Test files
\`\`\`

## Common Commands

\`\`\`bash
npm run dev           # Start development server
npm test             # Run unit tests
npm run test:e2e     # Run E2E tests
npm run lint         # Run linter
npm run build        # Build for production
npm run deploy       # Deploy to [environment]
\`\`\`

## Code Patterns

### [Pattern Name 1 - e.g., Component Pattern]

\`\`\`typescript
// Preferred component structure
export interface ComponentProps {
  // Props definition
}

export const Component: React.FC<ComponentProps> = (props) => {
  // Component implementation
};
\`\`\`

### [Pattern Name 2 - e.g., Error Handling]

All functions should use try-catch with proper error logging:

\`\`\`typescript
try {
  // Operation
} catch (error) {
  logger.error('Operation failed', { error });
  throw new CustomError('User-friendly message');
}
\`\`\`

### [Pattern Name 3 - e.g., API Requests]

\`\`\`typescript
async function fetchData<T>(endpoint: string): Promise<T> {
  try {
    const response = await fetch(\`/api/\${endpoint}\`);
    if (!response.ok) {
      throw new Error(\`HTTP \${response.status}\`);
    }
    return await response.json();
  } catch (error) {
    logger.error('API request failed', { endpoint, error });
    throw error;
  }
}
\`\`\`

## Testing Approach

- **Unit Tests:** [Coverage requirements, what to test]
- **Integration Tests:** [What integration points to test]
- **E2E Tests:** [Critical user flows to test]
- **Test Location:** [Co-located vs separate directories]

## Git Workflow

- **Branch Naming:** `feature/description`, `fix/description`, `refactor/description`
- **Commit Messages:** [Conventional commits / your format]
- **PR Requirements:**
  - All tests passing
  - Code review from [number] team members
  - [Other requirements]

## Documentation Standards

- Document all exported functions
- Include JSDoc comments for complex logic
- Update README for significant changes
- [Other documentation requirements]

## Environment Setup

### Prerequisites

- Node.js [version]
- [Other prerequisites]

### Getting Started

1. Clone repository
2. Install dependencies: `npm install`
3. Copy `.env.example` to `.env`
4. [Other setup steps]
5. Run development server: `npm run dev`

## External Documentation

- [API Documentation](https://...)
- [Design System](https://...)
- [Internal Wiki](@docs/wiki.md)
- [Architecture Decisions](@docs/adr/)

## Team Contacts

- **Tech Lead:** [Name/Contact]
- **Product Owner:** [Name/Contact]
- **Team Channel:** [Slack/Teams channel]

## Version History

### [Date - e.g., 2025-01-15]
- [Change description]
- [Another change]

### [Earlier Date]
- Initial project setup
\`\`\`

## Customization Points

### Essential Sections (Always Include)
- Project name and description
- Technology stack
- Common commands
- Coding conventions (at least one language/framework)

### Optional Sections (Include If Applicable)
- Architecture diagrams/descriptions (for complex projects)
- File structure (helpful for larger projects)
- Git workflow (for team projects)
- Testing approach (if tests are critical)
- Team contacts (for larger teams)

### When to Use @path Imports

If any section exceeds 30-50 lines, consider extracting to separate file:

```markdown
## Architecture

High-level overview here...

For detailed architecture documentation:
@docs/architecture.md
```

Common extractions:
- `@docs/architecture.md` - Detailed architecture docs
- `@docs/api-reference.md` - API endpoint documentation
- `@docs/style-guide.md` - Detailed coding style guide
- `@docs/deployment.md` - Deployment procedures
- `@docs/adr/` - Architecture Decision Records directory

## Tips

1. **Start Small:** Begin with just Tech Stack, Commands, and one Coding Convention section
2. **Grow Organically:** Add sections as patterns emerge in your project
3. **Keep It Updated:** Review and update monthly or after major changes
4. **Be Specific:** "Use try-catch blocks" is better than "Handle errors well"
5. **Show Examples:** Code examples are more valuable than prose descriptions
6. **Version Control:** Commit changes to CLAUDE.md like any other project documentation
