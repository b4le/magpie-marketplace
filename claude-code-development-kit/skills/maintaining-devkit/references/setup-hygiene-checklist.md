# Setup Hygiene Checklist

**Purpose**: Audit `~/.claude/` for accumulated entropy — stale plugins, empty todo files, disk bloat, settings drift, and security issues — and produce a prioritized list of cleanup actions.

---

## Quick Reference: Cleanup Schedule

| Frequency | Checks to run |
|-----------|---------------|
| Daily | Empty todo files, orphaned background job output |
| Weekly | Disk usage, disabled-plugin review |
| Monthly | Stale team review, settings drift, dead plugin references |
| Quarterly | Security audit, full cleanup pass |

---

## 1. Disk Usage Audit

Run these commands to understand what is consuming space inside `~/.claude/`:

```bash
# Total size of ~/.claude/
du -sh ~/.claude/

# Breakdown by top-level subdirectory, sorted largest first
du -sh ~/.claude/*/ 2>/dev/null | sort -rh

# Identify directories consuming more than 10 MB
du -sh ~/.claude/**/ 2>/dev/null | sort -rh | awk '{ if ($1 ~ /[0-9]+M/ && $1+0 >= 10) print }'

# Find large individual files (over 1 MB)
find ~/.claude/ -type f -size +1M -exec ls -lh {} \; 2>/dev/null | sort -k5 -rh

# Summarise log file sizes (common entropy source)
du -sh ~/.claude/logs/ 2>/dev/null || echo "No logs directory"
```

**Action thresholds**:

| Total size | Action |
|------------|--------|
| < 100 MB | No action needed |
| 100–500 MB | Review logs and background job output |
| > 500 MB | Full cleanup pass required |

---

## 2. Empty Todo File Detection and Cleanup

Empty or near-empty todo files accumulate when tasks are created and immediately resolved. Detect and clean them:

```bash
# Count JSON todo files smaller than 4 bytes (empty array or blank)
find ~/.claude/todos -name '*.json' -size -4c 2>/dev/null | wc -l

# List them by name
find ~/.claude/todos -name '*.json' -size -4c 2>/dev/null

# Show files containing only an empty array []
find ~/.claude/todos -name '*.json' 2>/dev/null -exec python3 -c "
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
if not data:
    print(path)
" {} \;

# Preview a todo file before deleting
cat ~/.claude/todos/<filename>.json

# Delete a specific empty todo file
rm ~/.claude/todos/<filename>.json

# Bulk delete all empty-array todo files (run preview first)
find ~/.claude/todos -name '*.json' -size -4c -delete 2>/dev/null
```

**Safety**: Always run the list command before the delete command. Never bulk-delete without previewing the list.

---

## 3. Stale Plugin Identification

### 3a. Disabled plugins

Identify plugins that have been disabled and may no longer be needed:

```bash
# List all disabled plugins in installed_plugins.json
python3 - ~/.claude/installed_plugins.json <<'EOF'
import json, sys
from datetime import date, timedelta

with open(sys.argv[1]) as f:
    plugins = json.load(f)

cutoff = date.today() - timedelta(days=30)
print(f"{'Name':<40} {'Enabled':<10} {'Installed':<12} {'Source'}")
print("-" * 80)

for p in plugins if isinstance(plugins, list) else plugins.get("plugins", []):
    enabled = p.get("enabled", True)
    installed = p.get("installedAt", "unknown")
    name = p.get("name", p.get("id", "?"))
    source = p.get("source", p.get("path", "?"))
    if not enabled:
        print(f"{name:<40} {'DISABLED':<10} {installed:<12} {source}")
EOF
```

A plugin disabled for more than 30 days with no recent activity is a candidate for removal.

### 3b. Plugins no longer on disk

Detect plugin references in `installed_plugins.json` that point to paths that no longer exist:

```bash
python3 - ~/.claude/installed_plugins.json <<'EOF'
import json, os, sys

with open(sys.argv[1]) as f:
    plugins = json.load(f)

for p in plugins if isinstance(plugins, list) else plugins.get("plugins", []):
    path = p.get("path", "")
    if path and not os.path.exists(path):
        name = p.get("name", p.get("id", "?"))
        print(f"DEAD PATH  {name}: {path}")
EOF
```

### 3c. Plugins not in the marketplace

If a plugin was installed from a local path that has since been deleted or moved, it will appear in `installed_plugins.json` but not be functional:

```bash
# Check that each local plugin path exists and contains a plugin.json
python3 - ~/.claude/installed_plugins.json <<'EOF'
import json, os, sys

with open(sys.argv[1]) as f:
    plugins = json.load(f)

for p in plugins if isinstance(plugins, list) else plugins.get("plugins", []):
    path = p.get("path", "")
    if not path:
        continue
    plugin_json = os.path.join(path, "plugin.json")
    if not os.path.exists(plugin_json):
        name = p.get("name", p.get("id", "?"))
        print(f"NO plugin.json  {name}: {path}")
EOF
```

---

## 4. Team Archival Criteria

Teams with no session activity in the past 30 days consume configuration space and can create confusing state. Identify them:

```bash
# List all teams and their last-activity timestamps
ls -lt ~/.claude/teams/ 2>/dev/null | head -20

# Find team directories not modified in the past 30 days
find ~/.claude/teams/ -maxdepth 1 -type d -not -newer ~/.claude/teams/ -mtime +30 2>/dev/null

# Check for teams with empty message history
find ~/.claude/teams/ -name 'messages.json' -size -10c 2>/dev/null
```

**Archival criteria** — flag a team for review if ALL of the following are true:

