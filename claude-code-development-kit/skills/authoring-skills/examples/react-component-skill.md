# Example: React Component Generation Skill

Complete example of a code generation skill for creating React components.

## SKILL.md

```yaml
---
name: generating-react-components
description: Creates React functional components with TypeScript, hooks, and accessibility features. Use when user asks to create a new component, generate a React file, scaffold UI elements, or add React components.
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

1. Determine component location based on type (page, layout, common)
2. Create component file: `{ComponentName}.tsx`
3. Create test file: `{ComponentName}.test.tsx`
4. Create styles file (if using CSS Modules): `{ComponentName}.module.css`
5. Export from index file

## Component Template

\`\`\`typescript
import React from 'react';
import styles from './{ComponentName}.module.css';

interface {ComponentName}Props {
  /**
   * Brief description of prop
   */
  propName: string;
}

/**
 * {ComponentName} description
 *
 * @example
 * \`\`\`tsx
 * <{ComponentName} propName="value" />
 * \`\`\`
 */
export const {ComponentName}: React.FC<{ComponentName}Props> = ({
  propName,
}) => {
  return (
    <div className={styles.container}>
      {/* Component implementation */}
    </div>
  );
};
\`\`\`

## Test Template

\`\`\`typescript
import { render, screen } from '@testing-library/react';
import { {ComponentName} } from './{ComponentName}';

describe('{ComponentName}', () => {
  it('renders correctly', () => {
    render(<{ComponentName} propName="test" />);
    expect(screen.getByText('test')).toBeInTheDocument();
  });
});
\`\`\`

## Directory Structure

\`\`\`
src/
├── components/
│   ├── common/          # Reusable UI components
│   ├── layout/          # Layout components (Header, Footer)
│   └── pages/           # Page-specific components
\`\`\`

## Validation Checklist

- [ ] Component file created in correct directory
- [ ] TypeScript interface defined for props
- [ ] JSDoc comments added
- [ ] Test file created with basic tests
- [ ] Component exported from index file
- [ ] Accessibility attributes included (aria-label, role, etc.)
- [ ] Component follows naming convention (PascalCase)

## Accessibility Requirements

All components must include:
- Semantic HTML elements
- ARIA labels where needed
- Keyboard navigation support
- Focus management
- Color contrast compliance

## Version History

### v1.0.0 (2025-01-15)
- Initial release
- TypeScript support
- Testing template
- Accessibility guidelines
```

## Supporting Files

### templates/component.tsx

```typescript
import React from 'react';
import styles from './{{ComponentName}}.module.css';

interface {{ComponentName}}Props {
  /**
   * Brief description of prop
   */
  propName: string;
  /**
   * Optional description
   */
  optionalProp?: boolean;
}

/**
 * {{ComponentName}} component description
 *
 * @param props - Component props
 * @returns React component
 *
 * @example
 * ```tsx
 * <{{ComponentName}} propName="value" />
 * ```
 */
export const {{ComponentName}}: React.FC<{{ComponentName}}Props> = ({
  propName,
  optionalProp = false,
}) => {
  return (
    <div className={styles.container}>
      {/* Component implementation */}
      <p>{propName}</p>
    </div>
  );
};
```

### templates/test.tsx

```typescript
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { {{ComponentName}} } from './{{ComponentName}}';

describe('{{ComponentName}}', () => {
  it('renders correctly', () => {
    render(<{{ComponentName}} propName="test" />);
    expect(screen.getByText('test')).toBeInTheDocument();
  });

  it('handles user interaction', async () => {
    const user = userEvent.setup();
    render(<{{ComponentName}} propName="test" />);

    // Add interaction tests
  });

  it('applies correct accessibility attributes', () => {
    render(<{{ComponentName}} propName="test" />);
    // Check ARIA labels, roles, etc.
  });
});
```

### templates/styles.module.css

```css
.container {
  /* Component styles */
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

/* Add responsive styles */
@media (max-width: 768px) {
  .container {
    /* Mobile styles */
  }
}
```

## Example Usage

### User Request

"Create a UserCard component that displays user name, email, and avatar"

### Skill Execution

1. **Determine location**: `src/components/common/UserCard/`

2. **Create component file** (`UserCard.tsx`):

