# Tool Selection Matrices - Decision Frameworks

Comprehensive decision matrices for choosing the right tool for any task.

---

## Primary Tool Selection Matrix

| I need to... | Use this tool | Not this tool | Why |
|--------------|---------------|---------------|-----|
| Read a specific file | Read | Bash (cat) | Specialized tool, better error handling |
| Edit an existing file | Edit | Write, Bash (sed) | Preserves context, safer |
| Create a new file | Write | Bash (echo >) | Only when necessary |
| Find files by name pattern | Glob | Bash (find, ls) | Optimized for pattern matching |
| Search file contents | Grep | Bash (grep), Read | Built for content search |
| Explore codebase structure | Task (Explore) | Multiple Grep/Glob | Autonomous multi-step |
| Plan implementation | Task (Plan) | Manual planning | Structured breakdown |
| Execute terminal commands | Bash | - | Terminal operations |
| Track multi-step tasks | Tasks | Manual tracking | Visibility and organization |
| Get user input | AskUserQuestion | - | Structured choices |
| Fetch web content | WebFetch | Bash (curl) | AI-powered extraction |
| Search web | WebSearch | - | Current information |
| Edit Jupyter notebooks | NotebookEdit | Write | Notebook-specific |

---

## File Operations Decision Matrix

| Task Type | Tool | Parameters to Use | Example |
|-----------|------|-------------------|---------|
| Read single file | Read | file_path | Read src/app.ts |
| Read large file (first part) | Read | file_path, limit: 100 | Read logs/app.log (limit: 100) |
| Read large file (last part) | Read | file_path, offset, limit | Read logs/app.log (offset: 9900, limit: 100) |
| Read multiple files | Read (parallel) | Multiple file_path calls | Read file1.ts, file2.ts, file3.ts |
| Change specific text | Edit | file_path, old_string, new_string | Edit file.ts (old → new) |
| Rename variable everywhere | Edit | file_path, old, new, replace_all: true | Edit file.ts (oldVar → newVar, all) |
| Create new file | Write | file_path, content | Write config.json (content) |
| Overwrite entire file | Write | file_path, content | Write (after Read if exists) |

---

## Search Operations Decision Matrix

| Looking for... | Tool | Output Mode | Example |
|----------------|------|-------------|---------|
| Files by name pattern | Glob | - | Glob "**/*.test.ts" |
| Specific class definition | Glob | - | Glob "**/*Button.tsx" |
| All TypeScript files | Glob | - | Glob "**/*.ts" |
| Code pattern in files | Grep | files_with_matches | Grep "function.*async" |
| See matching lines | Grep | content | Grep "TODO" --output_mode content |
| Count matches per file | Grep | count | Grep "import React" --output_mode count |
| Case-insensitive search | Grep | content, -i: true | Grep "error" -i: true |
| Search in specific file type | Grep | content, --type | Grep "TODO" --type ts |
| Search in specific files | Grep | content, --glob | Grep "TODO" --glob "*.tsx" |
| Multiline pattern | Grep | content, multiline: true | Grep complex pattern with multiline |

---

## Task Complexity Decision Matrix

| Complexity | Description | Tool Choice | Example |
|------------|-------------|-------------|---------|
| Simple | Single file, known path | Read/Edit/Write | Read config.json |
| Simple | Known file pattern | Glob | Glob "**/*.test.ts" |
| Simple | Search single pattern | Grep | Grep "TODO" |
| Medium | Multiple files, parallel | Read/Grep/Glob (parallel) | Read 3 files in one message |
| Medium | Search → Action | Grep → Read (sequential) | Grep for files → Read them |
| Complex | Multi-step exploration | Task (Explore agent) | "How does auth work?" |
| Complex | Implementation planning | Task (Plan agent) | "Plan dark mode feature" |
| Complex | 3+ distinct steps | Tasks | Track progress through steps |

---

## Parallel vs Sequential Decision Matrix

| Scenario | Execution | Reason | Example |
|----------|-----------|--------|---------|
| Read 5 known files | Parallel | Independent | All 5 Read calls in one message |
| Grep then Read results | Sequential | Read depends on Grep | Grep → wait → Read |
| Run 3 test suites | Parallel | Independent | 3 bash calls in one message |
| Build then Test | Sequential | Test depends on build | build && test |
| Edit 3 different files | Parallel | Independent | 3 Edit calls in one message |
| Read config then use values | Sequential | Usage depends on values | Read → wait → Use values |
| Check 4 lint rules | Parallel | Independent | 4 lint commands in one message |
| Git status + diff + log | Parallel | Independent | All 3 in one message |
| Git add then commit | Sequential | Commit needs staged files | add && commit |

---

## Content Type vs Tool Matrix

| Content Type | Find by Name | Find by Content | Read | Edit |
|--------------|-------------|-----------------|------|------|
| Source code | Glob "**/*.ts" | Grep "pattern" | Read | Edit |
| Config files | Glob "**/config.*" | Grep "key:" | Read | Edit |
| Test files | Glob "**/*.test.*" | Grep "describe\|it" | Read | Edit |
| Documentation | Glob "**/*.md" | Grep "## " | Read | Edit |
| Package files | Glob "**/package.json" | Grep "dependencies" | Read | Edit |
| Images | Glob "**/*.{png,jpg}" | - | Read (Claude can view) | - |
| Notebooks | Glob "**/*.ipynb" | - | Read | NotebookEdit |

---

## Performance Optimization Matrix

