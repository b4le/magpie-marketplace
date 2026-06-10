# Web & External Tools - Detailed Reference

Comprehensive documentation for WebFetch, WebSearch, and NotebookEdit tools.

---

## WebFetch Tool

**Purpose**: Fetch and analyze web content

**When to use**:
- Fetching documentation from URLs
- Analyzing web pages
- Extracting information from specific URLs
- Accessing external documentation or resources

**Parameters**:
- `url` (required): Fully-formed valid URL
- `prompt` (required): What information to extract from the page

**Best Practices**:
- Prefer MCP-provided web fetch tools if available (start with "mcp__")
- HTTP URLs auto-upgrade to HTTPS
- Has 15-minute self-cleaning cache for faster repeated access
- When URL redirects to different host, tool will inform you - make new request with redirect URL
- URL must be fully-formed and valid

**Examples**:
```
WebFetch:
  url: "https://docs.python.org/3/library/asyncio.html"
  prompt: "Explain how asyncio.gather works and provide examples"

WebFetch:
  url: "https://api-docs.example.com/v2/authentication"
  prompt: "What are the authentication methods supported?"
```

**Redirect Handling**:
If WebFetch returns a redirect message:
1. Note the redirect URL provided
2. Make a new WebFetch request with the redirect URL
3. Process the content from the redirect destination

**Anti-patterns**:
- Using when MCP-provided tool available
- Not handling redirects properly
- Using for current/recent information (use WebSearch instead)

---

## WebSearch Tool

**Purpose**: Search the web for current information

**When to use**:
- Accessing information beyond Claude's knowledge cutoff (January 2025)
- Finding current events or recent data
- Researching latest documentation or updates
- Getting up-to-date information about libraries, frameworks, or tools

**Parameters**:
- `query` (required): Search query (minimum 2 characters)
- `allowed_domains` (optional): Only include results from these domains
- `blocked_domains` (optional): Exclude results from these domains

**Best Practices**:
- Only available in US
- Account for "Today's date" from environment when crafting queries
- Use current year in queries for latest docs (don't use outdated year)
- Be specific in search queries
- Use domain filtering when you know the source

**Important**: If environment says "Today's date: 2025-11-18", and user wants latest docs, use 2025 in query, not 2024.

**Examples**:
```
WebSearch:
  query: "React 19 new features 2025"

WebSearch:
  query: "TypeScript 5.3 release notes"
  allowed_domains: ["typescriptlang.org"]

WebSearch:
  query: "Python asyncio best practices 2025"
  blocked_domains: ["stackoverflow.com"]  # Want official docs only
```

**Use Cases**:
- "What are the latest features in [library] version [X]?"
- "Current best practices for [technology] in 2025"
- "Recent updates to [framework]"
- "Latest security recommendations for [tool]"

**Anti-patterns**:
- Using for information within Claude's knowledge cutoff
- Not accounting for current date in queries
- Using outdated year references

---

## NotebookEdit Tool

**Purpose**: Edit Jupyter notebook (.ipynb) cells

**When to use**:
- Modifying code or markdown cells in Jupyter notebooks
- Inserting new cells into notebooks
- Deleting cells from notebooks
- Working with .ipynb files

**Parameters**:
- `notebook_path` (required): Absolute path to .ipynb file
- `new_source` (required): New cell content
- `cell_id` (optional): Cell ID to edit
- `cell_type` (optional): "code" or "markdown" (required for insert mode)
- `edit_mode` (optional): "replace" (default), "insert", "delete"

**Edit Modes**:
1. **replace** (default): Replace existing cell content
2. **insert**: Add a new cell
3. **delete**: Remove a cell

**Best Practices**:
- Read notebook first to understand structure (Read tool works with .ipynb)
- Use cell_id to target specific cells
- Specify cell_type when inserting new cells
- Test notebook after editing

**Examples**:

**Replace cell content**:
```
NotebookEdit:
  notebook_path: "/path/to/notebook.ipynb"
  cell_id: "abc123"
  new_source: "import pandas as pd\ndf = pd.read_csv('data.csv')"
  edit_mode: "replace"
```

**Insert new cell**:
```
NotebookEdit:
  notebook_path: "/path/to/notebook.ipynb"
  cell_id: "abc123"  # Insert after this cell
  cell_type: "code"
  new_source: "print('New cell')"
  edit_mode: "insert"
```

**Delete cell**:
```
NotebookEdit:
  notebook_path: "/path/to/notebook.ipynb"
  cell_id: "abc123"
  edit_mode: "delete"
  new_source: ""  # Required but ignored for delete
```

**Reading notebooks**:
```
Read /path/to/notebook.ipynb
```
Returns all cells with their outputs, combining code, text, and visualizations.

---

## Web Tools Decision Matrix

| Task | Tool | Reason |
|------|------|--------|
| Fetch specific URL content | WebFetch | Direct URL access |
| Search for current information | WebSearch | Discovery and search |
| Get latest library docs | WebSearch | Current information |
| Access known documentation page | WebFetch | Direct access |
| Find recent blog posts | WebSearch | Discovery |
| Extract data from API docs | WebFetch | Specific URL |
| Edit Jupyter notebook | NotebookEdit | Notebook-specific |
| Read Jupyter notebook | Read | Works with .ipynb |

---

## External Data Access Patterns

### Pattern 1: Search Then Fetch
```
Step 1: WebSearch for "React 19 documentation official"
Step 2: Identify official docs URL from results
Step 3: WebFetch that specific URL with detailed prompt
```

### Pattern 2: Direct Fetch
```
WebFetch known documentation URL with specific extraction prompt
```

### Pattern 3: Domain-Filtered Search
```
WebSearch with allowed_domains: ["python.org"] to get only official Python docs
```

### Pattern 4: Notebook Workflow
```
Step 1: Read notebook.ipynb to understand structure
Step 2: NotebookEdit to modify specific cells
Step 3: Read again to verify changes
```

---

## Common Web Tool Mistakes

1. **Using WebFetch for search**:
   - Wrong: WebFetch with general query
   - Right: WebSearch to find URLs, then WebFetch specific URLs

2. **Not handling redirects**:
   - Wrong: Ignoring redirect message
   - Right: Making new WebFetch request with redirect URL

3. **Using outdated year in WebSearch**:
   - Wrong: "React best practices 2024" when it's 2025
   - Right: "React best practices 2025"

4. **Using WebSearch for known URLs**:
   - Wrong: WebSearch "https://docs.python.org/3/library/asyncio.html"
   - Right: WebFetch "https://docs.python.org/3/library/asyncio.html"

5. **Editing notebooks without reading first**:
   - Wrong: NotebookEdit without knowing structure
   - Right: Read notebook, then NotebookEdit with proper cell_id
