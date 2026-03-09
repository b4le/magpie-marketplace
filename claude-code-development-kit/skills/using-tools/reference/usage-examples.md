# Tool Usage Examples - Practical Demonstrations

Real-world examples showing correct tool usage patterns.

---

## Example 1: Reading Multiple Configuration Files

**Scenario**: Need to review database, API, and app configuration.

**Approach**: Parallel execution (files are independent)

**Implementation**:
```
In one message, make three Read calls:
- Read config/database.json
- Read config/api.json
- Read config/app.json

[All execute in parallel]
```

**Why Parallel**: The files don't depend on each other, so reading them simultaneously is faster.

**Result**: All three file contents returned in one response.

---

## Example 2: Finding and Reading TODO Comments

**Scenario**: Find all files with TODO comments, then read them.

**Approach**: Sequential execution (reading depends on search results)

**Implementation**:
```
Step 1: Grep pattern: "TODO" --output_mode files_with_matches
[Wait for results: src/app.ts, src/utils.ts, src/config.ts]

Step 2: Read the files (now parallel since paths are known):
- Read src/app.ts
- Read src/utils.ts
- Read src/config.ts
```

**Why Sequential Then Parallel**:
- Step 1 must complete first (need file list)
- Step 2 can be parallel (independent file reads)

**Result**: Found 3 files, read all their contents.

---

## Example 3: Editing a Function

**Scenario**: Add error logging to handleSubmit function.

**Approach**: Read first, then Edit

**Implementation**:
```
Step 1: Read src/forms/LoginForm.tsx

Step 2: Edit src/forms/LoginForm.tsx
old_string:
  const handleSubmit = async (data) => {
    const result = await loginUser(data);
    return result;
  }

new_string:
  const handleSubmit = async (data) => {
    try {
      const result = await loginUser(data);
      return result;
    } catch (error) {
      console.error('Login failed:', error);
      throw error;
    }
  }
```

**Why Read First**: Edit tool requires Read to be called first (technical requirement).

**Result**: Function updated with error handling.

---

## Example 4: Finding React Components

**Scenario**: Locate all React component files in project.

**Approach**: Use Glob for filename pattern matching

**Implementation**:
```
Glob pattern: "src/components/**/*.tsx"
```

**Why Glob**: Searching by filename pattern, not file contents.

**Result**: List of all .tsx files in components directory:
```
src/components/Button/Button.tsx
src/components/Form/LoginForm.tsx
src/components/Layout/Header.tsx
...
```

---

## Example 5: Finding Components Using Specific Hook

**Scenario**: Find all components that use `useAuth` hook.

**Approach**: Use Grep for content search

**Implementation**:
```
Grep pattern: "useAuth" glob: "*.tsx" --output_mode content
```

**Why Grep**: Searching file contents, not filenames.

**Result**: Matching lines with context showing which components use the hook.

---

## Example 6: Exploring Authentication Implementation

**Scenario**: Understand how authentication is implemented in unfamiliar codebase.

**Approach**: Use Task tool with Explore agent

**Implementation**:
```
Agent (subagent_type: Explore, thoroughness: medium):
  "How is authentication implemented in this codebase? Find login, auth token handling, and protected route implementation."
```

**Why Task Tool**:
- Open-ended exploration
- Requires multiple search iterations
- Need to understand patterns across files
- Agent can make decisions about where to look next

**Result**: Comprehensive report on auth implementation with relevant file locations.

---

## Example 7: Creating a Git Commit

**Scenario**: User asks to commit changes to authentication feature.

**Approach**: Gather info (parallel), then commit (sequential)

**Implementation**:
```
Step 1: Gather information (parallel):
- git status
- git diff
- git log --oneline -5

Step 2: Analyze changes and draft commit message

Step 3: Stage and commit (sequential):
git add src/auth/ tests/auth/ && git commit -m "$(cat <<'EOF'
Add JWT authentication system

Implements token-based auth with login/logout endpoints and middleware.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)" && git status
```

**Why This Pattern**:
- Parallel info gathering (independent operations)
- Sequential stage + commit + verify (dependent operations)

**Result**: Clean commit with descriptive message.

---

## Example 8: Searching with Type Filtering

**Scenario**: Find all TypeScript functions named "validate".

**Approach**: Use Grep with type filter

**Implementation**:
```
Grep pattern: "function validate" --type ts --output_mode content
```

**Why Type Filter**: More efficient than glob pattern for standard file types.

**Result**: All validate functions in TypeScript files with surrounding context.

---

## Example 9: Multi-Step Feature Implementation

**Scenario**: User requests adding dark mode toggle with tests.

**Approach**: Use Tasks to track progress

