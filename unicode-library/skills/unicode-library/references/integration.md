# Integration Guide

How to use the Unicode Library from other skills, commands, and agents.

---

## Referencing the Library

### From a Skill's Branding File

Add a reference comment at the top of your `branding.md`:

```yaml
# Character source: unicode-library/references/registry.md
# Palette: unicode-library/references/palettes.md (Standard level)
```

Then define your skill's visual variables using only characters from the registry:

```yaml
SIGIL_PRIMARY:   "◆"    # registry: Hierarchy & Structure
SIGIL_SECONDARY: "◇"    # registry: Hierarchy & Structure
STATUS_PASS:     "✓"    # registry: Status Indicators
STATUS_FAIL:     "✗"    # registry: Status Indicators
SEPARATOR:       "··"   # registry: Separators (middle dot)
DIVIDER:         "─"    # registry: Separators (box light horizontal)
```

### From Output Templates

When defining completion display templates, add enforcement rules:

```markdown
**Character enforcement:**
- All Unicode characters MUST come from unicode-library/references/registry.md
- See unicode-library/references/anti-patterns.md for banned characters
- Block elements (░▒▓█) only on their own line
- No emoji, no smart quotes, no operator lookalikes
```

---

## Choosing a Palette Level

Match decoration level to the context:

| Context | Level | Characters |
|---------|-------|-----------|
| Agent output, ephemeral messages | **Minimal** | `• ▸ ✓ ✗ → ─ ·` (7 chars) |
| Skill completion displays | **Standard** | Add `◆ ◇ ✦ ░▒▓` |
| Branded experiences (e.g., archaeology) | **Full** | Full registry as needed |
| Data files, JSON output | **None** | Plain text only |

**Principle:** Decoration should be proportional to the permanence and visibility of the output. Ephemeral agent messages need less; polished skill completions deserve more.

---

## Building a Design System

When creating a new branded skill:

### Step 1: Pick Your Semantic Markers

Choose characters from the hierarchy palette to represent your skill's domain concepts. Each concept gets ONE character:

```yaml
# Example: a "deploy" skill
SIGIL_DEPLOY:    "◆"    # Deployment event
SIGIL_ROLLBACK:  "◇"    # Rollback event
SIGIL_CANARY:    "◈"    # Canary check
STATUS_HEALTHY:  "●"    # Service healthy
STATUS_DEGRADED: "○"    # Service degraded
```

### Step 2: Choose Your Divider Weight

Pick from the weight ladder in palettes.md:

```
┈┈┈┈  whisper (internal sub-sections)
┄┄┄┄  soft (between related items)
────  standard (section breaks)
━━━━  heavy (major divisions)
```

### Step 3: Define Your Sign-Off

Follow the strata gradient pattern:

```
░▒▓ {skill-name} ·· {mode}
```

### Step 4: Document in branding.md

Create a `references/branding.md` in your skill directory. Include:
- All variables with their registry source
- Usage rules specific to your skill
- Rendering notes (max width, background safety, etc.)

See `archaeology/references/branding.md` for a complete example.

---

## Rules for Agents

When instructing an agent to produce formatted output:

### Do

```markdown
Use these characters for status output:
- ✓ for success, ✗ for failure (from unicode-library registry)
- • for list items, ▸ for sub-items
- ─ repeated for section dividers
```

### Don't

```markdown
Make the output look nice with Unicode decorations.
```

Agents need explicit character assignments, not aesthetic discretion. Without specific guidance, agents will reach for emoji, smart quotes, and other anti-pattern characters.

---

## Validation Checklist

Before finalising any branded output template:

- [ ] Every Unicode character appears in `registry.md`
- [ ] No characters from `anti-patterns.md` categories 1-7
- [ ] Block elements (`░▒▓█`) only on their own line
- [ ] No emoji anywhere
- [ ] No smart quotes (`''""`)
- [ ] Column-aligned content uses only EAW=Narrow or EAW=Neutral characters
- [ ] Characters tested in target terminal (iTerm2, VS Code at minimum)

---

## Cross-Reference: Archaeology Plugin

The archaeology plugin was the first consumer of this library. Its character usage maps to the registry as follows:

| Archaeology variable | Character | Registry section |
|---------------------|-----------|-----------------|
| `SIGIL_SURVEY` | `◈` | Hierarchy & Structure |
| `SIGIL_EXTRACTION` | `◆` | Hierarchy & Structure |
| `SIGIL_WORKSTYLE` | `●` | Status Indicators |
| `SIGIL_CONSERVE` | `◇` | Hierarchy & Structure |
| `SIGIL_EXCAVATION` | `✦` | Stars & Emphasis |
| `STRATA_*` | `░▒▓` | Progress & Density |
| `LABEL_PREFIX` | `··` | Separators & Dividers |
| `SIGNOFF_TEMPLATE` | `░▒▓ ··` | Progress + Separators |

All characters validated. No anti-pattern violations.

---

*Integration guide version 1.0.0*
