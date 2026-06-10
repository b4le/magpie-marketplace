# Troubleshooting Command Usage

## Command Not Found

### Symptom
When you type `/my-command`, you get "Command not found" or no autocomplete suggestion.

### Solutions

1. **Verify the file exists**:
   ```bash
   ls .claude/commands/my-command.md
   ls ~/.claude/commands/my-command.md
   ```

2. **Check filename matches command**:
   - Command: `/review-pr`
   - File: `review-pr.md` (not `reviewPr.md` or `review_pr.md`)

3. **Restart Claude Code**: Sometimes a restart is needed to discover new commands

4. **Check file permissions**: Ensure the file is readable
   ```bash
   chmod 644 .claude/commands/my-command.md
   ```

## Arguments Not Working

### Symptom
Arguments aren't being passed correctly or command behavior is unexpected.

### Solutions

1. **Check argument format**: Commands expect space-separated arguments
   - Correct: `/review-pr 123 high`
   - Incorrect: `/review-pr 123,high`

2. **Quote multi-word arguments**: If an argument contains spaces
   - Correct: `/commit "Add user authentication feature"`
   - Incorrect: `/commit Add user authentication feature`

3. **Check argument order**: Positional arguments must match the command's expectation
   - If command expects `[pr-number] [priority]`
   - Use: `/review-pr 123 high` (not `/review-pr high 123`)

4. **Verify argument-hint**: Check what arguments the command expects
   - Type `/` and look for the command's argument hint

## Understanding Command Output

### Symptom
Command runs but output is confusing or unexpected.

### Solutions

1. **Read the command source**: Check what the command actually does
   ```bash
   cat .claude/commands/my-command.md
   ```

2. **Check for bash commands**: Commands with `!command` execute bash and include output

3. **Check for file references**: Commands with `@file` load file contents

4. **Review frontmatter**: Check `allowed-tools` or `model` settings that might affect behavior

## Permission or Access Issues

### Symptom
Command fails with permission errors or can't access files.

### Solutions

1. **Check file paths**: Ensure referenced files exist and are readable

2. **Verify bash commands**: Commands with `!git` or other bash need those tools installed

3. **Check allowed-tools**: Some commands restrict which tools Claude can use

4. **Working directory**: Commands run from current working directory - use absolute paths if needed

## Command Runs But Does Nothing

### Symptom
Command invokes but Claude doesn't respond or take action.

### Solutions

1. **Check disable-model-invocation**: Command might be template-only
   ```yaml
   disable-model-invocation: true
   ```

2. **Verify command content**: Empty or minimal commands might not give Claude enough context

3. **Check for errors in bash commands**: Failed bash commands might prevent execution

## Namespace Issues

### Symptom
Can't invoke namespaced command like `/git:commit`.

### Solutions

1. **Verify directory structure**:
   ```
   .claude/commands/
   └── git/
       └── commit.md
   ```

2. **Use correct separator**: Colon `:` not slash `/`
   - Correct: `/git:commit`
   - Incorrect: `/git/commit`

## Plugin Command Issues

### Symptom
Plugin command not working or not found.

### Solutions

1. **Verify plugin is installed**: Check `/plugin` output

2. **Use correct namespace**: Plugin commands need plugin name prefix
   - Correct: `/my-plugin:command-name`
   - Incorrect: `/command-name`

3. **Check plugin documentation**: Plugin might have specific requirements

## Getting More Help

- View command source code: `cat .claude/commands/command-name.md`
- Check Claude Code docs: https://code.claude.com/docs/en/slash-commands
- Invoke `creating-commands` skill for authoring guidance
- Use `/doctor` to check Claude Code health
- Use `/bug` to report issues
