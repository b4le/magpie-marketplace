# Example: API Documentation Skill

Complete example of a documentation skill for generating OpenAPI/Swagger documentation.

## SKILL.md

```yaml
---
name: documenting-apis
description: Generates OpenAPI 3.0 documentation for REST endpoints with schemas, examples, and authentication details. Use when documenting APIs, creating Swagger specs, or generating API documentation.
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
---

# Documenting APIs

Creates comprehensive OpenAPI 3.0 documentation for REST API endpoints.

## Quick Steps

1. Read endpoint handler code
2. Extract HTTP method, path, parameters, and body
3. Generate OpenAPI schema
4. Add request/response examples
5. Document authentication requirements
6. Add error responses

## OpenAPI Template

\`\`\`yaml
paths:
  /api/{resource}:
    {method}:
      summary: Brief description
      description: Detailed description
      tags:
        - {Tag}
      parameters:
        - name: {param}
          in: {location}
          required: {boolean}
          schema:
            type: {type}
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/{Schema}'
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/{ResponseSchema}'
        '400':
          description: Bad request
        '401':
          description: Unauthorized
        '500':
          description: Internal server error
\`\`\`

## Validation Checklist

- [ ] HTTP method and path documented
- [ ] All parameters included with types
- [ ] Request body schema defined
- [ ] Success response documented
- [ ] Error responses included
- [ ] Examples provided
- [ ] Authentication noted (if required)
- [ ] Tags assigned for grouping

## Detailed Guide

@reference/openapi-guide.md

## Examples

@examples/documented-endpoints.md
```

## Supporting Files

### reference/openapi-guide.md

```markdown
# OpenAPI 3.0 Documentation Guide

## Structure

OpenAPI documents consist of:

1. **Info**: API metadata
2. **Servers**: API server URLs
3. **Paths**: Endpoint definitions
4. **Components**: Reusable schemas
5. **Security**: Authentication schemes

## Path Definition

Each endpoint includes:

- **HTTP method**: GET, POST, PUT, DELETE, PATCH
- **Summary**: One-line description
- **Description**: Detailed explanation
- **Parameters**: Path, query, header parameters
- **Request body**: Payload schema
- **Responses**: Status codes and schemas

## Schema Definition

Schemas define data structures:

\`\`\`yaml
components:
  schemas:
    User:
      type: object
      required:
        - id
        - email
      properties:
        id:
          type: string
          format: uuid
          description: Unique user identifier
        email:
          type: string
          format: email
          description: User email address
        name:
          type: string
          description: User display name
\`\`\`

## Parameter Types

### Path Parameters

\`\`\`yaml
parameters:
  - name: userId
    in: path
    required: true
    schema:
      type: string
      format: uuid
\`\`\`

### Query Parameters

\`\`\`yaml
parameters:
  - name: page
    in: query
    required: false
    schema:
      type: integer
      default: 1
\`\`\`

### Header Parameters

\`\`\`yaml
parameters:
  - name: X-API-Key
    in: header
    required: true
    schema:
      type: string
\`\`\`

## Response Codes

Standard HTTP status codes:

- **200**: Success
- **201**: Created
- **204**: No content
- **400**: Bad request
- **401**: Unauthorized
- **403**: Forbidden
- **404**: Not found
- **500**: Internal server error

## Authentication

Document security schemes:

\`\`\`yaml
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT

security:
  - bearerAuth: []
\`\`\`
```

### examples/documented-endpoints.md

