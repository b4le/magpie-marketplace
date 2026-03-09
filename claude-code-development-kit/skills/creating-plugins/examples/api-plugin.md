# API Development Plugin Example

## Overview
A comprehensive toolkit for API development, offering endpoint creation, documentation generation, and API testing capabilities.

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

## Plugin Configuration
**File**: `.claude-plugin/plugin.json`
```json
{
  "name": "api-toolkit",
  "version": "1.2.0",
  "description": "Comprehensive API development and documentation toolkit",
  "author": { "name": "Backend Engineering Team", "email": "backend@company.com" },
  "keywords": ["api", "openapi", "documentation", "typescript"],
  "dependencies": {
    "typescript-toolkit": "^1.0.0"
  }
}
```

## Commands

### New Endpoint Command
**File**: `commands/new-endpoint.md`
```markdown
---
description: Create a new API endpoint with TypeScript and OpenAPI spec
argument-hint: [endpoint-name] [method]
---

Generate a complete API endpoint including:
- TypeScript implementation
- OpenAPI specification
- Validation schema
- Example test cases

### Usage
\`\`\`bash
/api-toolkit:new-endpoint UserProfile GET
\`\`\`

### Options
- First argument: Endpoint name
- Second argument: HTTP method (GET, POST, PUT, DELETE)
```

### Documentation Generation Command
**File**: `commands/generate-docs.md`
```markdown
---
description: Generate API documentation from OpenAPI/Swagger specs
---

Create comprehensive API documentation from existing specification files.

### Usage
\`\`\`bash
/api-toolkit:generate-docs
\`\`\`

### Output Formats
- HTML
- Markdown
- PDF
- Interactive Swagger UI
```

### API Testing Command
**File**: `commands/test-api.md`
```markdown
---
description: Run API integration and contract tests
---

Execute comprehensive API testing suite:
- Contract tests
- Integration tests
- Performance tests

### Usage
\`\`\`bash
/api-toolkit:test-api
\`\`\`

### Options
- `--coverage`: Generate test coverage report
- `--verbose`: Detailed test output
```

## API Generator Skill
**File**: `skills/api-generator/SKILL.md`
```yaml
---
name: api-generator
description: Automatically generate API endpoints, models, and validation schemas
---

# API Endpoint Generator Skill

## Supported Languages
- TypeScript
- Python
- Go
- Java

## Generation Capabilities
- CRUD endpoint scaffolding
- Request/response models
- Input validation
- Error handling templates
```

## OpenAPI Docs Skill
**File**: `skills/openapi-docs/SKILL.md`
```yaml
---
name: openapi-docs
description: Convert API specifications to comprehensive documentation
---

# OpenAPI Documentation Skill

## Supported Specification Formats
- OpenAPI 3.0
- Swagger 2.0
- JSON Schema

## Documentation Outputs
- Interactive API explorer
- Markdown reference
- Static HTML site
- PDF documentation
```

## Templates
### Endpoint Template (`templates/endpoint.ts`)
```typescript
import { APIGatewayProxyHandler } from 'aws-lambda';
import { validate } from './validator';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const validatedData = validate(event.body);
    // Implement endpoint logic
    return {
      statusCode: 200,
      body: JSON.stringify(validatedData)
    };
  } catch (error) {
    return {
      statusCode: 400,
      body: JSON.stringify({ error: error.message })
    };
  }
};
```

### OpenAPI Template (`templates/openapi.yaml`)
```yaml
openapi: 3.0.0
info:
  title: Example API
  version: 1.0.0
paths:
  /example:
    get:
      summary: Example endpoint
      responses:
        '200':
          description: Successful response
```

## README
**File**: `README.md`
```markdown
# API Toolkit Plugin

Streamline API development with automated tools for endpoint creation, documentation, and testing.

## Features
- API Endpoint Generation
- OpenAPI/Swagger Documentation
- Comprehensive API Testing
- Multi-language Support

## Installation
\`\`\`bash
/plugin marketplace add api-toolkit
/plugin install api-toolkit
\`\`\`

## Commands
- `/api-toolkit:new-endpoint` - Create API endpoints
- `/api-toolkit:generate-docs` - Generate API documentation
- `/api-toolkit:test-api` - Run API tests

## Skills
- `api-generator` - Generate API endpoints
- `openapi-docs` - Create API documentation
```

## When to Use This Plugin Pattern
- Microservices architectures
- API-first development approaches
- Teams with standardized API design
- Organizations requiring consistent documentation
- Projects with multiple API implementations

## Best Practices
- Keep templates language-agnostic
- Support multiple specification formats
- Generate human-readable documentation
- Provide flexible configuration options
```