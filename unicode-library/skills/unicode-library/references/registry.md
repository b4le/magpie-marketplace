# Character Registry

Authoritative registry of approved Unicode characters for CLI visual design. Every character here has been tested for clipboard safety, shell compatibility, JSON encoding, and terminal rendering.

**Safety ratings:**
- **Universal** -- works everywhere, including legacy terminals
- **Safe** -- works on all modern terminals (iTerm2, Kitty, VS Code, Terminal.app, Windows Terminal, Alacritty)
- **Caution** -- works but has a documented edge case (noted in "Issues" column)

Characters not in this registry should not be used in branded output without explicit justification.

---

## Status Indicators

| Char | Codepoint | Name | Role | Safety | Issues |
|------|-----------|------|------|--------|--------|
| `✓` | U+2713 | Check mark | Success, complete, pass | Safe | EAW=Neutral. Check mark for success/completion. |
| `✗` | U+2717 | Ballot X | Failure, error, reject | Safe | EAW=Neutral. Ballot X for failure/rejection. |
| `●` | U+25CF | Black circle | Active, current, selected | Caution | EAW=Ambiguous; double-width in CJK locales. Industry standard for radio-on / active state. |
| `○` | U+25CB | White circle | Inactive, pending, unselected | Caution | EAW=Ambiguous; double-width in CJK locales. Pair with `●` for on/off states. |
| `•` | U+2022 | Bullet | In-progress, list item | Caution | EAW=Ambiguous; double-width in CJK locales. The safest bullet character. |
| `◦` | U+25E6 | White bullet | Secondary item, sub-list | Safe | EAW=Neutral. Lighter weight than `•`. |

**Usage example:**
```
✓ Tests passing        ✗ Lint failed
● Authentication       ○ Caching (not started)
• Implement login      ◦ Add rate limiting
```

---

## Progress & Density

| Char | Codepoint | Name | Role | Safety | Issues |
|------|-----------|------|------|--------|--------|
| `░` | U+2591 | Light shade | Empty, faint, deep | Safe | EAW=Neutral. Keep on own line or use only in sequences. |
| `▒` | U+2592 | Medium shade | Partial, moderate | Safe | EAW=Ambiguous; same width caveat as block elements. Keep on own line. |
| `▓` | U+2593 | Dark shade | Mostly full, dense, surface | Safe | EAW=Ambiguous; same width caveat as block elements. Keep on own line. |
| `█` | U+2588 | Full block | Complete, filled, maximum | Safe | EAW=Ambiguous. Built-in rendering in Alacritty/Kitty/Windows Terminal. Keep on own line. |

**Width rule:** Block elements may render as 1 or 2 columns depending on font/terminal settings. Never place inline with text that needs column alignment. Use on their own line.

**Usage example:**
```
░░░▒▒▒▓▓▓███▓▓▓▒▒▒░░░    (gradient line -- own line only)
Progress: ████████░░ 80%   (progress bar -- own line only)
```

---

## Hierarchy & Structure

| Char | Codepoint | Name | Role | Safety | Issues |
|------|-----------|------|------|--------|--------|
| `◆` | U+25C6 | Black diamond | Primary, top-level finding | Caution | EAW=Ambiguous; double-width in CJK locales. Strong visual weight. |
| `◇` | U+25C7 | White diamond | Secondary, preserved | Caution | EAW=Ambiguous; double-width in CJK locales. Lighter pair to `◆`. |
| `◈` | U+25C8 | Diamond containing dot | Annotated, catalogued | Caution | EAW=Ambiguous; double-width in CJK locales. Distinct from `◆`/`◇`; good for indexed items. |
| `▸` | U+25B8 | Small right triangle | Child, nested, drill-down | Safe | EAW=Neutral. Industry standard for tree child. |
| `▾` | U+25BE | Small down triangle | Expandable, collapsible | Safe | EAW=Neutral. Pair with `▸` for expand/collapse. |
| `▪` | U+25AA | Small black square | Leaf item, terminal node | Safe | EAW=Neutral. Compact marker for list endpoints. |
| `▫` | U+25AB | Small white square | Empty leaf, placeholder | Safe | EAW=Neutral. Lighter pair to `▪`. |
| `△` | U+25B3 | White up triangle | Increase, expand, parent | Caution | EAW=Ambiguous; double-width in CJK locales. |
| `▽` | U+25BD | White down triangle | Decrease, collapse, child | Caution | EAW=Ambiguous; double-width in CJK locales. |

