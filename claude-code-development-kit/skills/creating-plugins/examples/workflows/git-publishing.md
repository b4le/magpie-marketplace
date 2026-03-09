# Git Publishing Workflow for Claude Code Plugins

## Prerequisites

- Git installed
- GitHub account
- Claude Code installed
- Plugin development completed

## Step-by-Step Guide

### 1. Prepare Repository

```bash
# Navigate to plugin directory
cd my-plugin

# Initialize git repository
git init

# Create .gitignore
cat > .gitignore << 'EOF'
# Ignore system and editor files
.DS_Store
*.log
.idea/
.vscode/

# Ignore Claude Code specific files
.claude/local-settings.json
EOF

# Stage initial files
git add .claude-plugin/plugin.json commands/ skills/ README.md .gitignore
```

### 2. Create GitHub Repository

```bash
# Authenticate with GitHub CLI
gh auth login

# Create public repository
gh repo create my-plugin --public --source=. --remote=origin
```

### 3. Commit and Tag First Version

```bash
# Initial commit
git commit -m "Initial plugin release: Basic functionality"

# Create semantic version tag
git tag v1.0.0
git push -u origin main
git push origin v1.0.0
```

### 4. Update Changelog

```bash
# Create CHANGELOG.md
cat > CHANGELOG.md << 'EOF'
# Changelog

## [1.0.0] - YYYY-MM-DD

### Added
- Initial plugin release
- Basic commands and skills
EOF

# Commit changelog
git add CHANGELOG.md
git commit -m "Add CHANGELOG.md for version tracking"
git push
```

### 5. Configure Marketplace Entry

```bash
# Create marketplace configuration
cat > marketplace.json << 'EOF'
{
  "name": "My Plugin Marketplace",
  "plugins": {
    "my-plugin": {
      "repository": "https://github.com/username/my-plugin",
      "version": "1.0.0",
      "description": "Description of my plugin"
    }
  }
}
EOF
```

### 6. Release Workflow

```bash
# Create a new release on GitHub
gh release create v1.0.0 \
  --title "Version 1.0.0" \
  --notes-file CHANGELOG.md
```

### 7. Publish to Claude Code Marketplace

```bash
# Add marketplace
/plugin marketplace add my-marketplace marketplace.json

# Install plugin
/plugin install my-plugin@my-marketplace
```

### Version Management

```bash
# Update version in plugin.json
{
  "version": "1.1.0"
}

# Commit version bump
git add .claude-plugin/plugin.json
git commit -m "Bump version to 1.1.0"
git tag v1.1.0
git push origin main --tags
```

### Best Practices

- Use semantic versioning
- Maintain detailed changelog
- Test thoroughly before releasing
- Use GitHub releases
- Tag each version
- Keep repository clean

### Troubleshooting

- Verify GitHub authentication
- Check plugin validation
- Validate marketplace configuration
- Ensure consistent versioning