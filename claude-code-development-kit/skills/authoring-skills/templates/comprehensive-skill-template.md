# Comprehensive Skill Template

Use this template for complex skills that require extensive documentation, multiple workflows, or supporting materials.

## Template Structure

```
skill-name/
├── SKILL.md
├── templates/
│   ├── template-1.ext
│   └── template-2.ext
├── examples/
│   ├── example-1.md
│   └── example-2.md
├── reference/
│   ├── detailed-guide.md
│   └── api-reference.md
└── scripts/
    └── helper.sh
```

## SKILL.md Template

```yaml
---
name: skill-name
description: Comprehensive description of what the skill does, key features, and when to use it. Use when [trigger 1], [trigger 2], [trigger 3], or [trigger 4].
allowed-tools:
  - Read
  - Write
  - Edit
---

# Skill Name

Brief overview of the skill's purpose and capabilities.

## Quick Reference

### Key Capabilities
- Capability 1
- Capability 2
- Capability 3

### Common Use Cases
1. Use case 1
2. Use case 2
3. Use case 3

## Workflows

### Workflow 1: [Name]

**When to use**: [Context]

**Steps**:
1. Step 1
2. Step 2
3. Step 3

**Example**: @examples/workflow-1.md

### Workflow 2: [Name]

**When to use**: [Context]

**Steps**:
1. Step 1
2. Step 2
3. Step 3

**Example**: @examples/workflow-2.md

## Templates

### Template 1
@templates/template-1.ext

**Usage**:
1. How to use template 1
2. Customization points
3. Validation steps

### Template 2
@templates/template-2.ext

**Usage**:
1. How to use template 2
2. Customization points
3. Validation steps

## Validation Checklist

### Pre-execution
- [ ] Check 1
- [ ] Check 2

### Post-execution
- [ ] Verify 1
- [ ] Verify 2

## Detailed Documentation

### Architecture
@reference/architecture.md

### API Reference
@reference/api-reference.md

### Best Practices
@reference/best-practices.md

## Troubleshooting

### Issue 1
**Symptom**: Description
**Solution**: Steps to fix

### Issue 2
**Symptom**: Description
**Solution**: Steps to fix

## Version History

### v1.0.0 (YYYY-MM-DD)
- Initial release
- Feature 1
- Feature 2
```

## When to Use This Template

Use the comprehensive template for:
- **Complex workflows** (multiple steps, branching logic)
- **Multiple sub-capabilities** (different modes or approaches)
- **Large templates** (code scaffolding, configuration files)
- **Extensive reference material** (API docs, architectural guides)
- **Multiple examples** (various use cases and scenarios)

## Supporting File Templates

### templates/template-file.ext

Store reusable templates here:

```typescript
// templates/component-template.tsx

import React from 'react';

interface {{ComponentName}}Props {
  // Props definition
}

export const {{ComponentName}}: React.FC<{{ComponentName}}Props> = (props) => {
  return (
    <div>
      {/* Component implementation */}
    </div>
  );
};
```

### examples/example.md

Store detailed examples:

```markdown
# Example: Creating a User Dashboard Component

## Context

This example demonstrates creating a complex dashboard component with multiple sub-components.

## Input

User request: "Create a user dashboard with profile card, activity feed, and stats widgets"

## Process

1. Generate main Dashboard component
2. Create ProfileCard sub-component
3. Create ActivityFeed sub-component
4. Create StatsWidget sub-component
5. Compose components in Dashboard
6. Add tests for each component

## Output

[Generated code files and structure]

## Validation

[How to verify the output is correct]
```

### reference/detailed-guide.md

Store detailed reference material:

```markdown
# Detailed Component Generation Guide

## Component Types

### Functional Components

Characteristics:
- Use React hooks
- Simpler syntax
- Better performance
- Recommended for new code

[Detailed explanation and examples]

### Class Components

Characteristics:
- Legacy pattern
- Lifecycle methods
- Used in older codebases

[Detailed explanation and examples]

## Patterns

### Container/Presenter Pattern

[Explanation and examples]

### Compound Components

[Explanation and examples]
```

## Complete Example

### SKILL.md