**Usage example:**
```
◆ Authentication System
  ▸ OAuth2 provider
  ▸ Session management
    ▪ Token rotation
    ▪ Refresh logic
◇ Caching Layer (planned)
```

---

## Arrows & Flow

| Char | Codepoint | Name | Role | Safety | Issues |
|------|-----------|------|------|--------|--------|
| `→` | U+2192 | Rightwards arrow | Next, flow, yields | Caution | EAW=Ambiguous; double-width in CJK locales. The primary directional indicator. |
| `←` | U+2190 | Leftwards arrow | Back, previous, from | Caution | EAW=Ambiguous; double-width in CJK locales. |
| `↑` | U+2191 | Upwards arrow | Increase, upload, parent | Caution | EAW=Ambiguous; double-width in CJK locales. |
| `↓` | U+2193 | Downwards arrow | Decrease, download, child | Caution | EAW=Ambiguous; double-width in CJK locales. |

**Usage example:**
```
Input → Process → Output
v2.1.0 ↑ from v2.0.3
```

---

## Separators & Dividers

| Char | Codepoint | Name | Role | Safety | Issues |
|------|-----------|------|------|--------|--------|
| `─` | U+2500 | Box light horizontal | Standard divider line | Universal | Built-in rendering in modern terminals. |
| `━` | U+2501 | Box heavy horizontal | Strong divider, emphasis | Universal | Heavier visual weight than `─`. |
| `┄` | U+2504 | Box light triple dash | Dashed divider | Universal | Softer than solid `─`. |
| `┈` | U+2508 | Box light quad dash | Dotted divider | Universal | Lightest line weight. |
| `·` | U+00B7 | Middle dot | Inline separator, field prefix | Caution | EAW=Ambiguous; double-width in CJK locales. Extremely common; safe for Western-locale CLI tools. |
| `│` | U+2502 | Box light vertical | Vertical separator, gutter | Universal | Used by delta, lazygit, and most TUI frameworks. |

**Usage example:**
```
archaeology ·· survey                  (middle dot as label prefix)
────────────────────────               (section divider)
┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄                 (soft divider)
```

---

## Stars & Emphasis

| Char | Codepoint | Name | Role | Safety | Issues |
|------|-----------|------|------|--------|--------|
| `✦` | U+2726 | Black four-pointed star | Primary emphasis, celebration | Safe | EAW=Neutral. Good font coverage in Dingbats block. |
| `✧` | U+2727 | White four-pointed star | Secondary emphasis, aspiration | Safe | EAW=Neutral. Lighter pair to `✦`. |
| `★` | U+2605 | Black star | Rating, highlight | Caution | EAW=Ambiguous. Use `✦` instead when alignment matters. |
| `☆` | U+2606 | White star | Empty rating | Caution | EAW=Ambiguous. Use `✧` instead when alignment matters. |

**Guidance:** Prefer `✦✧` over `★☆` -- they have the same visual impact but Neutral East Asian Width, avoiding CJK double-width issues.

**Usage example:**
```
✦ Archaeology Excavation Complete
✧ Suggested next steps
Rating: ★★★☆☆                         (use only in non-aligned contexts)
```

---

## Box Drawing (Borders & Frames)

