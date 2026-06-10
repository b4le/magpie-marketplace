# Troubleshooting Guide

## Overview

This guide provides solutions to common issues encountered when using the multi-agent-workflows skill.

---

## Common Issues

### Workflow State Issues

**Problem**: "Cannot find workflow-state.yaml"
**Cause**: Workflow not initialized
**Solution**:
- Create .development/workflows/{workflow-id}/ structure and populate workflow-state.yaml from template
- Use template: `templates/workflow-state.yaml`

**Problem**: "STATUS.yaml out of sync with reality"
**Cause**: Sub-agents not updating status
**Solution**:
- Enforce status updates in sub-agent prompts (include in protocol)
- Review STATUS.yaml manually and update if needed

**Problem**: "Concurrent workflows colliding"
**Cause**: Using same workflow-id for multiple workflows
**Solution**:
- Use unique workflow IDs (include timestamp or feature name)
- Example: `feature-auth-20251124`, `refactor-api-v2`

### Context Management Issues

**Problem**: "Orchestrator context bloat (>30K tokens)"
**Cause**: Reading full archived phase files instead of summaries
**Solution**:
- Read only archive/{phase}-{timestamp}/phase-summary.md, not raw agent outputs
- Use phase summaries for context handoff

**Problem**: "Agent outputs overwriting each other"
**Cause**: Agents using same filename (not following agent-{id}-{topic} pattern)
**Solution**:
- Ensure unique agent IDs and topic descriptions
- Follow naming convention: `agent-001-requirements.md`, `agent-002-design.md`, etc.

### Initialization Issues

**Problem**: `.development/workflows/{workflow-id}/` already exists
**Cause**: Workflow with same ID was previously created
**Solution**:
- Use a different workflow-id (e.g., append timestamp or version)
- OR delete existing workflow if obsolete: `rm -rf .development/workflows/{workflow-id}/`

**Problem**: Templates not found when initializing workflow
**Cause**: Skill not properly installed or templates directory missing
**Solution**:
- Verify skill exists: check the `skills/multi-agent-workflows/` directory in the orchestration-toolkit plugin
- Check templates: check the `skills/multi-agent-workflows/templates/` directory in the orchestration-toolkit plugin

---

### Agent Communication Issues

**Problem**: Agent cannot find STATUS.yaml
**Cause**: Incorrect path or file not created
**Solution**:
- Verify path: `.development/workflows/{workflow-id}/active/{phase}/STATUS.yaml` (uppercase)
- Create if missing: Copy from templates/STATUS.yaml

**Problem**: Agent cannot read context files
**Cause**: Incorrect path references, often missing timestamps in archived phase paths
**Solution**:
- Check archived phase paths include timestamps: `archive/{phase}-{timestamp}/`
- Verify path exists: `ls .development/workflows/{workflow-id}/archive/`

---

### Workflow State Issues

**Problem**: workflow-state.yaml shows outdated information
**Cause**: Not updated after phase transitions
**Solution**:
- Orchestrator must update workflow-state.yaml after archiving phases
- Verify current_phase matches actual work being done

**Problem**: Agent marked as active but actually completed
**Cause**: Agent didn't update STATUS.yaml correctly
**Solution**:
- Manually update STATUS.yaml: move agent from active_agents to completed_agents
- Check agent output exists at expected path

---

### File Naming Issues

**Problem**: Multiple agents create files with same name
**Cause**: Not following `agent-{id}-{topic}.md` naming convention
**Solution**:
- Use unique agent ID for each agent (increment: agent-001, agent-002, etc.)
- Use descriptive topic names to avoid collisions

**Problem**: Files not found despite being created
**Cause**: Case sensitivity (status.yaml vs STATUS.yaml)
**Solution**:
- Always use uppercase STATUS.yaml
- Use exact paths from templates

---

### Phase Transition Issues

**Problem**: Not sure when to archive a phase
**Cause**: Unclear completion criteria
**Solution**:
- Check all planned agents completed: STATUS.yaml shows no active_agents
- Verify no blocking questions: No NEEDS-INPUT.md or BLOCKED.md files
- Confirm outputs validated and decision log updated

**Problem**: Next phase agent can't find previous phase context
**Cause**: Forgot to archive, or archive path incorrect
**Solution**:
- Ensure phase-summary.md exists in `archive/{phase}-{timestamp}/`
- Use full paths with timestamps when referencing archived content

---

### Token Budget Issues

**Problem**: Agent exceeds token budget
**Cause**: Task too broad, or budget underestimated
**Solution**:
- Split task into multiple smaller agents
- Review context being loaded - extract summaries instead of full files
- Increase budget if justified (document why in notes)

**Problem**: Workflow uses far more tokens than estimated
**Cause**: Too much context duplication across agents
**Solution**:
- Use phase summaries instead of reading all agent outputs
- Implement context extraction patterns (see context-extraction-patterns.md)
- Archive phases promptly to reduce active context

---

## Orchestrator-Specific Troubleshooting

### Agent Launch Failures

**Problem**: Task tool fails to launch agent
**Cause**: Various - check error message
**Solutions**:
- If "invalid prompt": Check prompt structure, ensure all placeholders replaced
- If "tool restriction": Verify agent has necessary tools in allowed-tools
- If "budget exceeded": Orchestrator out of tokens, not agent

### State Synchronization

**Problem**: workflow-state.yaml and STATUS.yaml show different information
**Cause**: Updates not coordinated
**Solution**:
- workflow-state.yaml is workflow-level source of truth
- STATUS.yaml is phase-level source of truth
- Update both when transitioning phases

---

## Sub-Agent-Specific Troubleshooting

### Cannot Complete Task

**Problem**: Agent doesn't know how to complete assigned task
**Cause**: Task too complex, unclear requirements, or missing context
**Solution**:
- Set status to "needs-input" in STATUS.yaml
- Create NEEDS-INPUT.md with specific questions
- Ask orchestrator for: clearer requirements, additional context, or task breakdown

### Missing Context

**Problem**: Agent cannot find files referenced in prompt
**Cause**: Paths incorrect or files don't exist
**Solution**:
- Verify all paths in context_files object
- List actual files: `ls .development/workflows/{workflow-id}/`
- Return with status "failed" and specific error about missing files

---

## Prevention Best Practices

**For Orchestrators**:
- ✅ Always use timestamps in archive folder names
- ✅ Update both workflow-state.yaml and STATUS.yaml during transitions
- ✅ Validate agent outputs before archiving phases
- ✅ Provide full context paths (not relative) to agents
- ✅ Test workflow-state.yaml is valid YAML after updates

**For Sub-Agents**:
- ✅ Always update STATUS.yaml (on start, complete, or block)
- ✅ Follow naming convention: agent-{id}-{topic}.md
- ✅ Return proper JSON in final message
- ✅ Extract context efficiently (don't load entire files)
- ✅ Ask questions early if task is unclear

---

## Getting More Help

**Detailed Guides**:
- Orchestrator issues: See `@reference/orchestrator-guide.md`
- Sub-agent issues: See `@reference/subagent-guide.md`
- File structure: See `@reference/file-structure-spec.md`

**Examples**:
- Check `@examples/` directory for working implementations
- Compare your workflow against examples for patterns

---

**Note**: This troubleshooting guide will be expanded with more scenarios and solutions based on real-world usage. If you encounter issues not covered here, document them in your workflow notes for future reference.
