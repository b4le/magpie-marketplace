# Archaeology Branding

Visual identity for the archaeology skill. All branded output elements are defined as variables below. Completion templates in `output-templates.md` reference these variables — change them here, they update everywhere.

---

## Variables

**Single source of truth.** Completion templates, init banner, and list output all resolve these.

```yaml
# Mode sigils — prefix completion titles
SIGIL_SURVEY:     "◈"
SIGIL_EXTRACTION: "◆"
SIGIL_WORKSTYLE:  "●"
SIGIL_CONSERVE:   "◇"
SIGIL_EXCAVATION: "✦"

# Sign-off — final line of every completion display
SIGNOFF_TEMPLATE: "░▒▓ archaeology ·· {mode}"

# Logo — strata mark above text (avoids ambiguous-width alignment issues)
LOGO_LINE_1: "░░░▒▒▒▓▓▓███▓▓▓▒▒▒░░░"
LOGO_LINE_2: "A R C H A E O L O G Y"
LOGO_LINE_3: "·· extract · conserve · preserve"

# Label prefix — used in init banner and field-style output
LABEL_PREFIX: "··"

# Strata blocks — density-equals-depth
STRATA_SURFACE: "▓"
STRATA_MIDDLE:  "▒"
STRATA_DEEP:    "░"
```

### How templates use these

Completion templates reference variables by name. When rendering:

1. Look up the mode sigil: `SIGIL_{MODE_UPPER}` (e.g., `SIGIL_SURVEY` for survey mode)
2. Prefix the completion title: `{sigil} Archaeology {Mode} Complete`
3. Append the sign-off as the final line: substitute `{mode}` in `SIGNOFF_TEMPLATE`

**Example resolution for survey:**
```
◈ Archaeology Survey Complete
...body...
░▒▓ archaeology ·· survey
```

---

## Design Language

### Marker Hierarchy

| Marker | Meaning | Usage |
|--------|---------|-------|
| `✦` | Celebration / complete | Completion states |
| `◆` | Primary finding | Domain extraction results |
| `◈` | Catalogued artifact | Survey domain entries, indexed items |
| `◇` | Preserved / exhibited | Conservation artifacts, exhibition items |

### Density Convention

Strata blocks use the density-equals-depth rule:

- `▓` — surface / recent / dense signal
- `▒` — middle layer / moderate depth
- `░` — deep / old / faint signal

Always read top-to-bottom as surface-to-deep.

### Label Prefix

Use `··` (two middle dots) as the field-label prefix for key-value pairs in branded output:

```
S U R V E Y  ◈  magpie-marketplace
```

---

## Logo

Compact mark (3 lines). Strata row sits above the text — dense at centre, fading outward. Block characters are on their own line so ambiguous terminal widths don't affect text alignment. Composed from `LOGO_LINE_1`, `LOGO_LINE_2`, `LOGO_LINE_3`.

```
░░░▒▒▒▓▓▓███▓▓▓▒▒▒░░░
A R C H A E O L O G Y
·· extract · conserve · preserve
```

---

## Init Banner

Displayed once when `/archaeology` is invoked, before command routing begins. Substitute `{MODE}` with the resolved command name. Substitute `{PROJECT}` with the resolved project name. Uses `LABEL_PREFIX` for the field markers.

```
░░░▒▒▒▓▓▓███▓▓▓▒▒▒░░░
A R C H A E O L O G Y
·· extract · conserve · preserve

{MODE_SPACED}  {SIGIL}  {PROJECT}
```

`{MODE_SPACED}` is the mode name in spaced uppercase (e.g., `S U R V E Y`), mirroring the logo rhythm. `{SIGIL}` is resolved from the mode sigils table and sits between mode and project as a separator jewel.

If no project (e.g., `list` mode), omit `{PROJECT}`:
```
L I S T  ◈
```

---

## Rendering Notes

All characters used are in the Basic Multilingual Plane and render correctly in iTerm2, Kitty, VS Code integrated terminal, and macOS Terminal.app:

- Block elements: `░▒▓█` (U+2591–U+2593, U+2588)
- Geometric shapes: `◆◇◈●` (U+25C6, U+25C7, U+25C8, U+25CF)
- Misc symbols: `✦` (U+2726)
- Middle dot: `·` (U+00B7)

No box-drawing characters, no emoji, no braille patterns. Maximum width: 42 characters. Safe on both light and dark backgrounds.

**Alignment note:** Block elements (░▒▓█) are "ambiguous width" Unicode — some terminal fonts render them as 2 columns instead of 1, breaking monospace alignment. The logo design keeps block characters on their own line (`LOGO_LINE_1`) so text lines (`LOGO_LINE_2`, `LOGO_LINE_3`) are unaffected by rendering width variance. Do not place block characters inline with text that needs column alignment.

---

*Design: Hybrid of "Geological Strata" (density convention, marker hierarchy) and "Explorer's Field Journal" (label prefix, field-record warmth).*
