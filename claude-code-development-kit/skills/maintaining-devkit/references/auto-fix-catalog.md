# Auto-Fix Catalog

**Purpose**: Complete reference for automated fixes the maintenance workflow can apply without user confirmation, plus the full list of changes that require human review before applying.

---

## Decision Tree: Is This Fix Safe?

```
Is the fix purely additive (adds a missing required value)?
├── YES → Is the added value deterministic (not a guess)?
│         ├── YES → SAFE to auto-fix
│         └── NO  → REQUIRES CONFIRMATION (would add a placeholder)
└── NO  → Does the fix rename, delete, or change a field's semantics?
          ├── YES → REQUIRES CONFIRMATION
          └── NO  → Is the fix a normalization (case, format)?
                    ├── YES → Is the current value unambiguously wrong?
                    │         ├── YES → SAFE to auto-fix
                    │         └── NO  → REQUIRES CONFIRMATION
                    └── NO  → REQUIRES CONFIRMATION
```

---

## Safe Auto-Fixes

These fixes are deterministic, non-destructive, and reversible. Apply them without asking.

---

### FIX-01: Missing `version` field

**Pattern**: Frontmatter does not contain a `version` field.

**Applies to**: agents, skills, commands, output-styles

**Detection**:
```bash
# Detect missing version in an agent file
python3 -c "
import sys, re
content = open(sys.argv[1]).read()
fm = re.search(r'^---\n(.*?)\n---', content, re.DOTALL)
if fm and 'version:' not in fm.group(1):
    print('MISSING version:', sys.argv[1])
" path/to/agent.md
```

**Before**:
```yaml
---
name: code-reviewer
description: Performs code review. Use when reviewing pull requests.
tools: [Read, Grep, Glob]
---
```

**After**:
```yaml
---
name: code-reviewer
description: Performs code review. Use when reviewing pull requests.
tools: [Read, Grep, Glob]
version: 1.0.0
---
```

**Apply**:
```bash
# Insert version: 1.0.0 before the closing --- delimiter
sed -i '' '/^---$/{ /^---$/{N; /---/!{ s/^---$/---\nversion: 1.0.0/; }; }; }' path/to/agent.md
# Safer: use Python to inject after last existing frontmatter key
python3 - path/to/agent.md <<'EOF'
import re, sys
content = open(sys.argv[1]).read()
new = re.sub(r'(\n---\s*\n)', r'\nversion: 1.0.0\1', content, count=1)
open(sys.argv[1], 'w').write(new)
print("Fixed:", sys.argv[1])
EOF
```

**Re-validate**:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/evals/validate-agent.sh path/to/agent.md
```

---

### FIX-02: Field name case mismatch — `max-turns` → `maxTurns`

**Pattern**: Agent frontmatter uses `max-turns` (kebab-case) instead of the schema-required `maxTurns` (camelCase).

**Applies to**: agent files

**Detection**:
```bash
grep -r 'max-turns:' ${CLAUDE_PLUGIN_ROOT}/.claude-plugin/agents/ 2>/dev/null
```

**Before**:
```yaml
---
name: my-agent
description: An agent that does things.
tools: [Read]
max-turns: 5
---
```

**After**:
```yaml
---
name: my-agent
description: An agent that does things.
tools: [Read]
maxTurns: 5
---
```

**Apply**:
```bash
sed -i '' 's/^max-turns:/maxTurns:/' path/to/agent.md
```

**Re-validate**:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/evals/validate-agent.sh path/to/agent.md
```

---

### FIX-03: Agent name not in kebab-case

**Pattern**: The `name` field in agent frontmatter contains uppercase letters, spaces, or underscores.

**Applies to**: agent files

**Detection**:
```bash
python3 -c "
import re, sys
content = open(sys.argv[1]).read()
m = re.search(r'^name:\s*(.+)$', content, re.MULTILINE)
if m:
    name = m.group(1).strip()
    if not re.match(r'^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$', name):
        print('BAD NAME:', name, 'in', sys.argv[1])
" path/to/agent.md
```

**Before**:
```yaml
name: myAgent
```
or
```yaml
name: my_agent
```

**After**:
```yaml
name: my-agent
```

