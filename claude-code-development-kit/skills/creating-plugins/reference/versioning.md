# Plugin Versioning Guide

## Semantic Versioning (SemVer)

Follow Semantic Versioning for all plugins: `MAJOR.MINOR.PATCH`

### Version Types

| Type | Pattern | When to Use | Example |
|------|---------|-------------|---------|
| **Major** | X.0.0 | Breaking changes | 1.0.0 → 2.0.0 |
| **Minor** | x.X.0 | New features (backward compatible) | 1.0.0 → 1.1.0 |
| **Patch** | x.x.X | Bug fixes | 1.0.0 → 1.0.1 |

### Examples

#### Major Version (Breaking Changes)
- Removed commands or skills
- Changed command signatures
- Changed hook behavior
- Removed configuration options
- Incompatible API changes

**Example**: `1.5.2 → 2.0.0`

#### Minor Version (New Features)
- Added new commands
- Added new skills
- Added configuration options
- Enhanced existing features
- Backward-compatible changes

**Example**: `1.0.0 → 1.1.0`

#### Patch Version (Bug Fixes)
- Fixed bugs
- Improved error messages
- Updated documentation
- Performance improvements
- Security patches

**Example**: `1.0.0 → 1.0.1`

## Version Management Workflow

### 1. Update plugin.json

```json
{
  "name": "my-plugin",
  "version": "1.1.0"
}
```

### 2. Commit Changes

```bash
git add .claude-plugin/plugin.json
git commit -m "Bump version to 1.1.0"
```

### 3. Create Git Tag

```bash
git tag v1.1.0
```

### 4. Push to Remote

```bash
git push origin main --tags
```

## CHANGELOG Format

Maintain a `CHANGELOG.md` in your plugin root:

### Structure

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- New features in development

## [1.1.0] - 2025-01-15

### Added
- New component generation command
- TypeScript support for skills
- Template for API endpoints

### Changed
- Improved error messages in test command
- Updated README with new examples

### Fixed
- Bug in test generation for nested components

## [1.0.1] - 2025-01-10

### Fixed
- Fixed hook execution permissions
- Corrected path resolution in skills

## [1.0.0] - 2024-12-01

### Added
- Initial release
- Basic commands and skills
- Pre-commit hooks
- MCP server integration

[Unreleased]: https://github.com/user/plugin/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/user/plugin/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/user/plugin/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/user/plugin/releases/tag/v1.0.0
```

### Categories

Use these standard categories:

- **Added** - New features
- **Changed** - Changes to existing functionality
- **Deprecated** - Soon-to-be removed features
- **Removed** - Removed features
- **Fixed** - Bug fixes
- **Security** - Security fixes

## Version Tagging

### Git Tag Format

Use `v` prefix: `v1.0.0`, `v2.1.5`

```bash
# Create annotated tag
git tag -a v1.0.0 -m "Release version 1.0.0"

# Push specific tag
git push origin v1.0.0

# Push all tags
git push --tags
```

### Release Notes

For GitHub releases, include:
- Summary of changes
- Breaking changes (if major version)
- Migration guide (if needed)
- Known issues
- Contributors

## Pre-release Versions

For testing and beta releases:

```json
{
  "version": "1.1.0-beta.1"
}
```

Formats:
- `1.0.0-alpha.1` - Alpha release
- `1.0.0-beta.2` - Beta release
- `1.0.0-rc.1` - Release candidate

## Version Dependencies

When other plugins depend on yours, they use version ranges:

```json
{
  "dependencies": {
    "my-plugin": "^1.0.0"
  }
}
```

Ranges:
- `1.0.0` - Exact version
- `^1.0.0` - >=1.0.0 <2.0.0 (compatible)
- `~1.0.0` - >=1.0.0 <1.1.0 (patch updates)
- `>=1.0.0` - Any version 1.0.0 or higher

## Best Practices

1. **Never skip versions** - Go sequentially: 1.0.0 → 1.0.1 → 1.1.0
2. **Document all changes** - Update CHANGELOG with every release
3. **Tag immediately** - Create git tag as soon as version is bumped
4. **Communicate breaking changes** - Announce major versions early
5. **Test before releasing** - Validate all changes work correctly
6. **Keep semver strict** - Follow semver rules consistently