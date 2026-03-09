---
name: pickup
description: >-
  Invoke on "/pickup", "pick up where I left off", "resume", "where did I
  leave off", "catch me up", "load the handoff", "what was I working on",
  or "continue from last session". Finds the most recent handoff, shows
  context, detects git drift, and offers to load referenced files.
user-invocable: true
---

# Manual Session Pickup

Find and load the best available handoff for the current branch, detect any drift since it was written, and offer to load referenced files.

## Lookup Priority

1. Most recent `{branch}_*.md` in `.claude/handoffs/` (manual or auto handoff)
2. `.checkpoint_{branch}.md` in `.claude/handoffs/` (compaction checkpoint)
3. Git-state inference (branch, recent commits, modified files)

## Steps

1. **Find the handoff:**
   - Determine current branch: `git rev-parse --abbrev-ref HEAD`
   - Sanitize branch name (slashes → dashes)
   - Look in `.claude/handoffs/` using the priority order above
   - Legacy fallback: `~/.claude/handoff.md` (for pre-plugin installations)
   - If nothing found, say so and offer to start fresh
   - **Collision selection:** If multiple `{branch}_*.md` files exist within 1 hour of each other, present a numbered list:
     1. Each option shows: timestamp, HEAD SHA (from file content), type (manual = `# Session Handoff` / auto = `# Session Handoff (auto)`)
     2. Include a final option: "Skip all and start fresh"
     3. Wait for user to choose before proceeding to Step 2
   - If auto-resume sent the user here via collision detection, skip the "already loaded" acknowledgement and go straight to the selection list

2. **Display the handoff:**
   - Read and display the full handoff content
   - State which type was found (manual handoff / auto handoff / checkpoint / git inference)
   - Distinguish manual handoffs (header: `# Session Handoff`) from auto handoffs (header: `# Session Handoff (auto)`) by reading the file content.

3. **Detect drift:**
   - Compare handoff HEAD SHA to current HEAD: `git log --oneline {handoff_sha}..HEAD`
   - Check for new modified files not mentioned in the handoff
   - If drift detected, summarize: "N new commits since handoff" and list them
   - If the handoff is more than 24 hours old, warn: "This handoff is N days old and may not reflect current state. Consider running /handoff to create a fresh one."

4. **Offer to load context:**
   - If the handoff mentions specific files in "Files touched" or "How to continue", offer to read them
   - Ask: "Want me to load the referenced files into context?"

5. **Post-selection cleanup:**
   - After a handoff is chosen from a collision list, offer to clean up the unchosen handoff files
   - Ask: "Delete the other handoff(s) to avoid this prompt next time?"
   - If the user chose "Skip all and start fresh", offer to delete all handoffs for this branch

> **Note:** If auto-resume already loaded context at session start, acknowledge this: "Handoff was already loaded automatically. Showing full details with drift analysis."

## Output Format

Start with a brief summary, then show the full handoff, then drift analysis:

```
**Found:** [manual handoff | auto handoff | checkpoint | git inference] from [timestamp]
**Drift:** [N new commits | no changes | modified files changed]

---
[full handoff content]
---

[drift details if any]
[offer to load files]
```