```yaml
---
name: generating-react-applications
description: Scaffolds complete React applications with TypeScript, routing, state management, and testing setup. Use when creating new React apps, initializing projects, or setting up React development environments.
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
---

# Generating React Applications

Complete scaffolding solution for React applications with modern tooling and best practices.

## Quick Reference

### Key Capabilities
- Project initialization with Vite or Create React App
- TypeScript configuration
- React Router setup
- State management (Redux Toolkit, Zustand, or Context)
- Testing setup (Jest, React Testing Library)
- Styling solution (Tailwind, styled-components, or CSS Modules)

### Common Use Cases
1. New greenfield React project
2. Migrating existing app to TypeScript
3. Adding state management to existing app
4. Setting up testing infrastructure

## Workflows

### Workflow 1: New Project from Scratch

**When to use**: Starting a brand new React application

**Steps**:
1. Choose build tool (Vite recommended for new projects)
2. Initialize project: `npm create vite@latest`
3. Configure TypeScript: @templates/tsconfig.json
4. Set up routing: @templates/router-setup.tsx
5. Configure state management: @templates/store-setup.ts
6. Add testing: @templates/test-setup.ts
7. Configure linting: @templates/eslint-config.js

**Example**: @examples/new-project.md

### Workflow 2: Add State Management

**When to use**: Adding Redux Toolkit to existing app

**Steps**:
1. Install dependencies: `npm install @reduxjs/toolkit react-redux`
2. Create store: @templates/store.ts
3. Create slices: @templates/slice-template.ts
4. Configure provider: @templates/provider-setup.tsx
5. Add hooks: @templates/hooks.ts

**Example**: @examples/add-redux.md

## Templates

### TypeScript Configuration
@templates/tsconfig.json

**Usage**:
1. Copy to project root
2. Adjust `include` and `exclude` paths
3. Modify `compilerOptions` for project needs

### Router Setup
@templates/router-setup.tsx

**Usage**:
1. Create `src/routes/index.tsx`
2. Define route configuration
3. Add to main App component

### Store Setup (Redux Toolkit)
@templates/store-setup.ts

**Usage**:
1. Create `src/store/index.ts`
2. Configure middleware
3. Export typed hooks

## Validation Checklist

### Pre-execution
- [ ] Node.js version >= 18
- [ ] npm/yarn available
- [ ] Project name is valid
- [ ] Target directory is empty or doesn't exist

### Post-execution
- [ ] All dependencies installed
- [ ] TypeScript compiles without errors
- [ ] Tests run successfully
- [ ] Development server starts
- [ ] Build succeeds

## Detailed Documentation

### Architecture Decisions
@reference/architecture.md

### TypeScript Best Practices
@reference/typescript-guide.md

### State Management Patterns
@reference/state-management.md

### Testing Strategies
@reference/testing-guide.md

## Troubleshooting

### Issue: TypeScript Errors After Setup
**Symptom**: Red squiggly lines in editor, tsc errors
**Solution**:
1. Restart TypeScript server
2. Check tsconfig.json paths
3. Verify @types packages installed

### Issue: Tests Failing to Run
**Symptom**: Jest configuration errors
**Solution**:
1. Check jest.config.js exists
2. Verify test setup file
3. Install missing @testing-library packages

### Issue: Build Optimization
**Symptom**: Large bundle size
**Solution**:
1. Check bundle analyzer output
2. Enable code splitting
3. Use dynamic imports for routes

## Version History

### v2.0.0 (2025-01-15)
- Added Vite support (recommended over CRA)
- Updated to React 18
- Added Zustand as state management option

### v1.0.0 (2024-11-01)
- Initial release
- Create React App support
- Redux Toolkit integration
- Jest and RTL setup
```

### Supporting Files

**templates/tsconfig.json**:
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true
  },
  "include": ["src"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
```

**examples/new-project.md**:
```markdown
# Example: Creating a New React App

## User Request

"Create a new React app with TypeScript, React Router, and Tailwind CSS"

## Execution Steps

1. Initialize with Vite:
   \`\`\`bash
   npm create vite@latest my-app -- --template react-ts
   cd my-app
   \`\`\`

2. Install additional dependencies:
   \`\`\`bash
   npm install react-router-dom
   npm install -D tailwindcss postcss autoprefixer
   npx tailwindcss init -p
   \`\`\`

3. Configure Tailwind (tailwind.config.js):
   \`\`\`javascript
   export default {
     content: [
       "./index.html",
       "./src/**/*.{js,ts,jsx,tsx}",
     ],
     theme: { extend: {} },
     plugins: [],
   }
   \`\`\`

4. Add Tailwind directives (src/index.css):
   \`\`\`css
   @tailwind base;
   @tailwind components;
   @tailwind utilities;
   \`\`\`

5. Set up routes (src/routes/index.tsx):
   [Router setup code]

6. Update App.tsx to use router

7. Verify:
   \`\`\`bash
   npm run dev
   \`\`\`

## Result

Complete React application with:
- ✓ TypeScript configured
- ✓ React Router integrated
- ✓ Tailwind CSS working
- ✓ Development server running
- ✓ Hot module replacement active
```

## Line Count Management

Target: **Keep SKILL.md under 500 lines**

Strategy:
- SKILL.md: 200-400 lines (quick reference, workflows, checklists)
- Supporting files: Unlimited

Content distribution:
- **SKILL.md**: Overview, workflows, quick reference, validation
- **templates/**: Code templates, configuration files
- **examples/**: Detailed walkthroughs, use cases
- **reference/**: Architecture docs, API reference, best practices
- **scripts/**: Helper scripts, automation tools

## Version History

### v1.0.0 (2025-11-17)
- Initial template creation
- Added complete React app example
- Included supporting file templates
