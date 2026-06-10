# Changelog

All notable changes to this project will be documented in this file.

## [1.2.0] - 2026-02-25

### Changed
- Simplified Task tool documentation with single clear example
- Moved git/file analysis from orchestrator to expert-mapper agent (decoupling)
- Expert-mapper now returns `git_analysis` and `detected_expertise` fields
- Orchestrator receives analysis results instead of performing analysis
- Added explicit config validation in merge-coordinator (no silent fallbacks)
- Standardized error responses with `config_validation` field in all output types
- Documented agent naming convention (plugin:agent vs bare name)
- Added `model` parameter documentation for Task tool

### Fixed
- Removed duplicate lines in SKILL.md step 6
- Added `recovery_suggestion` to config validation error responses
- Added `config_validation` to escalation and error response formats
- Documented 1MB input limit rationale in checkpoint-detector.sh
- Added Python version check (>= 3.9) in validate-worktree.sh

## [1.1.0] - 2025-02-25

### Added
- Complete 4-phase orchestration implementation in SKILL.md
- Worktree cleanup phase with error handling for locked/dirty worktrees
- TaskGet polling mechanism for agent completion tracking
- Commit count safety checks before git diff operations
- Concrete git conflict resolution commands in merge-coordinator
- Multi-package-manager support (npm, yarn, pnpm, pytest, make)
- Prompt injection resistance in expert-mapper
- Empty repository fallback in domain-reviewer
- Worktree quantity limits (warns at 5, hard limit at 10)
- Confirmation requirement for destructive rollback commands
- Git pre-flight checks (validates git repo before commands)
- Tool clarification section (Task vs TaskCreate)
- LICENSE file (MIT)

### Fixed
- Command injection vulnerability in validate-worktree.sh (HIGH)
- Path traversal protection using component matching
- Timeout wrapper for checkpoint-detector.sh
- JSON validation before jq parsing
- Tilde expansion in glob patterns (now uses $HOME)

### Changed
- Deduplication algorithm simplified (file:line + 80% string overlap)
- Confidence criteria now explicitly defined (high/medium/low)
- Git workflow protocol documented (branching, commits, staging)
- Tool usage instructions added to expert-mapper (Glob instead of find)

## [1.0.0] - 2025-02-24

### Added
- Initial plugin structure
- Expert-mapper agent for dynamic discovery
- Domain-reviewer agent template
- Merge-coordinator agent for consolidation
- Expertise patterns configuration
- Precedence matrix configuration
- Checkpoint detector hook
- Worktree validation script
- Basic README and command documentation
