# Refactoring Template

## Purpose
A structured approach to refactoring code while maintaining functionality and ensuring quality through incremental changes.

## Usage
Use this template when requesting code refactoring to ensure changes are systematic, tested, and don't break existing functionality.

**Best for:**
- Code cleanup
- Performance improvements
- Modernization
- Technical debt reduction

**Warning:** Always run tests after each incremental change to catch regressions early.

## Template

```
Refactor [component/module] to improve [specific aspect].

Current issues:
- [Issue 1]
- [Issue 2]
- [Issue 3]

Goals:
- [Goal 1]
- [Goal 2]
- [Goal 3]

Constraints:
- Maintain existing API/interface
- Don't break existing tests (update if necessary)
- Follow project patterns

Process:
1. Analyze current implementation
2. Plan refactoring approach
3. Implement changes incrementally
4. Run tests after each change
5. Update documentation

Stop if tests fail - fix before proceeding.
```
