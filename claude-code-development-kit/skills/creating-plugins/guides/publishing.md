# Publishing Plugins

This guide covers how to publish and distribute your Claude Code plugins via Git repositories, npm, and plugin marketplaces.

## Table of Contents

- [Installation Scopes](#installation-scopes)
- [Publishing via Git Repository](#publishing-via-git-repository)
- [Publishing via Plugin Marketplace](#publishing-via-plugin-marketplace)
- [Publishing via npm](#publishing-via-npm)
- [Version Management](#version-management)
- [Changelog Maintenance](#changelog-maintenance)

## Installation Scopes

When a user installs a plugin, they choose an installation scope that determines which settings file the plugin entry is written to and which projects can access it.

### Scope Overview

| Scope | Settings File Written To | Visibility | Committed to Git |
|-------|--------------------------|------------|-----------------|
| `user` | `~/.claude/settings.json` | All projects for this user | No |
| `project` | `.claude/settings.json` (project root) | This project only | Yes (shared with team) |
| `local` | `.claude/settings.local.json` (project root) | This project only | No (gitignored) |
| `managed` | Enterprise-managed settings | All projects (read-only) | N/A |

### Scope Details

#### user scope
Plugins installed at the user level are registered in the user-level `~/.claude/settings.json` and are available across all projects on the machine. This is the default scope for plugins installed without a project context.

```bash
/plugin install my-plugin --scope user
```

#### project scope
Plugins installed at the project level are written to the project's `.claude/settings.json`. All team members who clone the repository get the plugin automatically. This is the recommended approach for plugins that are integral to a project's workflow.

```bash
/plugin install my-plugin --scope project
```

Commit `.claude/settings.json` to version control so teammates share the same plugin configuration.

#### local scope
Local plugins are project-specific but not shared. The plugin entry is written to `.claude/settings.local.json`, which should be gitignored. Useful for personal tooling or experimental plugins you are not ready to share.

```bash
/plugin install my-plugin --scope local
```

Add `.claude/settings.local.json` to `.gitignore` to prevent accidental commits.

#### managed scope
Enterprise-managed plugins are distributed and updated by platform administrators via enterprise-controlled settings. They are read-only and cannot be modified by individual users. Managed plugins always take effect regardless of user or project settings.

### Scope Precedence

When the same plugin is installed at multiple scopes, the following precedence applies (highest first):

1. `managed` — enterprise-controlled, always active
2. `project` — project-specific, overrides user defaults
3. `local` — personal project override, highest user-controllable priority
4. `user` — user-wide defaults

A `project`-scoped plugin with version `2.0.0` will take precedence over a `user`-scoped installation of `1.5.0` within that project.

### Recommending a Scope in Your Documentation

When publishing a plugin, recommend the appropriate scope in your README based on the plugin's purpose:

- **Team workflow plugins** → `project` scope (committed with the repo)
- **Personal productivity plugins** → `user` scope (available everywhere)
- **Experimental or private plugins** → `local` scope (gitignored)

```markdown
## Installation

For team-wide use (recommended — commits plugin to the repository):
/plugin install my-plugin --scope project

For personal use across all your projects:
/plugin install my-plugin --scope user
```

## Publishing via Git Repository

The most common way to share plugins is through Git repositories (GitHub, GitLab, etc.).

### Step 1: Prepare Repository

Initialize Git in your plugin directory:

```bash
cd my-plugin
git init
git add .
git commit -m "Initial plugin release"
```

### Step 2: Create GitHub Repository

Using GitHub CLI:

```bash
gh repo create my-plugin --public --source=. --remote=origin
git push -u origin main
```

Or manually:
1. Create repository on GitHub
2. Add remote: `git remote add origin https://github.com/username/my-plugin.git`
3. Push: `git push -u origin main`

### Step 3: Tag Version

Tag your release with semantic version:

```bash
git tag v1.0.0
git push origin v1.0.0
```

### Step 4: Share Plugin URL

Users can install directly from GitHub:

```bash
/plugin marketplace add username/my-plugin
/plugin install my-plugin@github
```

### Repository Best Practices

1. **Include comprehensive README.md**:
```markdown
# My Plugin

Description of what the plugin does.

## Features

- Feature 1
- Feature 2
- Feature 3

## Installation

\`\`\`bash
/plugin marketplace add user/my-plugin
/plugin install my-plugin@github
\`\`\`

## Usage

### Commands

- `/my-plugin:command1` - Description
- `/my-plugin:command2` - Description

### Skills

- `skill-name` - When it's invoked

## Configuration

[Any required setup or configuration]

## License

MIT
```

2. **Add LICENSE file**:
```bash
# Choose a license (MIT, Apache-2.0, etc.)
# Add LICENSE file to repository
```

3. **Include .gitignore**:
```gitignore
# OS files
.DS_Store
Thumbs.db

# Editor files
.vscode/
.idea/

# Test files
*.test.js
coverage/

# Temporary files
*.tmp
*.log
```

4. **Create releases**:
- Use GitHub Releases for each version
- Include release notes
- Attach any necessary assets

## Publishing via Plugin Marketplace

Plugin marketplaces provide centralized discovery and distribution.

### Step 1: Prepare Plugin Package

Ensure your plugin is complete:

```bash
cd my-plugin

# Verify plugin.json is complete
cat .claude-plugin/plugin.json

# Ensure README.md exists
ls README.md

# Add LICENSE file
ls LICENSE

# Add CHANGELOG.md
ls CHANGELOG.md
```

### Step 2: Create Marketplace Entry

Submit to a plugin marketplace (e.g., company internal marketplace).

Create a pull request to add your plugin entry to the `plugins` array in `.claude-plugin/marketplace.json`:

```json
{
  "plugins": [
    {
      "name": "my-plugin",
      "source": {
        "source": "github",
        "repo": "company/my-plugin"
      },
      "version": "1.0.0",
      "description": "My plugin description",
      "tags": ["react", "frontend", "testing"]
    }
  ]
}
```

### Step 3: Users Install from Marketplace

Once approved, users can install:

```bash
/plugin marketplace add your-org/marketplace-repo
/plugin install my-plugin@marketplace-name
```

### Marketplace Submission Checklist

Before submitting to a marketplace:

- [ ] Plugin.json has all required fields
- [ ] README.md is comprehensive
- [ ] LICENSE file is included
- [ ] CHANGELOG.md documents versions
- [ ] All commands tested
- [ ] All skills validated
- [ ] Hooks reviewed for security
- [ ] MCP servers tested
- [ ] Version tagged in Git
- [ ] Documentation is clear

### Marketplace Entry Format

```json
{
  "name": "my-plugin",
  "source": {
    "source": "github",
    "repo": "company/my-plugin"
  },
  "version": "1.0.0",
  "description": "Comprehensive description of plugin capabilities",
  "tags": ["category1", "category2"],
  "author": {
    "name": "Team Name",
    "email": "team@company.com"
  },
  "homepage": "https://docs.company.com/my-plugin",
  "license": "MIT"
}
```

## Publishing via npm

If npm distribution is supported by Claude Code:

### Step 1: Prepare package.json

Create or update package.json:

```json
{
  "name": "@company/my-plugin",
  "version": "1.0.0",
  "description": "My Claude Code plugin",
  "main": ".claude-plugin/plugin.json",
  "files": [
    ".claude-plugin/",
    "commands/",
    "skills/",
    "hooks/",
    "mcp/",
    "README.md",
    "LICENSE"
  ],
  "keywords": [
    "claude-code",
    "claude-plugin",
    "development"
  ],
  "author": { "name": "Your Name", "email": "you@example.com" },
  "license": "MIT",
  "repository": "https://github.com/company/my-plugin.git"
}
```

### Step 2: Package Plugin

```bash
npm pack
```

This creates a tarball (e.g., `my-plugin-1.0.0.tgz`).

### Step 3: Publish to npm

```bash
# Login to npm
npm login

# Publish
npm publish --access public
```

### Step 4: Users Install from npm

```bash
/plugin install my-plugin@npm
```

### npm Publishing Best Practices

1. **Use scoped packages** for organization plugins: `@company/plugin-name`
2. **Specify files to include** in package.json
3. **Test package before publishing**:
   ```bash
   npm pack
   tar -tzf my-plugin-1.0.0.tgz
   ```
4. **Use npm version** for version bumps:
   ```bash
   npm version patch  # 1.0.0 -> 1.0.1
   npm version minor  # 1.0.0 -> 1.1.0
   npm version major  # 1.0.0 -> 2.0.0
   ```

## Version Management

Follow Semantic Versioning (semver) for all plugin releases.

### Semantic Versioning Rules

- **Major** (1.0.0 → 2.0.0): Breaking changes
  - Remove commands or skills
  - Change command arguments
  - Change skill behavior significantly
  - Require new dependencies

- **Minor** (1.0.0 → 1.1.0): New features, backward compatible
  - Add new commands
  - Add new skills
  - Add new hooks (non-breaking)
  - Enhance existing features

- **Patch** (1.0.0 → 1.0.1): Bug fixes
  - Fix command errors
  - Fix skill issues
  - Update documentation
  - Fix hook bugs

### Updating Versions

#### Method 1: Manual Update

Edit `.claude-plugin/plugin.json`:
```json
{
  "name": "my-plugin",
  "version": "1.1.0"
}
```

Commit and tag:
```bash
git add .claude-plugin/plugin.json
git commit -m "Bump version to 1.1.0"
git tag v1.1.0
git push origin main --tags
```

#### Method 2: Using npm version (if using npm)

```bash
# Update version in package.json and create git tag
npm version minor -m "Release version %s"

# Push changes and tags
git push origin main --tags
```

## Changelog Maintenance

Maintain a CHANGELOG.md to document all changes.

### Changelog Format

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- New feature being worked on

## [1.1.0] - 2025-01-15

### Added
- New component generation command
- TypeScript support for skills
- API integration skill

### Changed
- Improved error handling in hooks
- Updated documentation

### Fixed
- Bug in test generation
- Hook permission issues

## [1.0.1] - 2024-12-20

### Fixed
- Command argument parsing
- Skill description typo

## [1.0.0] - 2024-12-01

### Added
- Initial release
- Basic commands and skills
- Pre-commit hooks
- MCP server integration

[Unreleased]: https://github.com/user/my-plugin/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/user/my-plugin/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/user/my-plugin/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/user/my-plugin/releases/tag/v1.0.0
```

### Changelog Categories

- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Features that will be removed
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security fixes

### Updating Changelog

Before each release:

1. Move items from `[Unreleased]` to new version section
2. Add version number and date
3. Update comparison links
4. Commit changelog with version bump

```bash
# Update CHANGELOG.md
git add CHANGELOG.md .claude-plugin/plugin.json
git commit -m "Release version 1.1.0"
git tag v1.1.0
git push origin main --tags
```

## Release Checklist

Before publishing any version:

### Pre-release

- [ ] All features tested
- [ ] All commands work as expected
- [ ] All skills invoke correctly
- [ ] Hooks trigger properly (if included)
- [ ] MCP servers connect successfully (if included)
- [ ] Documentation updated
- [ ] README.md reflects new features
- [ ] CHANGELOG.md updated
- [ ] Version bumped in plugin.json
- [ ] License file included
- [ ] Test in fresh environment

### Publishing

- [ ] Code committed to Git
- [ ] Version tagged
- [ ] Pushed to remote repository
- [ ] GitHub release created (if using GitHub)
- [ ] Marketplace entry updated (if using marketplace)
- [ ] npm published (if using npm)
- [ ] Installation tested from published source

### Post-release

- [ ] Announce release to users
- [ ] Update documentation site (if applicable)
- [ ] Monitor for issues
- [ ] Respond to user feedback

## Troubleshooting Publishing Issues

### Issue: Git tag already exists

```bash
# Delete local tag
git tag -d v1.0.0

# Delete remote tag
git push origin :refs/tags/v1.0.0

# Create new tag
git tag v1.0.0
git push origin v1.0.0
```

### Issue: npm publish fails

```bash
# Check if package name is available
npm search @company/my-plugin

# Login again
npm logout
npm login

# Try publishing with verbose output
npm publish --verbose
```

### Issue: Marketplace not updating

1. Verify marketplace JSON is valid
2. Check repository URL is accessible
3. Ensure version tag exists in repository
4. Contact marketplace administrator

## Next Steps

- Review [Best Practices](best-practices.md)
- Explore [Advanced Topics](advanced.md)
- Set up [Team Marketplace](marketplace-setup.md)
- Learn about [Adding Components](adding-components.md)