**Apply**:
```bash
python3 - path/to/agent.md <<'EOF'
import re, sys
content = open(sys.argv[1]).read()
def to_kebab(s):
    # camelCase → kebab-case
    s = re.sub(r'([A-Z])', r'-\1', s).lower().lstrip('-')
    # underscores → hyphens
    s = s.replace('_', '-')
    # collapse multiple hyphens
    s = re.sub(r'-+', '-', s).strip('-')
    return s
new = re.sub(r'^(name:\s*)(.+)$', lambda m: m.group(1) + to_kebab(m.group(2).strip()), content, flags=re.MULTILINE)
open(sys.argv[1], 'w').write(new)
print("Fixed:", sys.argv[1])
EOF
```

**Re-validate**:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/evals/validate-agent.sh path/to/agent.md
```

---

### FIX-04: Missing `model_rationale` when `model` is set

**Pattern**: Frontmatter contains a `model` field but no `model_rationale` field.

**Applies to**: agent files

**Detection**:
```bash
python3 -c "
import re, sys
content = open(sys.argv[1]).read()
has_model = bool(re.search(r'^model:', content, re.MULTILINE))
has_rationale = bool(re.search(r'^model_rationale:', content, re.MULTILINE))
if has_model and not has_rationale:
    print('MISSING model_rationale:', sys.argv[1])
" path/to/agent.md
```

**Before**:
```yaml
---
name: security-auditor
description: Audits code for security issues.
tools: [Read, Grep]
model: opus
---
```

**After**:
```yaml
---
name: security-auditor
description: Audits code for security issues.
tools: [Read, Grep]
model: opus
model_rationale: Uses opus for deeper reasoning over subtle vulnerability patterns
---
```

**Apply**:
```bash
python3 - path/to/agent.md <<'EOF'
import re, sys
content = open(sys.argv[1]).read()
m = re.search(r'^(model:\s*)(.+)$', content, re.MULTILINE)
if m:
    model_val = m.group(2).strip()
    rationale = f"Uses {model_val} for this task"
    new = re.sub(r'^(model:.+)$', r'\1\nmodel_rationale: ' + rationale, content, flags=re.MULTILINE)
    open(sys.argv[1], 'w').write(new)
    print("Fixed:", sys.argv[1])
EOF
```

**Note**: The placeholder rationale `"Uses {model} for this task"` is intentionally minimal. Flag it in the maintenance report so a human can write a meaningful rationale.

**Re-validate**:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/evals/validate-agent.sh path/to/agent.md
```

---

### FIX-05: Outdated tool name in `tools` or `allowed-tools`

**Pattern**: Frontmatter references a tool name that has been renamed in `tools-enum.json`.

**Applies to**: agent files, skill files

**Detection**:
```bash
# Read current valid tool names
python3 -c "
import json
with open('${CLAUDE_PLUGIN_ROOT}/schemas/tools-enum.json') as f:
    data = json.load(f)
valid = set(data['definitions']['toolName']['enum'])
print('Valid tools:', sorted(valid))
"

# Find tool names in an agent that aren't in the enum
python3 - path/to/agent.md ${CLAUDE_PLUGIN_ROOT}/schemas/tools-enum.json <<'EOF'
import json, re, sys, yaml
content = open(sys.argv[1]).read()
fm_match = re.search(r'^---\n(.*?)\n---', content, re.DOTALL)
if not fm_match:
    sys.exit(0)
fm = yaml.safe_load(fm_match.group(1))
with open(sys.argv[2]) as f:
    enum_data = json.load(f)
valid = set(enum_data['definitions']['toolName']['enum'])
tools = fm.get('tools', fm.get('allowed-tools', []))
if isinstance(tools, str):
    tools = [t.strip() for t in tools.split(',')]
for t in tools:
    if t not in valid:
        print(f"UNKNOWN TOOL: {t}")
EOF
```

**Before**:
```yaml
tools: [Read, FileStat, Grep]
```

**After** (assuming `FileStat` was renamed to `LS`):
```yaml
tools: [Read, LS, Grep]
```

**Apply**: Only apply if the rename mapping is definitive (from changelog). Do not guess.

