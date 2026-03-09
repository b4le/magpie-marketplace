# API Toolkit Plugin

## Overview

The API Toolkit plugin provides a comprehensive set of tools for API development, including endpoint generation, OpenAPI documentation, and API testing capabilities.

## Features

### Commands

- `/api-toolkit:new-endpoint` - Create a new API endpoint with boilerplate code
- `/api-toolkit:generate-docs` - Generate OpenAPI/Swagger documentation
- `/api-toolkit:test-api` - Run API integration and contract tests

### Skills

- `api-generator` - Dynamically generate API endpoints based on specifications
- `openapi-docs` - Create and validate OpenAPI documentation

## Plugin Structure

```
api-toolkit/
├── .claude-plugin/
│   └── plugin.json
├── commands/
│   ├── new-endpoint.md
│   ├── generate-docs.md
│   └── test-api.md
├── skills/
│   ├── api-generator/
│   │   └── SKILL.md
│   └── openapi-docs/
│       └── SKILL.md
└── templates/
    ├── endpoint.ts
    ├── test.spec.ts
    └── openapi.yaml
```

## Installation

```bash
/plugin marketplace add github https://github.com/company/api-toolkit
/plugin install api-toolkit@github
```

## Usage Examples

### Creating a New Endpoint

```bash
# Create a REST endpoint for user management
/api-toolkit:new-endpoint --type=rest --name=users --methods=GET,POST,PUT,DELETE
```

### Generating API Documentation

```bash
# Generate OpenAPI 3.0 documentation
/api-toolkit:generate-docs --format=openapi3 --output=docs/api-spec.yaml
```

### Running API Tests

```bash
# Run all API tests
/api-toolkit:test-api

# Test specific endpoint or service
/api-toolkit:test-api --service=user-management
```

## Configuration

Configure API toolkit behavior in your project's `.claude/settings.json`:

```json
{
  "api-toolkit": {
    "defaultLanguage": "typescript",
    "openapi": {
      "version": "3.0.0",
      "basePath": "/api/v1"
    },
    "testFramework": "supertest"
  }
}
```

## Requirements

- Claude Code version 1.5.0 or higher
- Project must have a supported API framework (Express, Koa, NestJS, etc.)
- TypeScript recommended

## License

Apache-2.0 License

## Contributing

1. Fork the repository
2. Create a new branch
3. Make your changes
4. Submit a pull request