```markdown
# Example: Documenting User Management API

## Source Code

\`\`\`typescript
// routes/users.ts
router.get('/users/:id', authenticate, async (req, res) => {
  const { id } = req.params;
  const user = await userService.getById(id);
  res.json({ success: true, data: user });
});

router.post('/users', authenticate, validate('createUser'), async (req, res) => {
  const { email, name } = req.body;
  const user = await userService.create({ email, name });
  res.status(201).json({ success: true, data: user });
});
\`\`\`

## Generated Documentation

\`\`\`yaml
openapi: 3.0.0
info:
  title: User Management API
  version: 1.0.0
  description: API for managing user accounts

servers:
  - url: https://api.example.com/v1
    description: Production server
  - url: http://localhost:3000/v1
    description: Development server

paths:
  /users/{id}:
    get:
      summary: Get user by ID
      description: Retrieves a single user by their unique identifier
      tags:
        - Users
      parameters:
        - name: id
          in: path
          required: true
          description: User ID
          schema:
            type: string
            format: uuid
          example: "123e4567-e89b-12d3-a456-426614174000"
      responses:
        '200':
          description: User retrieved successfully
          content:
            application/json:
              schema:
                type: object
                properties:
                  success:
                    type: boolean
                    example: true
                  data:
                    $ref: '#/components/schemas/User'
              example:
                success: true
                data:
                  id: "123e4567-e89b-12d3-a456-426614174000"
                  email: "john.doe@example.com"
                  name: "John Doe"
                  createdAt: "2025-01-15T10:30:00Z"
        '401':
          description: Unauthorized
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'
        '404':
          description: User not found
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'
        '500':
          description: Internal server error
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'
      security:
        - bearerAuth: []

  /users:
    post:
      summary: Create new user
      description: Creates a new user account with email and name
      tags:
        - Users
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - email
                - name
              properties:
                email:
                  type: string
                  format: email
                  description: User email address
                name:
                  type: string
                  description: User display name
            example:
              email: "jane.doe@example.com"
              name: "Jane Doe"
      responses:
        '201':
          description: User created successfully
          content:
            application/json:
              schema:
                type: object
                properties:
                  success:
                    type: boolean
                    example: true
                  data:
                    $ref: '#/components/schemas/User'
              example:
                success: true
                data:
                  id: "987e6543-e21b-43d1-a654-426614174111"
                  email: "jane.doe@example.com"
                  name: "Jane Doe"
                  createdAt: "2025-01-15T11:00:00Z"
        '400':
          description: Invalid input
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'
        '401':
          description: Unauthorized
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'
        '500':
          description: Internal server error
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'
      security:
        - bearerAuth: []

components:
  schemas:
    User:
      type: object
      required:
        - id
        - email
        - name
      properties:
        id:
          type: string
          format: uuid
          description: Unique user identifier
        email:
          type: string
          format: email
          description: User email address
        name:
          type: string
          description: User display name
        createdAt:
          type: string
          format: date-time
          description: Account creation timestamp
      example:
        id: "123e4567-e89b-12d3-a456-426614174000"
        email: "user@example.com"
        name: "User Name"
        createdAt: "2025-01-15T10:30:00Z"

    Error:
      type: object
      required:
        - success
        - error
      properties:
        success:
          type: boolean
          example: false
        error:
          type: string
          description: Error message
      example:
        success: false
        error: "User not found"

  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
      description: JWT authentication token
\`\`\`
```

## Example Usage

### User Request

"Document the GET /api/products/:id endpoint"

### Source Code Analysis

```typescript
// routes/products.ts
router.get('/products/:id', async (req, res) => {
  const { id } = req.params;
  const { include } = req.query;

  const product = await productService.getById(id, {
    includeReviews: include?.includes('reviews'),
    includeImages: include?.includes('images'),
  });

  if (!product) {
    return res.status(404).json({ error: 'Product not found' });
  }

  res.json(product);
});
```

### Generated Documentation

```yaml
paths:
  /products/{id}:
    get:
      summary: Get product by ID
      description: Retrieves a single product with optional related data (reviews, images)
      tags:
        - Products
      parameters:
        - name: id
          in: path
          required: true
          description: Product ID
          schema:
            type: string
            pattern: '^[0-9]+$'
          example: "12345"
        - name: include
          in: query
          required: false
          description: Related data to include (comma-separated)
          schema:
            type: string
            enum:
              - reviews
              - images
              - reviews,images
          example: "reviews,images"
      responses:
        '200':
          description: Product retrieved successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Product'
              example:
                id: "12345"
                name: "Wireless Headphones"
                price: 99.99
                description: "High-quality wireless headphones"
                reviews: [...]
                images: [...]
        '404':
          description: Product not found
          content:
            application/json:
              schema:
                type: object
                properties:
                  error:
                    type: string
              example:
                error: "Product not found"
```

## Key Learnings

### What Makes This Skill Effective

1. **Read-only tools** ensure no code modifications during documentation

2. **Complete templates** cover all OpenAPI components

3. **Examples** show real-world API documentation

4. **Validation checklist** ensures completeness

5. **Reference material** provides OpenAPI best practices

### Progressive Disclosure

The skill uses:
- Quick template in SKILL.md
- Detailed OpenAPI guide in reference/
- Complete examples in examples/

This keeps SKILL.md under 500 lines while providing comprehensive guidance.

### Description Effectiveness

Trigger phrases that work well:
- "document the API"
- "create OpenAPI spec"
- "generate Swagger docs"
- "document endpoint"

## Adaptation Tips

To adapt this skill for your project:

1. **Update schema references** to match your data models
2. **Modify authentication** to match your auth scheme (OAuth, API keys, etc.)
3. **Add project-specific tags** for endpoint grouping
4. **Include custom headers** if your API uses them
5. **Update server URLs** to match your environments

## Version History

### v1.0.0 (2025-11-17)
- Initial example creation
- OpenAPI 3.0 focus
- Complete user and product examples
