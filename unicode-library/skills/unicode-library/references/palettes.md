# Semantic Palettes

Pre-composed character sets for common CLI output patterns. Each palette is a complete, ready-to-use set -- pick the palette that matches your pattern and use the characters as specified.

Palettes are designed to scale: start with Minimal (3-4 chars), expand to Standard (6-8), or go Full when visual richness is justified.

---

## Status States

Show workflow or item status.

| Level | Pending | Active | Complete | Failed |
|-------|---------|--------|----------|--------|
| **Minimal** | `○` | `●` | `✓` | `✗` |
| **Standard** | `○` | `●` | `✓` | `✗` |
| **Full** | `○` pending | `●` active | `✓` passed | `✗` failed |

```
Minimal:  ○ Auth   ● Tests   ✓ Build   ✗ Deploy
Standard: ○ Pending  ● In Progress  ✓ Complete  ✗ Failed
```

**Extended status** (when you need more states):
| State | Character |
|-------|-----------|
| Not started | `○` |
| Queued | `◦` |
| In progress | `●` |
| Complete | `✓` |
| Failed | `✗` |
| Skipped | `▪` |
| Blocked | `▫` |

---

## Progress

Show completion or density.

| Level | Characters | Usage |
|-------|-----------|-------|
| **Minimal** | `░█` | Binary: empty/full |
| **Standard** | `░▒▓█` | 4-step gradient |
| **Full** | `░▒▓█` + percentage | Gradient with numeric label |

```
Minimal:  ████░░░░░░ 40%
Standard: ████▓▒░░░░ 40%
Full:     ████▓▒░░░░ 42% (18/43 files)
```

**Width rule:** Always use on own line. Never inline with text that needs column alignment.

---

## Hierarchy

Show parent-child, tree, or nesting relationships.

| Level | Characters | Pattern |
|-------|-----------|---------|
| **Minimal** | `•` `▸` `▪` | 3-level nesting |
| **Standard** | `◆` `▸` `▪` `▫` | 4-level with empty leaf |
| **Full** | `◆` `◇` `◈` `▸` `▪` `▫` | 6-level with semantic diamonds |

```
Minimal:
• Authentication
  ▸ OAuth2
    ▪ Token refresh

Standard:
◆ Authentication
  ▸ OAuth2 provider
    ▪ Token refresh
    ▫ PKCE flow (planned)

Full:
◆ Primary findings
◇ Secondary findings
◈ Annotated items
  ▸ Child detail
    ▪ Leaf item
    ▫ Empty leaf
```

---

## Separators

Divide sections or separate inline elements.

| Level | Characters | Usage |
|-------|-----------|-------|
| **Minimal** | `·` | Inline word separator |
| **Standard** | `·` `─` | Inline + line divider |
| **Full** | `·` `─` `━` `┄` `┈` | Full weight range |

**Weight ladder** (lightest to heaviest):
```
┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈    (quad dash -- whisper)
┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄    (triple dash -- soft)
────────────────────  (light -- standard divider)
━━━━━━━━━━━━━━━━━━━━  (heavy -- section break)
```

**Inline separator:**
```
extract · conserve · preserve        (middle dot as word separator)
Name ·· Value                        (double middle dot as label prefix)
```

---

## Borders & Frames

Frame content in boxes or panels.

| Style | Characters | When to use |
|-------|-----------|-------------|
| **Light** | `┌─┐│└┘` | Default, most contexts |
| **Rounded** | `╭─╮│╰╯` | Softer feel, modern tools |
| **None** | (indent only) | When borders add clutter |

```
Light:                    Rounded:
┌──────────────┐          ╭──────────────╮
│ Panel title  │          │ Panel title  │
├──────────────┤          ├──────────────┤
│ Content here │          │ Content here │
└──────────────┘          ╰──────────────╯
```

**Tree connectors** (for file trees, dependency graphs):
```
├── src/
│   ├── auth/
│   │   ├── login.ts
│   │   └── logout.ts
│   └── index.ts
└── README.md
```

---

## Arrows & Flow

Show direction, sequence, or transformation.

| Pattern | Example |
|---------|---------|
| **Sequence** | `Step 1 → Step 2 → Step 3` |
| **Bidirectional** | `Client ← → Server` |
| **Vertical flow** | `↓ Download  ↑ Upload` |
| **Drill-down** | `▸ Expand this section` |
| **Collapse** | `▾ Collapse this section` |

---

## Stars & Emphasis

Highlight important items or signal completion.

| Level | Characters | Usage |
|-------|-----------|-------|
| **Minimal** | `✦` only | Single emphasis marker |
| **Standard** | `✦` `✧` | Primary/secondary emphasis |
| **Full** | `✦` `✧` `◆` `◇` | Emphasis + hierarchy combined |

```
✦ Major achievement
✧ Notable observation
```

**Prefer `✦✧` over `★☆`** -- same visual impact, but Neutral East Asian Width (no CJK double-width risk).

---

## Sign-off & Branding

Branded completion line for skill output.

**Pattern:** `{density_gradient} {skill_name} ·· {mode}`

```
░▒▓ archaeology ·· survey
░▒▓ unicode-library ·· validate
```

**Components:**
- `░▒▓` -- strata gradient (density = depth, own line or line-start only)
- `··` -- label prefix (two middle dots)
- Skill name and mode in plain text

---

## Recommended Defaults

For agents that just need quick, safe output without designing a full visual system:

| Need | Use | Example |
|------|-----|---------|
| List items | `•` | `• Item one` |
| Sub-items | `▸` | `  ▸ Detail` |
| Success | `✓` | `✓ Tests pass` |
| Failure | `✗` | `✗ Build failed` |
| Section break | `─` (repeated) | `────────────` |
| Inline separator | `·` | `name · value` |
| Direction | `→` | `input → output` |

This 7-character set covers 90% of CLI output needs.

---

*Palettes version 1.0.0 -- derived from registry.md*