```bash
# Replace a specific tool name (adjust OLD and NEW from changelog)
OLD="FileStat"
NEW="LS"
sed -i '' "s/\b${OLD}\b/${NEW}/g" path/to/agent.md
```

**Re-validate**:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/evals/validate-agent.sh path/to/agent.md
```

---

### FIX-06: Trailing whitespace in frontmatter values

**Pattern**: Frontmatter string values have trailing spaces or tabs.

**Applies to**: all `.md` files with frontmatter

**Detection**:
```bash
grep -nP ':\s+\S.*\s+$' path/to/file.md
```

**Apply**:
```bash
# Remove trailing whitespace from all lines in a file
sed -i '' 's/[[:space:]]*$//' path/to/file.md
```

**Re-validate**: Re-run the relevant component validator.

---

### FIX-07: Hook script not executable

**Pattern**: A hook script referenced in `hooks.json` exists on disk but lacks execute permission (`chmod +x`).

**Applies to**: hook script files (`.sh`)

**Detection**:
```bash
# Find .sh files in hooks/ that are not executable
find ${CLAUDE_PLUGIN_ROOT}/.claude-plugin/hooks/ -name '*.sh' ! -perm -u+x 2>/dev/null
```

**Before**: `-rw-r--r--  hooks/validate-skill-structure.sh`

**After**: `-rwxr-xr-x  hooks/validate-skill-structure.sh`

**Apply**:
```bash
chmod +x path/to/hooks/script.sh
```

**Re-validate**:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/evals/validate-hook.sh path/to/hooks/script.sh
```

---

## Unsafe Changes: Require Confirmation

Do NOT apply these changes automatically. Present them to the user with a before/after diff and wait for explicit approval.

---

### UNSAFE-01: Renaming a field

Fields like `PostToolUseFailure` → `PostToolError` in hook event names, or `system_prompt` → `systemPrompt` in agent frontmatter, change the semantics of existing configurations. Auto-renaming could silently break hooks or agents.

**Flag as**: `RENAME-REQUIRED — confirm before applying`

---

### UNSAFE-02: Removing a property from a schema

Removing a property from `properties` (even if `additionalProperties: false`) invalidates any existing file that uses that property.

**Flag as**: `SCHEMA-REMOVAL — requires manual review`

---

### UNSAFE-03: Changing `additionalProperties` from `false` to `true`

This changes schema validation behavior globally for that schema. It may mask real errors in plugin files.

**Flag as**: `SCHEMA-BEHAVIOR-CHANGE — requires manual review`

---

### UNSAFE-04: Adding a required field to a schema

Adding a field to `required` means all existing valid files that lack that field now fail validation. This is a breaking schema change.

**Flag as**: `BREAKING-SCHEMA-CHANGE — requires manual review`

---

### UNSAFE-05: Changing a field's type or enum values

Changing `model.enum` from `["opus", "sonnet", "haiku", "inherit"]` to a new list, or changing a string field to an object, can invalidate existing agent files.

**Flag as**: `TYPE-CHANGE — verify all existing files still validate`

---

### UNSAFE-06: Modifying plugin.json `name` or `version`

These fields affect plugin identity and update detection. Auto-bumping the version or renaming the plugin without user intent causes unintended registry churn.

**Flag as**: `IDENTITY-CHANGE — confirm with plugin author`

---

### UNSAFE-07: Deleting any file

No file should be deleted automatically during maintenance. This includes empty reference files, deprecated hook scripts, and superseded schema files.

**Flag as**: `FILE-DELETION — always requires user confirmation`

---

## Applying Fixes: General Procedure

1. Run the relevant validator to confirm the issue exists:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/evals/validate-agent.sh path/to/file.md
   ```

2. Record the before state (display the diff):
   ```bash
   git diff path/to/file.md  # or cat the file if not in git
   ```

3. Apply the fix using the commands in this catalog.

4. Re-run the validator to confirm the fix resolves the issue:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/evals/validate-agent.sh path/to/file.md
   ```

5. If validation still fails after the fix, stop and flag as `MANUAL-REQUIRED`.

6. Report all applied fixes in the maintenance report with:
   - File path
   - Fix ID (FIX-01 through FIX-07)
   - Before/after state (one-line summary)
