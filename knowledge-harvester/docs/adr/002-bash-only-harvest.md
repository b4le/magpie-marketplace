# ADR-002: Bash-Only Harvest Stage

## Status
Accepted

## Context

Stage 3 (Harvest) of the funnel architecture involves copying selected files from their source locations to a local staging area for processing. This is a purely mechanical operation that involves:
- Reading file paths from the triage stage output
- Copying files while preserving directory structure
- Creating necessary directories
- Handling file permissions and errors

Initially, there was consideration to use an LLM agent for this stage to handle edge cases and provide intelligent error recovery. However, file copying is a deterministic operation that doesn't benefit from LLM reasoning.

## Decision

Implement Stage 3 (Harvest) using only bash commands with zero LLM token usage:
- Use `cp` for local file copying
- Use `rsync` for more complex copying with filters
- Use `mkdir -p` for directory creation
- Use bash error handling for robustness
- Generate the bash script dynamically based on triage output
- Execute the script directly without LLM interpretation

The implementation will be a bash script generator that:
1. Reads the JSONL triage output
2. Generates appropriate copy commands
3. Adds error handling and logging
4. Executes with progress reporting

## Consequences

### Positive
- **Zero token cost**: No LLM usage for mechanical file operations
- **Speed**: Native bash operations are orders of magnitude faster than LLM processing
- **Reliability**: Deterministic behavior with predictable outcomes
- **Resource efficiency**: No API calls or model inference overhead
- **Simple debugging**: Standard bash debugging tools and techniques apply

### Negative
- **Platform dependency**: Bash commands vary between OS versions
- **Limited intelligence**: Cannot adapt to unexpected scenarios
- **Error handling**: Must pre-define all error cases
- **No context awareness**: Cannot make judgment calls about file relevance
- **Maintenance burden**: Bash scripts require different expertise than LLM prompts

### Trade-offs Accepted
- Platform-specific implementation for performance gains
- Loss of adaptability for predictability
- Upfront complexity in script generation for runtime efficiency
