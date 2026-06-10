# Performance Issues

Troubleshooting high resource usage, slow responses, and unresponsive commands.

## High Resource Usage

**Problem**: Claude Code using too much CPU/memory

**Solutions**:

1. Use compact mode:
```bash
/compact
```

2. Restart between large tasks:
```bash
# Exit and restart Claude Code
```

3. Limit context:
- Use focused prompts
- Don't load unnecessary files
- Clear conversation when switching tasks

4. Check for runaway processes:
```bash
ps aux | grep claude
```

## Slow Response Times

**Problem**: Claude Code responds very slowly

**Solutions**:

1. Check internet connection
2. Verify API status
3. Reduce context size
4. Close other resource-intensive applications
5. Try different model (use haiku for faster responses)

## Unresponsive Commands

**Problem**: Commands hang or don't complete

**Solutions**:

1. Press `Ctrl+C` to cancel
2. Check for background processes
3. Restart Claude Code
4. Verify command syntax
5. Check logs for errors
