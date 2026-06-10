# Example: API Endpoint Generator

**File**: `.claude/commands/api/new-endpoint.md`

```markdown
---
description: Generate new API endpoint
argument-hint: [method] [path] [description]
---

Create a new API endpoint:
- Method: $1
- Path: $2
- Description: $3

Follow the API patterns in @docs/api-conventions.md.

Include:
- Route handler with validation
- Request/response types
- Error handling
- OpenAPI documentation
- Unit tests

Place in the appropriate directory based on existing structure.
```

**Usage**: `/api:new-endpoint POST /api/users/profile "Update user profile"`
