# Installation Issues

Detailed troubleshooting for Claude Code installation problems across different platforms.

## Windows WSL Problems

### OS Detection Errors

**Problem**: Installation fails with OS detection error on WSL

**Solution**:
```bash
npm install -g @anthropic-ai/claude-code --force --no-os-check
```

### Node Not Found in WSL

**Problem**: WSL can't find Node.js after installation

**Solutions**:

1. Install Node via Linux package manager:
```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

2. Or use nvm:
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 18
nvm use 18
```

3. Adjust shell configuration to prioritize Linux node:
```bash
# Add to ~/.bashrc
export PATH=/usr/bin:$PATH
```

## Linux/Mac Installation

### Permission Errors

**Problem**: npm installation fails with permission errors

**⚠️ CRITICAL**: Never use `sudo npm install -g` - this creates permission issues and security risks.

**Solution 1 (Recommended)**: Use native installer instead of npm:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**Solution 2**: Fix npm permissions (one-time setup):

```bash
# Create directory for global packages
mkdir -p ~/.npm-global

# Configure npm to use new directory
npm config set prefix '~/.npm-global'

# Add to PATH (add to ~/.bashrc or ~/.zshrc)
export PATH=~/.npm-global/bin:$PATH

# Source profile
source ~/.bashrc  # or source ~/.zshrc

# Now install without sudo
npm install -g @anthropic-ai/claude-code
```

**Why avoid sudo**:
- Creates permission conflicts
- Security risk (runs install scripts as root)
- Causes issues with file ownership
- Makes updates difficult
- May break other tools

**If you already used sudo**:
```bash
# Fix ownership
sudo chown -R $(whoami) ~/.npm ~/.npm-global

# Reinstall
npm install -g @anthropic-ai/claude-code
```

### Installation Hangs

**Problem**: Installation process hangs or times out

**Solutions**:
1. Check internet connection
2. Try different network (VPN issues)
3. Clear npm cache:
```bash
npm cache clean --force
```
4. Use native installer

## Verifying Installation

```bash
# Check if installed
which claude

# Check version
claude --version

# Run health check
/doctor
```
