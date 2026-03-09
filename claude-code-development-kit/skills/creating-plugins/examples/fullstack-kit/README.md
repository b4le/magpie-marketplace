# Full-Stack Development Kit Plugin

## Overview

The Full-Stack Development Kit plugin provides a comprehensive toolkit for full-stack development, offering code generation, component scaffolding, and development workflow tools for both frontend and backend.

## Features

### Frontend Commands

- `/fullstack-kit:frontend:component` - Generate React components
- `/fullstack-kit:frontend:page` - Create new page components
- `/fullstack-kit:frontend:storybook` - Generate Storybook stories

### Backend Commands

- `/fullstack-kit:backend:endpoint` - Create new API endpoints
- `/fullstack-kit:backend:model` - Generate database models

### Development Hooks

- Pre-commit linting and testing
- Pre-push validation
- Automatic code formatting

### Skills

- `component-generator` - Dynamically generate React components
- `api-generator` - Create backend API endpoints and models
- `db-migration` - Manage database schema migrations

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

## Installation

```bash
/plugin marketplace add github https://github.com/company/fullstack-kit
/plugin install fullstack-kit@github
```

## Usage Examples

### Creating a React Component

```bash
# Generate a new React component with TypeScript
/fullstack-kit:frontend:component --name=UserProfile --type=functional
```

### Creating a Backend Endpoint

```bash
# Generate a new REST API endpoint
/fullstack-kit:backend:endpoint --name=users --type=resource --methods=GET,POST
```

### Database Migration

```bash
# Create a new database migration
/fullstack-kit:db:migrate --create-table=users
```

## Configuration

Configure full-stack development settings in your project's `.claude/settings.json`:

```json
{
  "fullstack-kit": {
    "frontend": {
      "framework": "react",
      "typescript": true,
      "styledComponents": true
    },
    "backend": {
      "framework": "express",
      "database": "postgresql",
      "orm": "prisma"
    },
    "testing": {
      "frontend": "jest",
      "backend": "mocha",
      "e2e": "cypress"
    }
  }
}
```

## Development Workflow

1. Generate components and endpoints
2. Automatically run linters and tests via Git hooks
3. Build and deploy

## Requirements

- Claude Code version 2.0.0 or higher
- React (frontend)
- Node.js with TypeScript (backend)
- PostgreSQL or supported database

## Integrated Plugins

- Requires `api-toolkit` plugin for API development features

## License

MIT License

## Contributing

1. Fork the repository
2. Create a new branch
3. Make your changes
4. Submit a pull request