```typescript
import React from 'react';
import styles from './UserCard.module.css';

interface UserCardProps {
  /**
   * User's display name
   */
  name: string;
  /**
   * User's email address
   */
  email: string;
  /**
   * URL to user's avatar image
   */
  avatarUrl: string;
}

/**
 * UserCard displays user information with avatar
 *
 * @example
 * ```tsx
 * <UserCard
 *   name="John Doe"
 *   email="john@example.com"
 *   avatarUrl="/avatars/john.jpg"
 * />
 * ```
 */
export const UserCard: React.FC<UserCardProps> = ({
  name,
  email,
  avatarUrl,
}) => {
  return (
    <div className={styles.container} role="article" aria-label={`User card for ${name}`}>
      <img
        src={avatarUrl}
        alt={`${name}'s avatar`}
        className={styles.avatar}
      />
      <div className={styles.info}>
        <h3 className={styles.name}>{name}</h3>
        <p className={styles.email}>{email}</p>
      </div>
    </div>
  );
};
```

3. **Create test file** (`UserCard.test.tsx`):

```typescript
import { render, screen } from '@testing-library/react';
import { UserCard } from './UserCard';

describe('UserCard', () => {
  const defaultProps = {
    name: 'John Doe',
    email: 'john@example.com',
    avatarUrl: '/avatars/john.jpg',
  };

  it('renders user information correctly', () => {
    render(<UserCard {...defaultProps} />);

    expect(screen.getByText('John Doe')).toBeInTheDocument();
    expect(screen.getByText('john@example.com')).toBeInTheDocument();
    expect(screen.getByAltText("John Doe's avatar")).toBeInTheDocument();
  });

  it('has correct accessibility attributes', () => {
    render(<UserCard {...defaultProps} />);

    const container = screen.getByRole('article');
    expect(container).toHaveAttribute('aria-label', 'User card for John Doe');
  });

  it('displays avatar with correct src', () => {
    render(<UserCard {...defaultProps} />);

    const avatar = screen.getByAltText("John Doe's avatar");
    expect(avatar).toHaveAttribute('src', '/avatars/john.jpg');
  });
});
```

4. **Create styles** (`UserCard.module.css`):

```css
.container {
  display: flex;
  gap: 1rem;
  padding: 1rem;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  background: white;
}

.avatar {
  width: 64px;
  height: 64px;
  border-radius: 50%;
  object-fit: cover;
}

.info {
  display: flex;
  flex-direction: column;
  justify-content: center;
}

.name {
  margin: 0 0 0.25rem 0;
  font-size: 1.125rem;
  font-weight: 600;
  color: #333;
}

.email {
  margin: 0;
  font-size: 0.875rem;
  color: #666;
}

@media (max-width: 768px) {
  .container {
    flex-direction: column;
    align-items: center;
    text-align: center;
  }
}
```

5. **Export from index** (`src/components/common/index.ts`):

```typescript
export { UserCard } from './UserCard/UserCard';
```

### Validation

- [x] Component file created in `src/components/common/UserCard/`
- [x] TypeScript interface defined with JSDoc comments
- [x] Component has descriptive JSDoc with example
- [x] Test file created with three tests
- [x] Component exported from index file
- [x] Accessibility attributes included (role, aria-label, alt text)
- [x] Component follows naming convention (PascalCase)
- [x] Styles use CSS Modules
- [x] Responsive styles included

## Key Learnings

### What Makes This Skill Effective

1. **Clear description** with trigger phrases: "create a new component", "generate a React file", "scaffold UI elements"

2. **Complete templates** provided for:
   - Component code
   - Tests
   - Styles

3. **Validation checklist** ensures consistency

4. **Accessibility built-in** from the start

5. **Examples** show real-world usage

### Progressive Disclosure

The skill keeps SKILL.md focused by:
- Inline templates for quick reference
- External files for detailed templates
- Examples showing complete workflow
- Clear structure and organization

### Tool Restrictions

The skill allows:
- Read (to check existing components)
- Write (to create new files)
- Edit (to update index exports)
- Grep/Glob (to find component patterns)

This prevents accidental modifications while allowing necessary operations.

## Adaptation Tips

To adapt this skill for your project:

1. **Update directory structure** to match your project
2. **Modify templates** to use your styling solution (styled-components, Tailwind, etc.)
3. **Adjust naming conventions** if different from PascalCase
4. **Add project-specific requirements** (i18n, state management, etc.)
5. **Update test setup** to match your testing library

## Version History

### v1.0.0 (2025-11-17)
- Initial example creation
- Complete React component skill
- TypeScript and accessibility focus
