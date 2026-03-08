# Anti-Patterns

Characters that look appealing but MUST be avoided in CLI output. Each entry explains the specific failure mode.

---

## Category 1: Operator Lookalikes (BANNED)

These characters visually resemble functional shell/programming operators. When a user copies output containing these and pastes into a terminal or editor, the result silently differs from what they expect.

**This is the #1 copy-paste safety hazard.**

| Char | Codepoint | Name | Looks like | Why it's dangerous |
|------|-----------|------|------------|-------------------|
| `∷` | U+2237 | Proportion | `::` | Pasting `namespace∷method` won't resolve as `namespace::method`. Silent path/scope failure. |
| `›` | U+203A | Single right-angle quote | `>` | Could be confused with shell redirect. |
| `‹` | U+2039 | Single left-angle quote | `<` | Could be confused with shell redirect or heredoc. |
| `⁄` | U+2044 | Fraction slash | `/` | Path separator confusion. `src⁄main` won't resolve. |
| `∕` | U+2215 | Division slash | `/` | Same as `⁄`. |
| `⧸` | U+29F8 | Big solidus | `/` | Same risk, less common. |
| `﹥` | U+FE65 | Small greater-than | `>` | Shell redirect confusion. |
| `＞` | U+FF1E | Fullwidth greater-than | `>` | Fullwidth form; double-width rendering + redirect confusion. |
| `﹤` | U+FE64 | Small less-than | `<` | Shell redirect confusion. |
| `＜` | U+FF1C | Fullwidth less-than | `<` | Same risk as `＞`. |
| `≡` | U+2261 | Identical to | `===` | Could confuse readers comparing equality operators. |
| `≠` | U+2260 | Not equal to | `!=` | Same risk as `≡`. |
| `⟶` | U+27F6 | Long rightwards arrow | `->` | Looks like pointer/arrow operator in many languages. |
| `—` | U+2014 | Em dash | `--` | Looks like CLI flag prefix. `—verbose` won't parse as `--verbose`. |
| `–` | U+2013 | En dash | `-` | Looks like single hyphen/flag. |

**Rule:** If a user could reasonably paste the character thinking it's the ASCII equivalent, it's banned. No exceptions.

---

## Category 2: Smart Quotes (BANNED)

Smart/curly quotes break shell evaluation AND JSON parsing. They are the most common source of "it works in my doc but breaks when pasted" bugs.

| Char | Codepoint | Name | Failure mode |
|------|-----------|------|-------------|
| `'` | U+2018 | Left single quotation | Shell eval FAILS. `eval "var='value'"` with smart quotes = syntax error. |
| `'` | U+2019 | Right single quotation | Same as U+2018. |
| `"` | U+201C | Left double quotation | JSON parse FAILS. `{"key": "value"}` with smart quotes is invalid JSON. |
| `"` | U+201D | Right double quotation | Same as U+201C. |

**Verified by testing:** Shell `eval` and `python3 json.loads()` both fail with these characters.

**Common source:** Text editors, word processors, and some markdown renderers auto-convert straight quotes to smart quotes. Always verify output uses `'` (U+0027) and `"` (U+0022).

---

## Category 3: Emoji (AVOID)

Emoji have inconsistent rendering across terminals:
- **Width:** May render as 1 or 2 cells depending on terminal and font
- **Presentation:** May render as colour emoji (double-width) or text (single-width) unpredictably
- **Font fallback:** Triggers fallback to system emoji font, breaking monospace alignment

| Avoid | Use instead |
|-------|-------------|
| `✅` | `✓` (U+2713) |
| `❌` | `✗` (U+2717) |
| `⚠️` | Plain text `WARNING:` or `!` |
| `🔴🟢🟡` | `●` with ANSI colour |
| `📁` | Plain text or `▸` |
| `⭐` | `✦` (U+2726) |

**Rule:** Never use characters from the emoji presentation sequence list. If `U+FE0F` (emoji selector) could change its rendering, don't use it.

---

## Category 4: Braille Patterns for Layout (AVOID)