**Implementation**:
```
Step 1: Create todos:
Tasks:
  - content: "Create dark mode toggle component"
    activeForm: "Creating dark mode toggle component"
    status: "pending"
  - content: "Add dark mode state management"
    activeForm: "Adding dark mode state management"
    status: "pending"
  - content: "Implement CSS for dark theme"
    activeForm: "Implementing CSS for dark theme"
    status: "pending"
  - content: "Update components to support theming"
    activeForm: "Updating components to support theming"
    status: "pending"
  - content: "Write tests and ensure they pass"
    activeForm: "Writing tests and ensuring they pass"
    status: "pending"

Step 2: Mark first todo as in_progress and start work

Step 3: Complete first todo, mark as completed

Step 4: Mark second todo as in_progress...
[Continue through all todos]
```

**Why Tasks**:
- Complex multi-step task (5 distinct steps)
- User explicitly mentioned tests (important not to forget)
- Demonstrates progress to user

**Result**: Organized execution with visible progress tracking.

---

## Example 10: Creating a Pull Request

**Scenario**: User asks to create PR for feature branch.

**Approach**: Analyze all commits (parallel), then create PR

**Implementation**:
```
Step 1: Understand branch changes (parallel):
- git status
- git diff main...HEAD
- git log main..HEAD --oneline

Step 2: Analyze ALL commits in branch and draft PR summary

Step 3: Push and create PR (sequential):
git push -u origin feature/dark-mode && gh pr create --title "Add dark mode support" --body "$(cat <<'EOF'
## Summary
- Dark mode toggle component
- Theme state management with Context
- CSS variables for light/dark themes
- Updated all components to use theme
- Comprehensive test coverage

## Test plan
- [ ] Toggle switches between light and dark mode
- [ ] Theme preference persists across sessions
- [ ] All components render correctly in both modes
- [ ] Tests pass (npm test)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

**Why This Pattern**:
- Review ALL commits, not just latest
- Parallel info gathering
- Sequential push + PR creation

**Result**: Well-documented PR with comprehensive summary.

---

## Example 11: Web Research for Current Information

**Scenario**: Need latest React 19 features (beyond knowledge cutoff).

**Approach**: Use WebSearch then WebFetch

**Implementation**:
```
Step 1: WebSearch query: "React 19 new features official documentation 2025"

Step 2: [Review results, identify official docs URL]

Step 3: WebFetch:
  url: "https://react.dev/blog/2025/react-19"
  prompt: "What are the major new features in React 19?"
```

**Why This Pattern**:
- WebSearch finds current resources
- WebFetch extracts detailed information from specific URL

**Result**: Up-to-date information about React 19 features.

---

## Example 12: Editing Jupyter Notebook

**Scenario**: Update data processing code in notebook.

**Approach**: Read notebook, edit specific cell

**Implementation**:
```
Step 1: Read analysis/data_processing.ipynb
[Review structure, identify cell to edit]

Step 2: NotebookEdit:
  notebook_path: "/path/to/analysis/data_processing.ipynb"
  cell_id: "abc123"
  new_source: "import pandas as pd\n\ndf = pd.read_csv('data.csv')\ndf_clean = df.dropna()\nprint(f'Cleaned {len(df_clean)} rows')"
  edit_mode: "replace"
```

**Why Read First**: Need to understand notebook structure and find correct cell_id.

**Result**: Notebook cell updated with improved data processing code.

---

## Pattern Summary

| Scenario | Pattern | Tools Used | Key Principle |
|----------|---------|------------|---------------|
| Read multiple files | Parallel | Read (multiple) | Independent operations |
| Search then read | Sequential → Parallel | Grep → Read | Dependent then independent |
| Edit file | Sequential | Read → Edit | Read always first |
| Find by filename | Single tool | Glob | Pattern matching |
| Find by content | Single tool | Grep | Content search |
| Explore codebase | Agent | Task (Explore) | Multi-step discovery |
| Create commit | Parallel → Sequential | Bash (git) | Gather info → Act |
| Track complex task | Ongoing | Tasks | Multi-step work |
| Find current info | Sequential | WebSearch → WebFetch | Discover → Extract |
| Edit notebook | Sequential | Read → NotebookEdit | Understand → Modify |

---

## Quick Decision Guide

**How many files?**
- One file → Single tool call
- Multiple known files → Parallel tool calls
- Don't know which files → Search first (Grep/Glob), then act

**Operations related?**
- Independent → Parallel execution
- Dependent → Sequential execution

**What are you looking for?**
- Filename pattern → Glob
- File contents → Grep
- Don't know where to start → Task (Explore)

**Modifying files?**
- Always Read first
- Prefer Edit over Write
- Use Write only for new files

**Complex task?**
- 3+ steps → Tasks
- Open-ended exploration → Task
- Need user input → AskUserQuestion
