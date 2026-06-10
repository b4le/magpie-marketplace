# Full-Stack Development Plugin Example

## Overview
A comprehensive full-stack development toolkit that supports frontend, backend, and database development across multiple frameworks and technologies.

## Plugin Structure
```
fullstack-kit/
├── .claude-plugin/
│   └── plugin.json
├── commands/
│   ├── frontend/
│   │   ├── component.md
│   │   └── page.md
│   └── backend/
│       ├── endpoint.md
│       └── model.md
├── skills/
│   ├── component-generator/
│   ├── api-generator/
│   └── db-migration/
├── hooks/
│   ├── pre-commit.sh
│   └── pre-push.sh
└── mcp/
    └── servers.json
```

## Plugin Configuration
**File**: `.claude-plugin/plugin.json`
```json
{
  "name": "fullstack-kit",
  "version": "2.0.0",
  "description": "Integrated full-stack development toolkit for modern web applications",
  "author": { "name": "Engineering Team", "email": "engineering@company.com" },
  "keywords": ["fullstack", "react", "typescript", "node", "postgresql"],
  "dependencies": {
    "react-toolkit": "^1.2.0",
    "backend-utils": "^1.0.0"
  },
  "config": {
    "defaultFrontendFramework": "react",
    "defaultBackendFramework": "express",
    "defaultDatabase": "postgresql"
  }
}
```

## Frontend Commands

### Component Generation Command
**File**: `commands/frontend/component.md`
```markdown
---
description: Generate a new React/Vue component with TypeScript
argument-hint: [component-name] [framework]
---

Create a new frontend component with:
- Component implementation
- TypeScript types
- Styled components
- Unit tests
- Storybook stories

### Usage
\`\`\`bash
/fullstack-kit:frontend:component UserProfile react
\`\`\`

### Supported Frameworks
- React
- Vue
- Svelte
```

### Page Generation Command
**File**: `commands/frontend/page.md`
```markdown
---
description: Generate a complete page with routing and data fetching
argument-hint: [page-name] [framework]
---

Create a new page with:
- Page component
- Route configuration
- Data fetching logic
- Error handling
- Responsive design

### Usage
\`\`\`bash
/fullstack-kit:frontend:page Dashboard react
\`\`\`
```

## Backend Commands

### Endpoint Generation Command
**File**: `commands/backend/endpoint.md`
```markdown
---
description: Create a new backend API endpoint
argument-hint: [endpoint-name] [method]
---

Generate a complete backend endpoint:
- Route implementation
- Input validation
- Error handling
- Middleware
- OpenAPI spec

### Usage
\`\`\`bash
/fullstack-kit:backend:endpoint UserProfile GET
\`\`\`

### Supported Frameworks
- Express.js
- Koa
- NestJS
- FastAPI
```

### Model Generation Command
**File**: `commands/backend/model.md`
```markdown
---
description: Create database models and ORM mappings
argument-hint: [model-name] [database]
---

Generate database models with:
- ORM mapping
- Validation schema
- Relationships
- Migration scripts

### Usage
\`\`\`bash
/fullstack-kit:backend:model User postgresql
\`\`\`
```

## Skills

### Component Generator Skill
**File**: `skills/component-generator/SKILL.md`
```yaml
---
name: component-generator
description: Advanced component generation across multiple frontend frameworks
---

# Component Generator Skill

## Supported Frameworks
- React (TypeScript, JavaScript)
- Vue (Composition API, Options API)
- Svelte
- Angular

## Generation Features
- Component scaffolding
- Props/state management
- Styling integrations
- Accessibility hints
```

### API Generator Skill
**File**: `skills/api-generator/SKILL.md`
```yaml
---
name: api-generator
description: Generate complete backend services with robust integrations
---

# API Generator Skill

## Supported Backend Technologies
- Node.js (Express, Koa, NestJS)
- Python (FastAPI, Django)
- Go (Gin, Echo)
- Rust (Actix)

## Generation Capabilities
- CRUD endpoint scaffolding
- Authentication middleware
- Request validation
- Error handling patterns
```

### Database Migration Skill
**File**: `skills/db-migration/SKILL.md`
```yaml
---
name: db-migration
description: Database schema management and migration tools
---

# Database Migration Skill

## Supported Databases
- PostgreSQL
- MySQL
- SQLite
- MongoDB
- Redis

## Migration Features
- Schema generation
- Incremental migrations
- Rollback scripts
- Data seeding
```

## Hooks

### Pre-Commit Hook
**File**: `hooks/pre-commit.sh`
```bash
#!/bin/bash
# Validate code quality before committing

# Run linters
npm run lint:frontend
npm run lint:backend

# Run tests
npm run test:unit
npm run test:integration

# Check build
npm run build

# Block commit if any step fails
exit $?
```

### Pre-Push Hook
**File**: `hooks/pre-push.sh`
```bash
#!/bin/bash
# Perform comprehensive checks before pushing

# Run full test suite
npm run test:all

# Run security vulnerability scan
npm audit

# Check bundle size
npm run size-check

# Block push if any check fails
exit $?
```

## MCP Servers
**File**: `.mcp.json`
```json
{
  "servers": {
    "local-database": {
      "transport": "stdio",
      "command": "npx",
      "args": ["mcp-postgres", "${DATABASE_URL}"],
      "description": "Local PostgreSQL access"
    },
    "cloud-api": {
      "transport": "http",
      "url": "https://api.company.com/mcp",
      "description": "Company cloud API integration"
    }
  }
}
```

## README
**File**: `README.md`
```markdown
# Full-Stack Development Kit

Accelerate full-stack development with integrated tooling and automation.

## Features
- Frontend Component Generation
- Backend API Scaffolding
- Database Model Creation
- Multi-Framework Support
- Comprehensive Testing

## Installation
\`\`\`bash
/plugin marketplace add fullstack-kit
/plugin install fullstack-kit
\`\`\`

## Commands
- `/fullstack-kit:frontend:component` - Create frontend components
- `/fullstack-kit:frontend:page` - Generate complete pages
- `/fullstack-kit:backend:endpoint` - Create backend endpoints
- `/fullstack-kit:backend:model` - Generate database models

## Skills
- `component-generator`
- `api-generator`
- `db-migration`
```

## When to Use This Plugin Pattern
- Microservices architectures
- Monorepo development
- Startups requiring rapid prototyping
- Enterprise with standardized tech stacks
- Teams with consistent development workflows

## Best Practices
- Keep templates framework-agnostic
- Support multiple technology stacks
- Provide flexible configuration
- Enforce code quality through hooks
- Generate human-readable, maintainable code
```