| Optimization | Bad Practice | Good Practice | Impact |
|--------------|--------------|---------------|--------|
| Parallel execution | 3 sequential Read calls | 3 parallel Read calls | 3x faster |
| Right tool | Bash cat | Read tool | Better UX |
| Targeted search | Glob "**/*" then filter | Glob "**/*.test.ts" | Faster results |
| Agent sizing | Explore agent for simple read | Read tool directly | Lower cost |
| Search scope | Grep in all files | Grep with --type or --glob | Faster search |
| File reading | Read entire 10K line file | Read with offset/limit | Less context |

---

## Error Handling Decision Matrix

| Error Scenario | Likely Cause | Solution | Prevention |
|----------------|--------------|----------|------------|
| Edit fails "not unique" | old_string matches multiple | Add more context | Include surrounding lines |
| Edit fails "must read first" | Didn't Read before Edit | Read file first | Always Read before Edit |
| Import not found | Typo or missing file | Check filename/path | Verify after creation |
| Bash command fails | Wrong syntax or path | Check command | Use specialized tools |
| Grep no results | Pattern doesn't match | Try simpler pattern | Test pattern first |
| File not found | Wrong path or doesn't exist | Verify path | Use absolute paths |
| Task agent confused | Vague instructions | Be specific | Detailed prompts |

---

## Special Cases Decision Matrix

| Special Case | Standard Approach | Better Approach | Why |
|--------------|-------------------|-----------------|-----|
| Very large file (10K+ lines) | Read entire file | Read with offset/limit | Context limits |
| Files with spaces in name | Hope it works | Quote paths | Prevents errors |
| Cross-file refactoring | Edit each file | Grep to find all, then Edit | Comprehensive |
| Exploring unfamiliar code | Random Grep/Read | Task (Explore agent) | Systematic |
| Multiple similar edits | Edit one at a time | Edit with replace_all | Efficiency |
| Creating similar files | Write each manually | Write with template | Consistency |
| Complex multi-step task | Ad-hoc execution | Tasks tracking | Organization |

---

## Tool Capability Comparison

### Read vs Grep

| Feature | Read | Grep |
|---------|------|------|
| Purpose | View file contents | Search file contents |
| Input | File path | Pattern + optional path |
| Output | Full file or range | Matching lines or files |
| Best for | Known files | Finding patterns |
| Multiple files | Parallel calls | Single call with pattern |

### Glob vs Grep

| Feature | Glob | Grep |
|---------|------|------|
| Searches | Filenames | File contents |
| Pattern type | Glob patterns | Regex patterns |
| Output | File paths | Content or paths |
| Best for | "Find files named X" | "Find files containing Y" |
| Speed | Very fast | Fast |

### Edit vs Write

| Feature | Edit | Write |
|---------|------|-------|
| Purpose | Modify existing | Create/replace |
| Preserves | Formatting, context | Nothing (overwrites) |
| Safety | Targeted changes | Full replacement |
| Best for | Updates to existing | New files |
| Read required | Yes | Yes (if exists) |

### Task vs Direct Tools

| Feature | Task Tool | Direct Tools |
|---------|-----------------|--------------|
| Complexity | Multi-step | Single operation |
| Autonomy | Task agent decides | You decide |
| Best for | Exploration, planning | Known operations |
| Speed | Slower (thorough) | Fast |
| Cost | Higher (uses model) | Lower |

---

## Quick Reference Decision Trees

### "I need to find something"

```
What are you looking for?
├─ File by name → Glob
├─ Content in files → Grep
├─ Understanding of system → Task (Explore)
└─ Current web info → WebSearch
```

### "I need to modify files"

```
What kind of change?
├─ Specific text replacement → Edit
├─ Entire file rewrite → Write
├─ Multiple similar changes → Edit with replace_all
└─ Notebook cells → NotebookEdit
```

### "I need to execute something"

```
What kind of execution?
├─ File operation → Use specialized tool (Read/Edit/Write/Grep/Glob)
├─ Terminal command → Bash
├─ Complex exploration → Task (Explore)
├─ Implementation planning → Task (Plan)
└─ Track progress → Tasks
```

### "Should I use parallel or sequential?"

```
Do later operations need earlier results?
├─ NO → Parallel (default)
└─ YES → Sequential
```

---

## Advanced Patterns

### Pattern: Progressive File Reading

```
1. Glob to find files
2. Grep to filter by content
3. Read the specific files needed

Example:
- Glob "**/*.ts" (find TypeScript files)
- Grep "class.*extends Component" --glob "*.ts" (find component classes)
- Read [specific files from results]
```

### Pattern: Comprehensive Search

```
1. Task (Explore) for initial understanding
2. Grep for specific patterns based on understanding
3. Read files for detailed review

Example: Understanding new codebase
- Task: "Explore the authentication system"
- [Agent finds key files]
- Grep for specific auth patterns
- Read critical auth files
```

### Pattern: Bulk Updates

```
1. Grep to find all instances
2. Read files to verify context
3. Edit with replace_all for bulk changes

Example: Rename variable across codebase
- Grep "oldVariableName" --output_mode files_with_matches
- Read files to verify safe to replace
- Edit each file with replace_all: true
```

---

## Summary: Tool Selection Principles

1. **Prefer specialized tools over Bash** for file operations
2. **Default to parallel** execution unless dependencies exist
3. **Use Task tool** for multi-step exploration or planning
4. **Always Read before Edit** (technical requirement)
5. **Use Grep for content**, Glob for filenames
6. **Track complex tasks** with Tasks
7. **Absolute paths** always, never relative
8. **No placeholders** - wait for actual values
9. **Ask users** when you need decisions (AskUserQuestion)
10. **Trust agent outputs** when using the Task tool
