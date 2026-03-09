# Minimal Skill Template

Use this template for simple, focused skills that don't require extensive documentation.

## Template

```yaml
---
name: skill-name
description: Clear description of what the skill does and when to use it. Use when [trigger phrase 1], [trigger phrase 2], or [trigger phrase 3].
---

# Skill Name

## Quick Steps

1. First step
2. Second step
3. Third step

## Example

\`\`\`language
// Code example here
\`\`\`

## Validation

- [ ] Check item 1
- [ ] Check item 2
- [ ] Check item 3
```

## Usage

1. Copy this template to your skill directory
2. Replace `skill-name` with a descriptive lowercase hyphenated name (e.g., `generating-components`, `api-documentation`, `test-runner`)
3. Write a 200-400 character description with trigger phrases
4. Fill in the steps, example, and validation checklist
5. Keep total under 500 lines

## When to Use This Template

Use the minimal template for:
- **Simple workflows** (3-5 steps)
- **Single-purpose skills** (one clear capability)
- **Quick reference** (no extensive documentation needed)
- **Template-based generation** (with inline templates)

## When NOT to Use This Template

Don't use minimal template for:
- Complex workflows requiring detailed explanation
- Skills with multiple sub-capabilities
- Skills needing extensive examples
- Skills with large templates or reference material

For those cases, use the comprehensive template instead.

## Examples

### Code Generation Skill

```yaml
---
name: generating-api-routes
description: Creates Express.js API routes with validation and error handling. Use when creating API endpoints, adding routes, or scaffolding REST services.
---

# Generating API Routes

## Quick Steps

1. Create route file in `src/routes/{name}.ts`
2. Import Express and validation middleware
3. Define route handlers with try/catch
4. Add input validation
5. Export router

## Example

\`\`\`typescript
import { Router } from 'express';
import { validate } from '../middleware/validation';

const router = Router();

router.get('/users/:id', validate('getUserById'), async (req, res) => {
  try {
    const user = await userService.getById(req.params.id);
    res.json({ success: true, data: user });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

export default router;
\`\`\`

## Validation

- [ ] Route file created in correct location
- [ ] Validation middleware applied
- [ ] Error handling implemented
- [ ] Response format consistent
- [ ] Router exported
```

### Analysis Skill

```yaml
---
name: analyzing-bundle-size
description: Analyzes JavaScript bundle size and identifies large dependencies. Use when optimizing bundle size or investigating large builds.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# Analyzing Bundle Size

## Quick Steps

1. Run bundle analyzer: `npm run build -- --analyze`
2. Review bundle composition report
3. Identify largest dependencies (>100KB)
4. Check for duplicate dependencies
5. Suggest optimizations (lazy loading, code splitting)

## Example Output

\`\`\`
Bundle Analysis Results:

Largest Dependencies:
- moment.js: 285KB (consider date-fns: 12KB)
- lodash: 245KB (use lodash-es with tree-shaking)
- chart.js: 180KB (lazy load)

Recommendations:
1. Replace moment.js with date-fns (save 273KB)
2. Use lodash-es for tree-shaking (save ~200KB)
3. Lazy load chart.js when needed
\`\`\`

## Validation

- [ ] Bundle size calculated
- [ ] Top 5 dependencies identified
- [ ] Alternatives suggested for large deps
- [ ] Code splitting opportunities noted
- [ ] Estimated size savings provided
```

### Documentation Skill

```yaml
---
name: documenting-functions
description: Generates JSDoc comments for JavaScript and TypeScript functions. Use when adding documentation, documenting APIs, or creating JSDoc comments.
---

# Documenting Functions

## Quick Steps

1. Read function signature
2. Identify parameters and return type
3. Generate JSDoc with description, params, returns, examples
4. Add throws clause if function throws errors
5. Include examples for complex functions

## Example

\`\`\`typescript
/**
 * Fetches user data from the API
 *
 * @param {string} userId - The unique identifier for the user
 * @param {Object} options - Optional configuration
 * @param {boolean} options.includeProfile - Whether to include profile data
 * @returns {Promise<User>} The user object with requested data
 * @throws {NotFoundError} If user does not exist
 * @throws {APIError} If API request fails
 *
 * @example
 * const user = await fetchUser('123', { includeProfile: true });
 * console.log(user.name);
 */
async function fetchUser(userId: string, options: FetchOptions = {}): Promise<User> {
  // Implementation...
}
\`\`\`

## Validation

- [ ] Description is clear and concise
- [ ] All parameters documented with types
- [ ] Return type documented
- [ ] Throws clause included (if applicable)
- [ ] Example provided for complex functions
```

## File Structure

When using the minimal template, keep this simple structure:

```
skill-name/
└── SKILL.md
```

No supporting files needed for minimal skills.

## Line Count Guidelines

Target: **100-300 lines** for minimal skills

Breakdown:
- YAML frontmatter: ~10 lines
- Quick reference: ~20 lines
- Steps: ~30 lines
- Example: ~40 lines
- Validation: ~20 lines
- Miscellaneous: ~80 lines

Total: ~200 lines (well under 500 limit)

## Version History

### v1.0.0 (2025-11-17)
- Initial template creation
- Added usage guidelines
- Included three complete examples
