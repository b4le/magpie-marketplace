# Common Anti-Patterns & How to Avoid Them

Detailed guide to recognizing and avoiding common tool usage mistakes.

---

## File Operation Anti-Patterns

### Anti-Pattern 1: Using Bash Commands for File Operations

**Problem**: Using `cat`, `head`, `tail`, `sed`, `awk`, or `echo` instead of specialized tools.

**Wrong**:
```bash
cat src/app.ts
head -20 config.json
tail -10 logs/error.log
sed 's/old/new/g' file.txt
echo "content" > file.txt
```

**Right**:
```
Read src/app.ts
Read config.json (with limit: 20)
Read logs/error.log (with offset and limit for last 10 lines)
Edit file.txt (old_string: "old", new_string: "new", replace_all: true)
Write file.txt (content: "content")
```

**Why**: Specialized tools provide better error handling, context management, and user experience.

---

### Anti-Pattern 2: Creating New Files Instead of Editing

**Problem**: Using Write to create a new file when editing existing file would work.

**Wrong**:
```
Read existing-file.ts
[Note contents]
Write existing-file.ts (with modified content)
```

**Right**:
```
Read existing-file.ts
Edit existing-file.ts (old_string: "...", new_string: "...")
```

**Why**:
- Edit preserves formatting and context
- Edit is safer (only changes specific parts)
- Edit is clearer about intent
- Write can accidentally lose content

---

### Anti-Pattern 3: Using Task Tool for Simple Known Paths

**Problem**: Launching a Task agent when you know exactly which file to read.

**Wrong**:
```
Agent (subagent_type: Explore):
  "Find and read the configuration file"
```

**Right**:
```
Read config/app.config.json
```

**Why**: The Task tool is for complex multi-step exploration, not simple file access.

---

### Anti-Pattern 4: Using Glob to Search File Contents

**Problem**: Using Glob when you need to search inside files.

**Wrong**:
```
Glob pattern: "**/*.ts"
[Then manually check each file for content]
```

**Right**:
```
Grep pattern: "TODO" glob: "*.ts"
```

**Why**: Grep is designed for content search; Glob is for filename patterns.

---

### Anti-Pattern 5: Using Grep to Find Files

**Problem**: Using Grep to locate files by name.

**Wrong**:
```
Grep pattern: "config.json"
```

**Right**:
```
Glob pattern: "**/config.json"
```

**Why**: Glob is optimized for filename matching; Grep is for content search.

---

### Anti-Pattern 6: Not Reading Files Before Editing

**Problem**: Calling Edit or Write without reading the file first.

**Wrong**:
```
Edit file.ts (old_string: "const x = 1", new_string: "const x = 2")
[ERROR: Must read file first]
```

**Right**:
```
Read file.ts
Edit file.ts (old_string: "const x = 1", new_string: "const x = 2")
```

**Why**: Edit and Write tools require Read to be called first (technical requirement).

---

## Execution Pattern Anti-Patterns

### Anti-Pattern 7: Running Dependent Commands in Parallel

**Problem**: Calling tools in parallel when one depends on another's results.

**Wrong**:
```
In one message:
- Grep pattern: "TODO" --output_mode files_with_matches
- Read src/app.ts  # Doesn't know if this file has TODOs yet!
```

**Right**:
```
Step 1: Grep pattern: "TODO" --output_mode files_with_matches
[Wait for results: src/app.ts, src/utils.ts]
Step 2: Read src/app.ts and Read src/utils.ts (parallel)
```

**Why**: Can't read files from Grep results if you don't have the results yet.

---

### Anti-Pattern 8: Running Independent Commands Sequentially

**Problem**: Waiting between independent operations that could run in parallel.

**Wrong**:
```
Read src/app.ts
[Wait for response]
Read src/config.ts
[Wait for response]
Read package.json
```

**Right**:
```
In one message:
- Read src/app.ts
- Read src/config.ts
- Read package.json
```

**Why**: Parallel execution is much faster and more efficient.

---

