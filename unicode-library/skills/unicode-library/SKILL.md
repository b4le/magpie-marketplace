---
name: unicode-library
description: This skill should be used when the user says "unicode", "character library", "CLI characters", "terminal symbols", "safe unicode", "validate characters", "what character should I use", "format output", "unicode for CLI", or when agents are creating visual CLI output, formatting terminal displays, choosing Unicode characters for branded skill output, designing completion banners or sign-off lines, checking whether a character is safe to use, looking up what character represents a concept (status, progress, hierarchy, flow), or when any skill or agent needs to validate that its output only uses approved characters. Also triggers on "anti-patterns", "banned characters", "smart quotes", "operator lookalikes", "EAW", "East Asian Width", "emoji in terminal", "progress bar characters", "spinner frames", "box drawing", "status indicators", or "what palette should I use".
argument-hint: "[lookup|validate|palette|anti-patterns] [category|palette-name] [--level minimal|standard|full]"
allowed-tools:
  - Read
  - Glob
  - Grep
version: 1.0.0
last_updated: 2026-03-08
---

# Unicode Library Skill

Curated reference library of ~50 approved Unicode characters for CLI visual design. Provides safety-rated characters, semantic palettes, banned character documentation, and integration guidance. This is a lookup and validation skill — it reads reference data and returns structured guidance.

## Invocation Patterns

```bash
/unicode-library                                    # Show recommended defaults (7-char set)
/unicode-library lookup                             # Same as bare invocation
/unicode-library lookup {category}                  # Characters from a specific registry category
/unicode-library palette {palette-name}             # Show palette at all levels
/unicode-library palette {palette-name} --level {level}   # Show palette at specific level
/unicode-library validate                           # Run validation checklist against output/branding
/unicode-library anti-patterns                      # Show banned characters and decision tree
```

**Category names** (for `lookup`):
`status` · `progress` · `hierarchy` · `arrows` · `separators` · `stars` · `box` · `spinners` · `suits`

**Palette names** (for `palette`):
`status-states` · `progress` · `hierarchy` · `separators` · `borders` · `arrows` · `stars` · `sign-off` · `defaults`

**Palette levels**: `minimal` · `standard` · `full`

---

## Execution Workflow

### Path Resolution

Set these paths once before any command routing:

```javascript
// The directory containing this SKILL.md file (resolve from the loaded skill path)
SKILL_DIR = dirname(this_skill_file);  // Do NOT hardcode — resolve relative to loaded SKILL.md
// Reference files
REGISTRY    = `${SKILL_DIR}/references/registry.md`;
PALETTES    = `${SKILL_DIR}/references/palettes.md`;
ANTI        = `${SKILL_DIR}/references/anti-patterns.md`;
INTEGRATION = `${SKILL_DIR}/references/integration.md`;
```

### Init Banner

Display the branded init banner before any command output:

```
░▒▓ unicode-library ·· {mode}
```

Where `{mode}` is the command name (`lookup`, `palette`, `validate`, `anti-patterns`, or `defaults`).

### Command Routing

Parse the invocation and route as follows:

```javascript
args = parse_arguments(user_input);

if (args.command === undefined || args.command === 'lookup' && !args.category) {
  // Default: show recommended defaults
  execute_defaults();
  return;
}

if (args.command === 'lookup' && args.category) {
  execute_lookup(args.category);
  return;
}

if (args.command === 'palette') {
  execute_palette(args.palette_name, args.level);
  return;
}

if (args.command === 'validate') {
  execute_validate();
  return;
}

if (args.command === 'anti-patterns') {
  execute_anti_patterns();
  return;
}
```

---

## Commands

### defaults — Recommended Defaults

**Trigger:** `/unicode-library` or `/unicode-library lookup` with no category.

Read `${PALETTES}`, extract the "Recommended Defaults" section.

Display the 7-character set that covers 90% of CLI output needs:

```
• list items
▸ sub-items
✓ success
✗ failure
─ section break (repeated)
· inline separator
→ direction / flow
```

Append: "This 7-character set covers 90% of CLI output needs. For more, use `/unicode-library lookup {category}` or `/unicode-library palette {palette-name}`."

---

### lookup — Registry Category

**Trigger:** `/unicode-library lookup {category}`

Read `${REGISTRY}`. Extract and display the requested category section.

**Category aliases** (accept any of these, map to the registry heading):

| Alias | Registry section |
|-------|-----------------|
| `status` | Status Indicators |
| `progress` | Progress & Density |
| `hierarchy` | Hierarchy & Structure |
| `arrows` | Arrows & Flow |
| `separators` | Separators & Dividers |
| `stars` | Stars & Emphasis |
| `box` | Box Drawing (Borders & Frames) |
| `spinners` | Spinners (Animation Frames) |
| `suits` | Card Suits & Miscellaneous |

Display the category table verbatim from the registry, including the usage example block.

If the requested category is not found, list available categories and suggest the closest match.

---

### palette — Semantic Palette

