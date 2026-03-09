# Code Generation Skill Template

Template for skills that generate code (components, functions, tests, etc.).

## Template

```yaml
---
name: generating-{output-type}
description: Generates {what} with {key features}. Use when user asks to create {trigger 1}, {trigger 2}, or {trigger 3}.
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
---

# Generating {OutputType}

Brief description of what this skill generates and why.

## Quick Steps

1. Analyze requirements from user request
2. Determine file location based on project structure
3. Generate code from template
4. Add documentation (JSDoc, comments)
5. Create associated test file
6. Update exports/imports

## Template

\`\`\`{language}
// Code template here
// Use {{placeholders}} for variable parts
\`\`\`

## File Structure

\`\`\`
expected/directory/structure/
├── {OutputType}.{ext}
├── {OutputType}.test.{ext}
└── index.{ext}
\`\`\`

## Validation Checklist

- [ ] File created in correct location
- [ ] Code follows project conventions
- [ ] Documentation included
- [ ] Tests generated
- [ ] Exports updated
- [ ] No syntax errors

## Examples

### Example 1: Basic Case

**User Request**: "Create a simple {output}"

**Generated Output**:
\`\`\`{language}
// Example code
\`\`\`

### Example 2: Complex Case

**User Request**: "Create {output} with {features}"

**Generated Output**:
\`\`\`{language}
// Example code with features
\`\`\`

## Customization Points

1. **{Aspect 1}**: How to customize
2. **{Aspect 2}**: How to customize
3. **{Aspect 3}**: How to customize

## Detailed Templates

@templates/detailed-template.{ext}

## Version History

### v1.0.0 (YYYY-MM-DD)
- Initial release
```

## Usage Instructions

1. Replace `{output-type}` with what you're generating (components, endpoints, tests)
2. Replace `{language}` with the target language (typescript, python, etc.)
3. Fill in trigger phrases that users might say
4. Create actual code template with placeholders
5. Add 2-3 concrete examples
6. Include validation checklist

## Complete Example: React Component Generator

```yaml
---
name: generating-react-components
description: Generates React functional components with TypeScript, hooks, and styling. Use when user asks to create a component, generate a React file, or scaffold UI elements.
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
---

# Generating React Components

Creates production-ready React components following project conventions.

## Quick Steps

1. Analyze component requirements (props, behavior)
2. Determine component location (common, pages, layout)
3. Generate component from template
4. Add TypeScript interface for props
5. Create test file
6. Update component index

## Template

\`\`\`typescript
import React from 'react';
import styles from './{{ComponentName}}.module.css';

interface {{ComponentName}}Props {
  // Props interface
}

export const {{ComponentName}}: React.FC<{{ComponentName}}Props> = (props) => {
  return (
    <div className={styles.container}>
      {/* Component implementation */}
    </div>
  );
};
\`\`\`

## File Structure

\`\`\`
src/components/{category}/
├── {ComponentName}.tsx
├── {ComponentName}.test.tsx
├── {ComponentName}.module.css
└── index.ts
\`\`\`

## Validation Checklist

- [ ] Component file created in correct category
- [ ] TypeScript interface defined
- [ ] Props documented with JSDoc
- [ ] Test file generated with basic tests
- [ ] CSS module created
- [ ] Component exported from index
- [ ] Accessibility attributes included

## Examples

### Example 1: Simple Display Component

**User Request**: "Create a Card component with title and content props"

**Generated Output**:
\`\`\`typescript
import React from 'react';
import styles from './Card.module.css';

interface CardProps {
  /** Card title */
  title: string;
  /** Card content */
  content: string;
}

export const Card: React.FC<CardProps> = ({ title, content }) => {
  return (
    <div className={styles.container}>
      <h3 className={styles.title}>{title}</h3>
      <p className={styles.content}>{content}</p>
    </div>
  );
};
\`\`\`

### Example 2: Interactive Component

**User Request**: "Create a Button component with onClick handler and loading state"

**Generated Output**:
\`\`\`typescript
import React from 'react';
import styles from './Button.module.css';

interface ButtonProps {
  /** Button text */
  children: React.ReactNode;
  /** Click handler */
  onClick: () => void;
  /** Loading state */
  loading?: boolean;
  /** Button variant */
  variant?: 'primary' | 'secondary';
}

export const Button: React.FC<ButtonProps> = ({
  children,
  onClick,
  loading = false,
  variant = 'primary',
}) => {
  return (
    <button
      className={`${styles.button} ${styles[variant]}`}
      onClick={onClick}
      disabled={loading}
      aria-busy={loading}
    >
      {loading ? 'Loading...' : children}
    </button>
  );
};
\`\`\`

## Customization Points

1. **Styling Approach**: Change from CSS Modules to styled-components, Tailwind, etc.
2. **Component Type**: Use class components instead of functional
3. **State Management**: Add Redux, Zustand, or Context integration
4. **Accessibility**: Add ARIA attributes based on component type

## Version History

### v1.0.0 (2025-01-15)
- Initial release with TypeScript and CSS Modules support
```

## Key Features of Code Generation Skills

1. **Clear Templates**: Provide copy-paste ready code templates
2. **Validation**: Include checklists to ensure quality
3. **Examples**: Show both simple and complex cases
4. **Customization**: Note what can be adapted to project needs
5. **File Structure**: Show where files should be created
6. **Tests**: Always include test generation

## Common Patterns

### Function Generator

```yaml
name: generating-api-endpoints
description: Generates Express.js API endpoint handlers with validation and error handling
```

### Test Generator

```yaml
name: generating-unit-tests
description: Creates Jest unit tests with mocks and assertions for functions
```

### Configuration Generator

```yaml
name: generating-config-files
description: Creates configuration files (TypeScript, ESLint, Prettier) following best practices
```

## Version History

### v1.0.0 (2025-11-17)
- Initial template creation
- Added React component example
- Included usage instructions