## Communication Anti-Patterns

### Anti-Pattern 9: Using Bash Echo to Communicate

**Problem**: Using `echo` or other bash commands to talk to the user.

**Wrong**:
```bash
echo "I found 3 files with TODOs"
echo "Now I'll read them"
```

**Right**:
```
[Output in response text]: I found 3 files with TODOs. Now I'll read them.
```

**Why**: Bash commands are for system operations, not user communication.

---

## Task Management Anti-Patterns

### Anti-Pattern 10: Not Using Tasks for Complex Tasks

**Problem**: Working on multi-step task without tracking progress.

**Wrong**:
```
User: "Add authentication, update tests, and deploy"
Assistant: [Starts working without creating todos]
```

**Right**:
```
User: "Add authentication, update tests, and deploy"
Assistant:
Tasks:
  - "Implement authentication system"
  - "Update test suite for auth"
  - "Deploy application"
[Then marks each as in_progress/completed as working]
```

**Why**: Tasks provides visibility, demonstrates progress, helps prevent forgetting steps.

---

### Anti-Pattern 11: Marking Todos Complete Prematurely

**Problem**: Marking task as completed before it's actually done.

**Wrong**:
```
Todo: "Run tests and fix failures"
[Runs tests, 3 failures found]
Tasks: Mark "Run tests and fix failures" as completed
```

**Right**:
```
Todo: "Run tests and fix failures"
[Runs tests, 3 failures found]
Tasks:
  - "Run tests and fix failures" stays in_progress
  - Add new todos: "Fix test failure 1", "Fix test failure 2", "Fix test failure 3"
```

**Why**: Task isn't complete if tests are failing.

---

## Tool Selection Anti-Patterns

### Anti-Pattern 12: Using Read to Search

**Problem**: Reading files to search for content when Grep would work better.

**Wrong**:
```
Read src/app.ts
Read src/utils.ts
Read src/config.ts
[Manually look for "TODO" in each file]
```

**Right**:
```
Grep pattern: "TODO" glob: "*.ts" --output_mode content
```

**Why**: Grep is designed for searching across files efficiently.

---

### Anti-Pattern 13: Using Relative Paths

**Problem**: Using relative paths instead of absolute paths.

**Wrong**:
```
Read ../config/app.json
Edit ./src/app.ts
```

**Right**:
```
Read /Users/username/project/config/app.json
Edit /Users/username/project/src/app.ts
```

**Why**: Relative paths can be ambiguous; absolute paths are always clear.

---

### Anti-Pattern 14: Speculating Without Investigation

**Problem**: Making assumptions about code without reading it.

**Wrong**:
```
"Based on typical React projects, this probably uses Redux for state management, so I'll suggest adding a new action..."
```

**Right**:
```
"Let me first read the state management files to see what's being used."
Read src/store/index.ts
Read src/context/AppContext.tsx
[Then make recommendations based on actual code]
```

**Why**: Prevents hallucinations, ensures accuracy, matches actual codebase.

---

## Git & GitHub Anti-Patterns

### Anti-Pattern 15: Committing Without Being Asked

**Problem**: Creating commits proactively without user request.

**Wrong**:
```
[Finishes making changes]
git add . && git commit -m "Update feature"
```

**Right**:
```
[Finishes making changes]
"The changes are complete. Would you like me to create a commit?"
[Wait for user to explicitly ask]
```

**Why**: Users should control when commits are created.

---

### Anti-Pattern 16: Force Pushing to Main

**Problem**: Running `git push --force` to main/master branch.

**Wrong**:
```bash
git push --force origin main
```

**Right**:
```
"Warning: Force pushing to main is dangerous and can overwrite team members' work. Are you absolutely sure you want to do this?"
[Only proceed if user confirms]
```

**Why**: Force pushing to main can destroy team history and work.

---

### Anti-Pattern 17: Skipping Hooks

**Problem**: Using `--no-verify` or `--no-gpg-sign` without user request.

**Wrong**:
```bash
git commit --no-verify -m "Quick fix"
```

