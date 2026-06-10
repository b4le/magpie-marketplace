---
phase: REPLACE_WITH_PHASE          # planning | research | design | execution | review
author_agent: REPLACE_WITH_AGENT_ID  # e.g., agent-005
created_at: REPLACE_WITH_TIMESTAMP   # YYYY-MM-DDTHH:MM:SSZ
topic: REPLACE_WITH_TOPIC            # Brief topic description
folder_purpose: REPLACE_WITH_PURPOSE # Why this output requires multiple files
total_files: 0                       # Count of files in this folder (excluding this README)
total_tokens: 0                      # Approximate total tokens across all files
---

# READ FIRST: [Topic Title]

## Folder Overview

This folder contains **multi-file output** from agent-[id] for the [topic] task.

**Why Multiple Files?**
[1-2 sentence explanation of why output couldn't be in single file]

Example: "Database schema design required both structured schema definition (JSON) and narrative migration guide (Markdown). Splitting enables direct consumption by tools (schema.json) while preserving human-readable documentation (migrations.md)."

---

## Quick Summary

[2-3 sentence summary of what this folder contains and accomplishes]

Example: "Complete database schema for authentication system with 8 tables, normalized to 3NF. Includes JSON schema for programmatic use, migration scripts for database setup, and rationale document explaining design decisions. Ready for implementation phase to consume."

---

## Files in This Folder

### 1. [filename1.ext]

**Purpose**: [What this file contains]
**Format**: [markdown | JSON | YAML | SQL | etc.]
**Size**: ~[approximate tokens or lines]

**When to Use**:
- [Scenario 1 when this file is relevant]
- [Scenario 2 when this file is relevant]

**Key Contents**:
- [Key element 1]
- [Key element 2]
- [Key element 3]

**Read This If**: [Who should read and why]

---

### 2. [filename2.ext]

**Purpose**: [What this file contains]
**Format**: [markdown | JSON | YAML | SQL | etc.]
**Size**: ~[approximate tokens or lines]

**When to Use**:
- [Scenario 1 when this file is relevant]
- [Scenario 2 when this file is relevant]

**Key Contents**:
- [Key element 1]
- [Key element 2]

**Read This If**: [Who should read and why]

---

### 3. [filename3.ext]

[Follow same structure for each file in folder]

---

## Reading Order

### For Orchestrators (Quick Context)

**Recommended Order**:
1. **This file** (READ-FIRST.md) - Overview and navigation (you are here)
2. **[filename1.ext]** - [Why read this next]
3. Skip other files unless deep dive needed

**Estimated Time**: 5 minutes for quick context

---

### For Sub-Agents (Full Context)

**Recommended Order**:
1. **This file** (READ-FIRST.md) - Understanding folder structure
2. **[filename2.ext]** - [Why read this first for agents]
3. **[filename1.ext]** - [Why read this second]
4. **[filename3.ext]** - [Why read this last]

**Estimated Time**: 15-20 minutes for comprehensive understanding

---

### For Implementation (Direct Use)

If you're implementing based on this output:

**Critical Files**:
- **[filename1.ext]** - Use this for [specific purpose]
- **[filename2.ext]** - Reference this when [specific scenario]

**Optional Files**:
- **[filename3.ext]** - Context/rationale, not required for implementation

---

## File Dependencies

[Show relationships between files if any]

```
[filename1.ext] (schema)
    ↓ referenced by
[filename2.ext] (migrations)
    ↓ explained in
[filename3.ext] (rationale)
```

**Dependency Notes**:
- [filename2.ext] assumes [filename1.ext] is applied first
- [filename3.ext] provides context but not required for execution

---

## Usage Examples

### Example 1: Implementing from This Output

```bash
# For implementation phase:
1. Review schema.json to understand table structure
2. Run migrations.sql to create database tables
3. Reference rationale.md if questions arise about design decisions
```

### Example 2: Reviewing for Validation

```bash
# For review phase:
1. Read rationale.md to understand design decisions
2. Check schema.json against requirements
3. Validate migrations.sql for correctness
```

### Example 3: Extracting Specific Information

**To find**: "Why was table X normalized?"
**Read**: `rationale.md` → Section 3: Normalization Decisions

**To find**: "What are the foreign key constraints?"
**Read**: `schema.json` → Look for `"foreignKeys"` property

**To find**: "How to create table X?"
**Read**: `migrations.sql` → Search for `CREATE TABLE X`

---

## Key Decisions in This Output

[List 3-5 key decisions represented in these files]

1. **Decision**: [What was decided]
   - **File**: [Which file contains this]
   - **Rationale**: [Why this decision]
   - **Impact**: [What this affects]

2. **Decision**: [What was decided]
   - **File**: [Which file contains this]
   - **Rationale**: [Why this decision]
   - **Impact**: [What this affects]

3. **Decision**: [What was decided]
   [Follow same structure]

---

## Integration with Other Outputs

### This Output Uses

[List files/outputs from previous agents/phases that informed this work]

- `archive/planning-[timestamp]/agent-001-requirements.md` - Used for understanding user needs
- `shared/decisions.md` - Referenced for architecture constraints
- External: [Any external docs, APIs, etc.]

### This Output Informs

[List what future agents/phases should consume from this output]

- **Implementation phase** should use `schema.json` for database creation
- **Testing phase** should validate against schema in `schema.json`
- **Documentation phase** should reference `rationale.md` for design explanations

---

## Validation Checklist

[Checklist for reviewing this output]

**Completeness**:
- [ ] All files present and properly named
- [ ] Each file has required content
- [ ] No placeholder content (all REPLACE_WITH_* updated)
- [ ] File formats correct (valid JSON, proper Markdown, etc.)

**Quality**:
- [ ] Decisions clearly explained in rationale file
- [ ] Code/schemas follow project conventions
- [ ] Examples provided where helpful
- [ ] Edge cases considered

**Usability**:
- [ ] Clear navigation via this READ-FIRST.md
- [ ] Files can be consumed independently if needed
- [ ] Dependencies clearly documented

---

## Questions and Next Steps

### Potential Questions

**Q: "Can I modify these files?"**
A: Once archived, these become historical. If changes needed, create new versions in current phase.

**Q: "Which file is the 'main' output?"**
A: [Identify which file is most important, e.g., "schema.json is primary, others are supporting"]

**Q: "Do I need to read all files?"**
A: No. See "Reading Order" section above based on your role (orchestrator/agent/implementer).

### Next Steps for This Output

[What should happen with this output]

1. **Immediate**: Orchestrator reviews for validation
2. **Next Phase**: Implementation agent consumes [primary file]
3. **Archival**: This folder moves to `archive/[phase]-[timestamp]/` when phase completes

---

## Metadata

**Agent**: [agent_id]
**Phase**: [phase]
**Topic**: [topic]
**Created**: [created_at]
**Total Files**: [count] (excluding this README)
**Total Tokens**: ~[approximate across all files]

**Return JSON**:
```json
{
  "status": "finished",
  "output_paths": [
    "active/[phase]/agent-[id]-[topic]/READ-FIRST.md",
    "active/[phase]/agent-[id]-[topic]/[file1]",
    "active/[phase]/agent-[id]-[topic]/[file2]"
  ],
  "questions": [],
  "summary": "[2-3 sentence summary from Quick Summary section above]",
  "tokens_used": [total_tokens],
  "next_phase_context": "[From Integration > This Output Informs section]"
}
```

---

## File Structure

```
agent-[id]-[topic]/
├── READ-FIRST.md           # You are here
├── [filename1.ext]         # [Brief description]
├── [filename2.ext]         # [Brief description]
├── [filename3.ext]         # [Brief description]
└── [additional files...]   # [If any]
```

---

## Template Notes

**For Agents Creating Multi-File Outputs**:
1. Create folder: `agent-{id}-{topic}/`
2. Add all output files to folder
3. Create THIS file (READ-FIRST.md) explaining folder contents
4. Update all REPLACE_WITH_* placeholders
5. List all files with clear purpose statements
6. Provide reading order for different audiences
7. Return path to READ-FIRST.md in output_paths

**For Agents Reading Multi-File Outputs**:
1. Always start with READ-FIRST.md
2. Follow recommended reading order for your role
3. Don't try to read all files unless necessary
4. Use "Usage Examples" section as guide
5. Reference "File Dependencies" to understand relationships

**Best Practices**:
- Keep individual files focused (single responsibility)
- Separate structured data (JSON/YAML) from narrative (Markdown)
- Separate generated code from documentation
- Explain WHY files are split (in Folder Overview)
- Provide navigation (reading order, dependencies)

---

**Template Version**: 1.0.0
**Last Updated**: 2025-11-24
