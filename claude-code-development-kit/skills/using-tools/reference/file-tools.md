# File Operation Tools - Detailed Reference

Comprehensive documentation for file reading, writing, editing, and searching tools.

---

## Read Tool

**Purpose**: Read file contents from the filesystem

**When to use**:
- Reading any file with a known path
- Viewing file contents before editing
- Reading images (PNG, JPG, etc.) - Claude can view them
- Reading Jupyter notebooks (.ipynb files)
- Checking file contents before making decisions

**Parameters**:
- `file_path` (required): Absolute path to file
- `offset` (optional): Line number to start from
- `limit` (optional): Number of lines to read

**Best Practices**:
- Always read files before editing them (required for Edit/Write tools)
- Use for specific known paths, not for searching
- Default reads up to 2000 lines from beginning
- Lines longer than 2000 characters are truncated
- Can read multiple files in parallel in a single message

**Examples**:
```
Read src/components/Button.tsx
Read package.json and README.md in parallel
```

**Anti-patterns**:
- Using `cat`, `head`, `tail` bash commands instead
- Reading files to search for content (use Grep instead)

---

## Edit Tool

**Purpose**: Perform exact string replacements in files

**When to use**:
- Modifying existing code
- Making precise changes to specific sections
- Replacing all instances of a string (with replace_all)
- Renaming variables across a file

**Parameters**:
- `file_path` (required): Absolute path to file
- `old_string` (required): Exact text to replace
- `new_string` (required): Replacement text (must differ from old_string)
- `replace_all` (optional): Replace all occurrences (default: false)

**Best Practices**:
- MUST use Read tool first before editing
- Preserve exact indentation from file (ignore line number prefix)
- Provide enough context to make old_string unique
- Use replace_all for renaming/replacing multiple instances
- ALWAYS prefer editing existing files over creating new ones
- Never include emojis unless user explicitly requests

**Important**: Edit will FAIL if old_string is not unique. Provide more surrounding context or use replace_all.

**Example**:
```
Edit function from:
  const handleClick = () => {
    console.log('clicked');
  }

To:
  const handleClick = () => {
    console.log('clicked');
    trackEvent('button_click');
  }
```

**Anti-patterns**:
- Using `sed`, `awk` bash commands instead
- Creating new files when you should edit existing ones
- Not reading file first

---

## Write Tool

**Purpose**: Write complete file contents (overwrites existing files)

**When to use**:
- Creating new configuration files (only when necessary)
- Writing new source files (only when explicitly required)
- Overwriting entire file contents

**Parameters**:
- `file_path` (required): Absolute path (not relative)
- `content` (required): Complete file contents

**Best Practices**:
- MUST use Read tool first if file exists
- ALWAYS prefer editing existing files
- NEVER proactively create documentation/README files
- Only use when creating files is explicitly required
- Never include emojis unless user explicitly requests

**Examples**:
```
Write new config file .eslintrc.json
Write new test file tests/button.test.ts
```

**Anti-patterns**:
- Using `cat <<EOF` or `echo >` bash commands instead
- Creating files when editing would work
- Proactively creating documentation

---

## Glob Tool

**Purpose**: Fast file pattern matching using glob patterns

**When to use**:
- Finding files by name patterns
- Searching for specific file types
- Locating files in directory structures
- Finding specific class definitions (e.g., "class Foo")

**Parameters**:
- `pattern` (required): Glob pattern (e.g., "**/*.js", "src/**/*.tsx")
- `path` (optional): Directory to search in (defaults to current working directory)

**Best Practices**:
- Use for known file patterns, not open-ended searches
- Returns files sorted by modification time
- Works with any codebase size
- Can run multiple globs in parallel
- For open-ended searches, use Task tool with subagent_type=Explore instead

**Examples**:
```
Glob pattern: "**/*.test.ts" - Find all test files
Glob pattern: "src/components/**/*.tsx" - Find React components
Glob pattern: "**/config.json" - Find config files
```

**Anti-patterns**:
- Using `find` or `ls` bash commands instead
- Using for content search (use Grep instead)
- Using for open-ended exploration (use Task tool instead)

---

## Grep Tool

**Purpose**: Search file contents using regex patterns (built on ripgrep)

**When to use**:
- Searching for code patterns
- Finding function/class usage
- Locating specific strings in codebase
- Finding TODO comments, error messages, etc.

**Parameters**:
- `pattern` (required): Regex pattern (ripgrep syntax)
- `path` (optional): File or directory to search
- `output_mode` (optional): "content" (matching lines), "files_with_matches" (just paths - default), "count" (match counts)
- `glob` (optional): Filter files (e.g., "*.js")
- `type` (optional): File type filter (e.g., "js", "py", "rust")
- `-i` (optional): Case insensitive
- `-A`, `-B`, `-C` (optional): Context lines after/before/both
- `-n` (optional): Show line numbers (default: true with content mode)
- `multiline` (optional): Enable cross-line pattern matching
- `head_limit` (optional): Limit output to first N results
- `offset` (optional): Skip first N results

**Best Practices**:
- Use for searching within files, not finding files
- Literal braces need escaping: `interface\\{\\}` to find `interface{}`
- Use output_mode: "files_with_matches" to find which files, then read specific files
- Use output_mode: "content" to see matching lines
- For open-ended searches requiring multiple rounds, use Task tool instead
- Can run multiple greps in parallel

**Examples**:
```
Grep pattern: "function handleSubmit" - Find function definition
Grep pattern: "TODO|FIXME" - Find todos
Grep pattern: "import.*React" glob: "*.tsx" - Find React imports in TypeScript
Grep pattern: "struct \\{[\\s\\S]*?field" multiline: true - Cross-line pattern
```

**Anti-patterns**:
- Using `grep` or `rg` bash commands instead
- Searching for files (use Glob instead)
- Open-ended exploration (use Task tool instead)

---

## File Operations Decision Matrix

| Task | Recommended Tool | Alternative | Reason |
|------|------------------|-------------|--------|
| Read specific file | Read | - | Direct file access |
| Search for file by name | Glob | - | Pattern matching |
| Search file contents | Grep | - | Content search |
| Edit existing file | Edit | Write | Preserves formatting |
| Create new file | Write | - | Complete control |
| Find class definition | Glob | Grep | Name-based search |
| Find function usage | Grep | - | Content-based search |
| Explore codebase | Task (Explore) | - | Complex multi-step |

---

## Performance Optimization

### Reading Multiple Files

**Slow** (Sequential):
```
Read file1.ts
[Wait]
Read file2.ts
[Wait]
Read file3.ts
```

**Fast** (Parallel):
```
In one message:
- Read file1.ts
- Read file2.ts
- Read file3.ts
```

### Searching Multiple Patterns

**Slow** (Sequential):
```
Grep "pattern1"
[Wait]
Grep "pattern2"
```

**Fast** (Parallel):
```
In one message:
- Grep "pattern1"
- Grep "pattern2"
```

### Search Then Read

**Correct** (Sequential - dependencies exist):
```
Step 1: Grep "TODO" --output_mode files_with_matches
[Wait for file list]
Step 2: Read [files from results]
```
