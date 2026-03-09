# CI/CD Integration for Marketplace Validation

This directory contains CI/CD integration files for automated marketplace validation.

## Quick Start

### GitHub Actions

1. Copy `github-actions.yml` to your repository's `.github/workflows/` directory:

```bash
mkdir -p .github/workflows
cp claude-code-development-kit/evals/ci/github-actions.yml .github/workflows/marketplace-validation.yml
```

2. Commit and push to enable automated validation on PRs and pushes to main.

### Local PR Validation

Run diff-aware validation locally before pushing:

```bash
# Validate only plugins affected by your changes
./claude-code-development-kit/evals/ci/validate-pr.sh

# Compare against a specific branch
./claude-code-development-kit/evals/ci/validate-pr.sh --base develop

# Run full validation instead of diff-aware
./claude-code-development-kit/evals/ci/validate-pr.sh --full
```

## Files

| File | Purpose |
|------|---------|
| `github-actions.yml` | GitHub Actions workflow for automated validation |
| `validate-pr.sh` | Diff-aware PR validation script |
| `README.md` | This documentation |

## GitHub Actions Workflow

### Features

- **Triggers on push to main** - Full marketplace validation
- **Triggers on pull requests** - Both full and diff-aware validation
- **Path filtering** - Only runs when relevant files change (*.md, plugin.json, etc.)
- **JSON output** - Machine-readable results for CI/CD integration
- **PR comments** - Optional automated comments with validation results
- **Artifact upload** - Validation results saved for 30 days
- **Job summary** - Visual summary in GitHub Actions UI
- **jq caching** - Faster subsequent runs

### Jobs

1. **validate** - Runs full marketplace validation
2. **comment** - Posts validation results as PR comment (requires write permissions)
3. **validate-pr-diff** - Runs diff-aware validation for faster PR checks

### Customization

Edit the workflow file to customize:

```yaml
# Change trigger branches
on:
  push:
    branches: [main, develop]  # Add more branches

# Adjust path filters
paths:
  - '**/*.md'
  - '**/plugin.json'
  # Add or remove patterns

# Disable PR comments
comment:
  if: false  # Disable this job
```

## validate-pr.sh

### Usage

```bash
./validate-pr.sh [OPTIONS]
```

### Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message |
| `-f, --full` | Run full marketplace validation instead of diff-aware |
| `-b, --base REF` | Base reference for diff comparison (default: origin/main) |
| `-v, --verbose` | Show detailed validation output |
| `--json` | Output summary in JSON format |

### Examples

```bash
# Default: diff against origin/main
./validate-pr.sh

# Compare against specific branch
./validate-pr.sh --base origin/develop

# Compare against specific commit
./validate-pr.sh --base HEAD~5

# Full validation with verbose output
./validate-pr.sh --full --verbose

# JSON output for scripting
./validate-pr.sh --json | jq '.summary'
```

### How Diff-Aware Validation Works

1. Gets list of changed files between base ref and HEAD
2. Maps changed files to affected plugins using marketplace.json
3. Only validates plugins with changed files
4. Falls back to full validation if:
   - marketplace.json changed
   - Validation scripts changed
   - Cannot determine affected plugins

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All validations passed |
| 1 | One or more validations failed |
| 2 | Invalid arguments or configuration error |

## Troubleshooting

### "marketplace.json not found"

Ensure you're running from the marketplace root directory, or the script can find the marketplace.json file.

```bash
# Run from correct directory
cd /path/to/marketplace
./claude-code-development-kit/evals/ci/validate-pr.sh
```

### "jq not installed"

The validation scripts work best with jq installed:

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# The scripts fall back to basic validation without jq
```

### "Permission denied"

Make scripts executable:

```bash
chmod +x claude-code-development-kit/evals/*.sh
chmod +x claude-code-development-kit/evals/ci/*.sh
```

### "Cannot determine plugin directories"

Ensure marketplace.json has the correct structure with `plugins[].source` entries:

```json
{
  "plugins": [
    {
      "name": "my-plugin",
      "source": "./my-plugin"
    }
  ]
}
```

### GitHub Actions workflow not running

Check path filters - the workflow only triggers when files matching the patterns change. Add patterns if needed:

```yaml
paths:
  - '**/*.md'
  - '**/plugin.json'
  - 'your-custom-path/**'  # Add custom patterns
```

### PR comments not posting

Ensure the workflow has `pull-requests: write` permission:

```yaml
permissions:
  pull-requests: write
```

For organization repositories, you may need to allow GitHub Actions to create/update comments in repository settings.

## Badge Examples

Add validation status badges to your README:

### GitHub Actions Badge

```markdown
![Marketplace Validation](https://github.com/YOUR_ORG/YOUR_REPO/actions/workflows/marketplace-validation.yml/badge.svg)
```

### With Branch Specification

```markdown
![Marketplace Validation](https://github.com/YOUR_ORG/YOUR_REPO/actions/workflows/marketplace-validation.yml/badge.svg?branch=main)
```

### Custom Badge with shields.io

```markdown
[![Marketplace](https://img.shields.io/badge/marketplace-validated-brightgreen)](https://github.com/YOUR_ORG/YOUR_REPO/actions/workflows/marketplace-validation.yml)
```

## Integration with Pre-commit Hooks

For local validation before commits:

```bash
# .git/hooks/pre-push
#!/bin/bash
./claude-code-development-kit/evals/ci/validate-pr.sh --base origin/main
```

Or with a pre-commit configuration:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: validate-marketplace
        name: Validate Marketplace
        entry: ./claude-code-development-kit/evals/ci/validate-pr.sh
        language: script
        pass_filenames: false
        stages: [push]
```

## Related Documentation

- [validate-marketplace.sh](../README.md) - Main validation script documentation
- [Validation Scripts](../) - Individual component validators
