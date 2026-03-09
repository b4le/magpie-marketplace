# Minimal Output Style Template

A bare-minimum template for creating quick, focused output styles. Use this when you need a simple formatting guideline without complex structure.

---

## Template

```yaml
name: style-name
purpose: Brief description of what this output style produces

structure:
  - section: Section Name
    format: paragraph | bullet-list | numbered-list | table | code-block
    content: Description of what content goes in this section

  - section: Another Section
    format: bullet-list
    content: What to include here

guidelines:
  - Keep it concise
  - Focus on clarity
  - Use consistent formatting
```

---

## Example Usage

**Style Definition:**
```yaml
name: bug-report
purpose: Standardized format for reporting bugs

structure:
  - section: Summary
    format: paragraph
    content: One-sentence description of the bug

  - section: Steps to Reproduce
    format: numbered-list
    content: Exact steps that trigger the bug

  - section: Expected vs Actual
    format: table
    content: Two-column comparison of expected and actual behavior

  - section: Environment
    format: bullet-list
    content: Relevant system/version information

guidelines:
  - Be specific and actionable
  - Include reproduction rate if known
  - Attach screenshots when relevant
```

**Output Example:**
```
# Bug Report: Login Button Unresponsive on Mobile

## Summary
Login button does not respond to tap events on iOS Safari when keyboard is visible.

## Steps to Reproduce
1. Open app in iOS Safari
2. Navigate to login page
3. Tap username field (keyboard appears)
4. Tap login button

## Expected vs Actual
| Expected | Actual |
|----------|--------|
| Login form submits | No response, button appears clickable but does not trigger |

## Environment
- iOS 17.1, Safari
- iPhone 14 Pro
- App version 2.3.1
- Reproducible 100% of the time
```

---

## When to Use This Template

Use the minimal template when:

- **Quick Style Creation** - You need an output style in minutes, not hours
- **Single-Purpose Formats** - The style serves one clear use case
- **Testing Concepts** - Experimenting with a style before committing to full specification
- **Personal Workflows** - Creating styles for individual use, not team-wide adoption
- **Simple Structures** - Output has 2-5 sections without complex nesting or conditional logic

Skip the minimal template when:

- Output requires conditional sections based on context
- Multiple output variants needed (e.g., summary vs detailed modes)
- Team standardization requires detailed examples and edge case handling
- Integration with other systems needs precise field specifications

---

## Expanding to Comprehensive

When your minimal style grows complex, migrate to the comprehensive template:

1. Copy your minimal YAML to `/templates/comprehensive-style.md`
2. Add `examples` section with 2-3 real-world samples
3. Define `variants` if multiple output modes needed
4. Add `validation` rules for quality checks
5. Include `integration` notes if used with other tools

See `comprehensive-style.md` for the full template structure.

---

## Quick Start Checklist

- [ ] Name is descriptive and unique
- [ ] Purpose clearly states what output is produced
- [ ] Each section has a defined format type
- [ ] Content descriptions are specific enough to guide output
- [ ] At least 2 guidelines included
- [ ] Example output demonstrates the structure
- [ ] File saved to `~/.claude/skills/authoring-output-styles/styles/{name}.md`