1. No session file modified in the past 30 days
2. No pending tasks in the team's todo files
3. The project or feature the team was working on is complete or cancelled

**Do not** automatically delete teams. Present findings to the user for confirmation.

---

## 5. Settings Drift Detection

Settings can be set at the global level (`~/.claude/settings.json`) and overridden at the project level (`.claude/settings.json` in each project). Drift occurs when project-level overrides conflict with global intent.

### 5a. Inspect global settings

```bash
# View global settings
cat ~/.claude/settings.json | python3 -m json.tool

# Check which keys are set globally
python3 -c "
import json
with open('$HOME/.claude/settings.json') as f:
    s = json.load(f)
for k, v in sorted(s.items()):
    print(f'{k}: {v}')
"
```

### 5b. Detect project-level overrides

```bash
# Find all project-level settings files
find ~/. -name '.claude/settings.json' -not -path '~/.claude/settings.json' 2>/dev/null | head -20

# Compare a project override against global settings
python3 - ~/.claude/settings.json /path/to/project/.claude/settings.json <<'EOF'
import json, sys

with open(sys.argv[1]) as f:
    global_s = json.load(f)
with open(sys.argv[2]) as f:
    project_s = json.load(f)

overrides = {}
for k, v in project_s.items():
    if k in global_s and global_s[k] != v:
        overrides[k] = {"global": global_s[k], "project": v}
    elif k not in global_s:
        overrides[k] = {"global": "(not set)", "project": v}

if overrides:
    print("Project overrides global settings:")
    for k, vals in overrides.items():
        print(f"  {k}: {vals['global']} -> {vals['project']}")
else:
    print("No overrides found.")
EOF
```

### 5c. Flags to check

Review these specific settings for unexpected values:

| Setting key | Concern | Safe value |
|-------------|---------|-----------|
| `autoUpdaterStatus` | If set to `disabled`, devkit won't self-update | `enabled` |
| `preferredNotifChannel` | Verify matches current notification setup | varies |
| Any key containing `dev`, `debug`, or `test` | May be a leftover dev-mode flag | Remove |

---

## 6. Security Checks

### 6a. Secrets in settings files

Settings files should never contain API keys, tokens, or passwords:

```bash
# Scan settings files for common secret patterns
grep -rE '(api_key|apikey|token|secret|password|passwd|credential|auth)' \
  ~/.claude/settings.json \
  ~/.claude/settings.local.json 2>/dev/null

# Scan for common secret value shapes (base64-like strings, JWT prefixes)
grep -rE '(ghp_|sk-|Bearer |eyJ[A-Za-z0-9])' \
  ~/.claude/*.json 2>/dev/null
```

If secrets are found: remove them immediately and rotate the exposed credentials.

### 6b. Dev-mode OAuth flags

OAuth tokens issued in dev mode may have broader scopes than production tokens. Check for residual dev-mode flags:

```bash
# Look for dev-mode flags in any settings file
grep -rE '(devMode|dev_mode|oauth.*dev|debug.*true)' ~/.claude/ 2>/dev/null

# Check for localhost/127.0.0.1 OAuth redirect URIs
grep -rE '(localhost|127\.0\.0\.1)' ~/.claude/*.json 2>/dev/null
```

### 6c. World-readable sensitive files

```bash
# Check permissions on sensitive Claude config files
ls -la ~/.claude/settings.json ~/.claude/installed_plugins.json 2>/dev/null

# These files should be owner-readable only (600) or owner-read/write (644 is acceptable)
# If group or other has write permission, fix it:
chmod 644 ~/.claude/settings.json
```

---

## 7. Recommended Cleanup Schedule

### Daily (< 2 minutes)

- [ ] Check for empty todo files: `find ~/.claude/todos -name '*.json' -size -4c | wc -l`
- [ ] Review any background job output files older than 24 hours

### Weekly (5–10 minutes)

- [ ] Run disk usage summary: `du -sh ~/.claude/*/`
- [ ] Review disabled plugins: any disabled > 7 days with no scheduled re-enable?
- [ ] Check for dead plugin paths in `installed_plugins.json`

### Monthly (15–20 minutes)

- [ ] Full disabled-plugin review (> 30 days disabled → remove or re-enable)
- [ ] Team archival review (> 30 days inactive → confirm with user)
- [ ] Settings drift scan (project overrides vs global)
- [ ] Rotate any credentials referenced in hook scripts

### Quarterly (30–45 minutes)

- [ ] Security audit (secrets scan, file permissions, dev-mode flags)
- [ ] Full disk audit with large-file identification
- [ ] Remove orphaned log files older than 90 days
- [ ] Re-validate all installed plugins: `bash ${CLAUDE_PLUGIN_ROOT}/evals/validate-plugin.sh <path>` for each

---

## 8. Generating the Hygiene Report

The maintenance report template expects a hygiene section. Populate it with:

```
## Setup Hygiene

| Check | Status | Count | Action |
|-------|--------|-------|--------|
| Empty todo files | OK/WARN | N | Delete N files |
| Disabled plugins (>30d) | OK/WARN | N | Review N plugins |
| Dead plugin paths | OK/WARN | N | Remove N entries |
| Stale teams (>30d) | OK/WARN | N | Archive N teams |
| Settings drift | OK/WARN | N keys | Review overrides |
| Security (secrets) | OK/FAIL | N | Rotate N credentials |
| Disk usage | OK/WARN | X MB | Free X MB |
```

Report overall hygiene as:
- **CLEAN** — all checks OK, no action needed
- **WARN** — minor items to address (empty files, small drift)
- **ACTION REQUIRED** — security issues or > 500 MB disk usage