Braille characters (U+2800-28FF) are **safe for spinners** (animation frames) but should NOT be used for static layout or decoration:
- Accessibility concern: screen readers may try to interpret them as Braille text
- Visual meaning is opaque to most users
- The archaeology plugin explicitly bans them in completion displays

**Allowed:** Spinner frames (`⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏`)
**Banned:** Static patterns, art, or filler

---

## Category 5: Dingbats (MOSTLY AVOID)

Most characters in the Dingbats block (U+2700-27BF) have poor coverage in monospace fonts. They fall back to system fonts (often proportional), causing:
- Width misalignment
- Style clash (serif dingbat next to monospace text)
- Tofu on minimal systems

**Exceptions (in registry, safe to use):**
- `✓` (U+2713), `✗` (U+2717) -- check/cross
- `✦` (U+2726), `✧` (U+2727) -- four-pointed stars

**Not in registry but lower risk:**
- `✔` (U+2714), `✘` (U+2718) -- heavy check/cross. NOT in the approved registry. Prefer `✓`/`✗` instead. These have emoji presentation risk (U+FE0F could change rendering) and are not approved for branded output.

**Avoid everything else in U+2700-27BF** unless you've verified font coverage.

---

## Category 6: Characters Outside the BMP (BANNED)

Characters above U+FFFF (astral plane / supplementary planes) have poor terminal support:
- Some terminals can't render them at all
- Cursor positioning may break
- Width calculation fails

This includes:
- Legacy computing symbols (U+1FB00-1FB3B)
- Most newer emoji (U+1F600+)
- Musical symbols, mathematical alphanumeric symbols
- Egyptian hieroglyphs, etc.

**Rule:** Stick to the Basic Multilingual Plane (U+0000-FFFF).

---

## Category 7: Combining Characters (BANNED)

Combining diacritical marks (U+0300-036F) attach to the preceding character, creating a single glyph from multiple codepoints. This breaks:
- Cursor positioning (terminal thinks it's 2 chars, displays as 1)
- String length calculations
- Copy-paste alignment

**Banned:** All combining characters in decorative output. Use precomposed characters instead.

---

## Category 8: Width-Ambiguous in Alignment-Critical Contexts

These characters are in the registry but must NOT be used where column alignment matters:

| Char | Issue | Safe usage | Unsafe usage |
|------|-------|------------|-------------|
| `→←↑↓` | EAW=Ambiguous | Flow diagrams (Western locales) | Column-aligned tables in CJK contexts |
| `•` | EAW=Ambiguous | Bullet lists (Western locales) | Column-aligned lists in CJK contexts |
| `△▽` | EAW=Ambiguous | Decorative indicators (Western locales) | Column-aligned output in CJK contexts |
| `◆◇◈` | EAW=Ambiguous | Hierarchy markers (Western locales) | Column-aligned hierarchies in CJK contexts |
| `●○` | EAW=Ambiguous | Status indicators (Western locales) | Column-aligned status in CJK contexts |
| `▒▓█` | EAW=Ambiguous | Own line, gradient, progress bar | Inline with text needing alignment |
| `·` | EAW=Ambiguous | Inline separator (Western locales) | Column-aligned tables |
| `★☆` | EAW=Ambiguous | Decorative, non-aligned | Rating displays with other text |
| `♠♥♣` | EAW=Ambiguous | Decorative accents | Anywhere alignment matters |

**Rule:** Ambiguous-width characters are fine for decoration. They are NOT fine for structured, column-aligned output.

---

## Quick Decision Tree

```
Is it in the registry?
├─ No → Don't use it
└─ Yes → Is it in a column-aligned context?
   ├─ Yes → Is it EAW=Ambiguous?
   │  ├─ Yes → Don't use it here (find a Neutral alternative)
   │  └─ No → Safe to use
   └─ No → Is it in the anti-patterns list?
      ├─ Yes → Don't use it
      └─ No → Safe to use
```

---

*Anti-patterns version 1.0.0 -- Last validated: 2026-03-08*
