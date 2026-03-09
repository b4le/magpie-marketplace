# Common Use Cases

## 1. Code Review Workflows

```markdown
# pr-review.md
Review PR $1:

!gh pr view $1
!gh pr diff $1

Check for:
- Breaking changes
- Security issues
- Test coverage
- Documentation updates
```

## 2. Deployment Workflows

```markdown
# deploy.md
Deploy to $1:

!git status
!npm run test
!npm run build

Verify tests and build succeed, then deploy to $1.
```

## 3. Code Generation

```markdown
# new-component.md
Create React component: $1

Include:
- TypeScript types
- Props interface
- Default export
- CSS module
- Test file
- Storybook story
```

## 4. Analysis Tasks

```markdown
# analyze-performance.md
Analyze performance of $1:

Identify:
- Heavy computations
- Unnecessary re-renders
- Large imports
- Missing optimizations

Suggest improvements.
```

## 5. Refactoring Tasks

```markdown
# refactor.md
Refactor $1 to $2:

1. Analyze current implementation
2. Plan refactoring approach
3. Execute refactoring
4. Update tests
5. Verify functionality
```