**Right**:
```bash
git commit -m "Quick fix"
[Let hooks run normally]
```

**Why**: Hooks exist for a reason (linting, testing, etc.). Only skip if user explicitly requests.

---

## Path & File Handling Anti-Patterns

### Anti-Pattern 18: Not Quoting Paths with Spaces

**Problem**: Using paths with spaces in bash without quotes.

**Wrong**:
```bash
cd /Users/name/My Documents
python3 /path with spaces/script.py
```

**Right**:
```bash
cd "/Users/name/My Documents"
python3 "/path with spaces/script.py"
```

**Why**: Unquoted paths with spaces will cause command failures.

---

### Anti-Pattern 19: Using Placeholders in Tool Calls

**Problem**: Using placeholder values when actual values aren't known yet.

**Wrong**:
```
Read {filename}  # Placeholder - don't know filename yet
Edit src/app.ts (old_string: "{old_value}", new_string: "new_value")
```

**Right**:
```
[First get the actual filename]
Grep pattern: "config" --output_mode files_with_matches
[Wait for results]
Read [actual filename from results]
```

**Why**: Tools need actual values, not placeholders. Wait for results if you need them.

---

## Search & Exploration Anti-Patterns

### Anti-Pattern 20: Using Grep/Glob for Open-Ended Exploration

**Problem**: Using multiple rounds of Grep/Glob when Task tool with Explore agent would work better.

**Wrong**:
```
Grep pattern: "authentication"
[Review results]
Grep pattern: "login"
[Review results]
Glob pattern: "**/*auth*"
[Review results]
Grep pattern: "jwt"
[Keep searching...]
```

**Right**:
```
Agent (subagent_type: Explore, thoroughness: medium):
  "How is authentication implemented in this codebase? Find login, auth, and JWT-related code."
```

**Why**: The Task tool is designed for multi-step exploration; more efficient than manual iterations.

---

## Summary: Anti-Pattern Quick Reference

| Don't Do This | Do This Instead | Tool/Concept |
|---------------|-----------------|--------------|
| `cat file.ts` | `Read file.ts` | File Operations |
| `grep "TODO" **/*.ts` | `Grep pattern: "TODO" glob: "*.ts"` | Search |
| `find . -name "*.ts"` | `Glob pattern: "**/*.ts"` | File Finding |
| Write when editing works | Edit tool | File Modification |
| Run dependent ops in parallel | Run sequentially | Execution |
| Run independent ops sequentially | Run in parallel | Execution |
| `echo "message"` to user | Output in response text | Communication |
| Commit without being asked | Wait for user request | Git |
| `git push --force origin main` | Warn user first | Git |
| `cd /path with spaces` | `cd "/path with spaces"` | Paths |
| Multiple Grep/Glob iterations | Task (Explore agent) | Exploration |
| Assume code structure | Read and investigate | Code Understanding |
| Mark todo complete early | Only when fully done | Task Management |
| Use placeholders | Wait for actual values | Tool Calls |
| Relative paths | Absolute paths | File Paths |

---

## How to Recognize Anti-Patterns

**Red Flags**:
1. Using bash command when specialized tool exists
2. Creating files when editing would work
3. Running operations sequentially that could be parallel
4. Making assumptions without reading code
5. Using wrong tool for the task (Grep for files, Glob for content)
6. Skipping required steps (Read before Edit)
7. Communicating via bash commands
8. Not tracking complex multi-step tasks
9. Using relative paths
10. Force flags without user confirmation

**Self-Check Questions**:
- Is there a specialized tool for this? (Use it instead of bash)
- Can these operations run in parallel? (Use parallel if yes)
- Do I know this for sure, or am I guessing? (Read and verify)
- Am I using the right tool for the task? (Check tool purpose)
- Have I read the file first? (Required for Edit/Write)
- Is this a complex task? (Use Tasks)
- Am I using placeholders? (Wait for actual values)
- Am I using absolute paths? (Always use absolute)