| Char | Codepoint | Name | Role | Safety | Issues |
|------|-----------|------|------|--------|--------|
| `┌` | U+250C | Light down and right | Top-left corner | Universal | |
| `┐` | U+2510 | Light down and left | Top-right corner | Universal | |
| `└` | U+2514 | Light up and right | Bottom-left corner | Universal | |
| `┘` | U+2518 | Light up and left | Bottom-right corner | Universal | |
| `├` | U+251C | Light vertical and right | Left tee | Universal | |
| `┤` | U+2524 | Light vertical and left | Right tee | Universal | |
| `┬` | U+252C | Light down and horizontal | Top tee | Universal | |
| `┴` | U+2534 | Light up and horizontal | Bottom tee | Universal | |
| `┼` | U+253C | Light vertical and horizontal | Cross junction | Universal | |
| `╭` | U+256D | Arc down and right | Rounded top-left | Safe | Falls back to `┌` on legacy Windows. |
| `╮` | U+256E | Arc down and left | Rounded top-right | Safe | Falls back to `┐` on legacy Windows. |
| `╰` | U+2570 | Arc up and right | Rounded bottom-left | Safe | Falls back to `└` on legacy Windows. |
| `╯` | U+256F | Arc up and left | Rounded bottom-right | Safe | Falls back to `┘` on legacy Windows. |

**Note:** Box-drawing characters have built-in programmatic rendering in Alacritty, Kitty, and Windows Terminal -- they bypass font glyphs entirely.

**Usage example:**
```
┌─────────────────┐      ╭─────────────────╮
│ Light borders   │      │ Rounded borders  │
└─────────────────┘      ╰─────────────────╯
```

---

## Spinners (Animation Frames)

| Set | Frames | Block | Safety | Notes |
|-----|--------|-------|--------|-------|
| Braille dots | `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏` | U+2800 | Safe | Industry standard (ora, gh, charm). Smooth single-cell animation. |
| Braille heavy | `⣾⣽⣻⢿⡿⣟⣯⣷` | U+2800 | Safe | Used by charm.sh bubbletea. |
| Block pulse | `█▓▒░▒▓` | U+2588-91 | Safe | Density-based pulse. Keep on own line. |
| ASCII line | <code>\|/-\\</code> | ASCII | Universal | Fallback for legacy terminals. |

---

## Card Suits & Miscellaneous

| Char | Codepoint | Name | Role | Safety | Issues |
|------|-----------|------|------|--------|--------|
| `♦` | U+2666 | Black diamond suit | Category marker, variant | Safe | EAW=Neutral. |
| `♠` | U+2660 | Black spade suit | Category marker, variant | Caution | EAW=Ambiguous; double-width in CJK locales. |
| `♥` | U+2665 | Black heart suit | Favourite, liked | Caution | EAW=Ambiguous; double-width in CJK locales. |
| `♣` | U+2663 | Black club suit | Category marker, variant | Caution | EAW=Ambiguous; double-width in CJK locales. |

**Guidance:** `♠♥♣` are EAW=Ambiguous; `♦` is EAW=Neutral. Use Ambiguous suits sparingly and only in non-aligned decorative contexts.

---

## Quick Reference: Safety by East Asian Width

| EAW Property | Meaning | Characters in this registry |
|---|---|---|
| **Neutral** (N) | Always 1 cell. Safe everywhere. | `◦▸▾▪▫✦✧✓✗♦░` |
| **Ambiguous** (A) | 1 cell in Western locales, 2 cells in CJK. | `→←↑↓•△▽◆◇◈●○·★☆♠♥♣▒▓█` |

For alignment-sensitive output, prefer Narrow/Neutral characters. Use Ambiguous characters only where width variance won't break layout (own line, decorative context, non-aligned).

---

*Registry version 1.0.0 -- Last validated: 2026-03-08*
*Tested on: macOS 15, iTerm2, VS Code integrated terminal*
*Test coverage: clipboard round-trip, shell eval, JSON parse, terminal width*