**Trigger:** `/unicode-library palette {palette-name}` or `/unicode-library palette {palette-name} --level {level}`

Read `${PALETTES}`. Extract the requested palette section.

**Palette aliases:**

| Alias | Palettes section |
|-------|-----------------|
| `status-states` | Status States |
| `progress` | Progress |
| `hierarchy` | Hierarchy |
| `separators` | Separators |
| `borders` | Borders & Frames |
| `arrows` | Arrows & Flow |
| `stars` | Stars & Emphasis |
| `sign-off` | Sign-off & Branding |
| `defaults` | Recommended Defaults |

If `--level` is provided (`minimal`, `standard`, or `full`), extract and display only the row for that level plus its usage example. If no level is specified, display the full palette table showing all three levels.

If the palette name is not found, list available palettes.

---

### validate — Character Safety Check

**Trigger:** `/unicode-library validate`

This command checks that a skill or agent's output uses only approved characters.

**Step 1: Locate the target**

Look for the most recently active skill's branding file. Check these locations in order:
1. `{cwd}/references/branding.md`
2. `{cwd}/branding.md`
3. Any `.md` file in `{cwd}/references/` that contains Unicode character definitions

If none found, ask the user: "What file or text should I validate? Paste content or provide a path."

**Step 2: Extract characters**

Read the target file. Extract every non-ASCII character (codepoint > U+007F). Build a list of unique characters with their codepoints.

**Step 3: Check registry**

Read `${REGISTRY}`. For each extracted character:
- If present in registry: mark PASS with its safety rating (Universal/Safe/Caution)
- If not in registry: mark FAIL — not an approved character

**Step 4: Check anti-patterns**

Read `${ANTI}`. For each extracted character:
- Check against Category 1 (operator lookalikes): FAIL if found
- Check against Category 2 (smart quotes): FAIL if found
- Check against Category 3 (emoji): WARN if found
- Check against Category 4 (braille for layout): WARN if found
- Check against Category 5 (unapproved dingbats): WARN if found
- Check against Category 6 (outside BMP): FAIL if found
- Check against Category 7 (combining characters): FAIL if found
- Check against Category 8 (width-ambiguous in alignment): INFO if found

**Step 5: Display results**

```
░▒▓ unicode-library ·· validate

Validation: {filename}
────────────────────────────────

PASS  ◆  U+25C6  registry: Hierarchy & Structure  [Safe]
PASS  ✓  U+2713  registry: Status Indicators       [Caution — EAW=Ambiguous]
FAIL  "  U+201C  anti-patterns: smart quote (Category 2) — breaks JSON parsing
WARN  ✅  U+2705  anti-patterns: emoji (Category 3) — inconsistent terminal width

Summary: {N} pass · {N} fail · {N} warn

{if failures}
Action required: Remove or replace FAIL characters before publishing.
  Smart quotes → use " (U+0022) and ' (U+0027)
  Operator lookalikes → remove entirely, use plain ASCII
{/if}
```

If zero failures and zero warnings: "All characters validated. No anti-pattern violations."

---

### anti-patterns — Banned Characters

**Trigger:** `/unicode-library anti-patterns`

Read `${ANTI}`. Display the full document, preserving all 8 categories and the decision tree.

Do not summarise or truncate. The full anti-patterns document is the output.

---

## Design Principles

These principles govern every recommendation this skill makes. Embed them in any output that advises on character selection:

**Prescriptive, not encyclopaedic.** This library contains ~50 curated characters. When a character is not in the registry, the answer is "don't use it" — not "let me find an alternative in the full Unicode range."

**Copy-paste safety is non-negotiable.** Operator lookalikes (em dash, fraction slash, angle quotes, long arrows) are BANNED. A character that looks right but pastes wrong is worse than no decoration.

**Smart quotes BANNED.** They break shell `eval` AND JSON parsing. Both failure modes are silent and hard to debug. Always use straight quotes: `'` (U+0027) and `"` (U+0022).

**One character = one semantic role.** Don't use `◆` for both "primary finding" and "deploy event" in the same output. Each character should mean exactly one thing in its context.

**East Asian Width tracked per character.** EAW=Ambiguous characters (marked Caution) render as 2 cells in CJK locales. For column-aligned output, use only EAW=Narrow (`→←↑↓`) or EAW=Neutral (`•◦▸▾▪▫△▽✦✧◆◇◈●○`) characters.

**Palette levels scale by permanence.** Minimal (3-4 chars) for ephemeral agent messages. Standard (6-8 chars) for skill completion displays. Full (registry as needed) for polished branded experiences.

**Block elements own the line.** `░▒▓█` are EAW=Ambiguous and may render as 1 or 2 cells. Never place them inline with text that needs column alignment. Use only on their own line.

---

## Completion Display

Every command ends with the sign-off line:

```
░▒▓ unicode-library ·· {mode}
```

This uses the strata gradient pattern from palettes.md:
- `░▒▓` — density gradient (own line only, never inline)
- `··` — double middle dot label prefix (U+00B7 twice)
- Skill name and mode in plain text
