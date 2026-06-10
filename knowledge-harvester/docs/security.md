# Security Documentation

## Overview

This document outlines the security measures implemented in the knowledge-harvester plugin to protect against common vulnerabilities. The plugin processes user-provided paths and patterns, making input validation critical to prevent command injection and path traversal attacks.

## Security Architecture

### Trust Boundaries

| Input Source | Trust Level | Validation Required |
|--------------|-------------|-------------------|
| User-provided paths | Untrusted | Full sanitization via `lib/sanitize.py` |
| User glob patterns | Untrusted | Pattern validation via `validate_glob_pattern()` |
| Agent-generated IDs | Trusted | None (internal use only) |
| Config JSON | Untrusted | Schema validation + input sanitization |
| External source credentials | Sensitive | Never stored in code, use environment variables |

### Defense Layers

1. **Input Validation** - Reject dangerous inputs at entry point
2. **Path Canonicalization** - Resolve to absolute paths, prevent traversal
3. **Shell Escaping** - Proper quoting for shell command arguments
4. **Least Privilege** - Agents limited to specific operations
5. **Output Validation** - Structured JSON output only

## Input Validation

### Path Validation (`lib/sanitize.py::sanitize_path`)

**Purpose**: Prevent path traversal and command injection through file paths.

**Security Measures**:
- Rejects null bytes (`\x00`) - common in path truncation attacks
- Blocks shell metacharacters (`;`, `|`, `&`, `$`, etc.)
- Detects command substitution patterns (`$(...)`, `` `...` ``)
- Prevents variable expansion (`${...}`)
- Blocks command chaining (`&&`, `||`)
- Prevents I/O redirection (`>`, `<`)
- Canonicalizes paths to absolute form (resolves `..`, symlinks)
- Expands user home directory (`~`)

**Usage**:
```python
from lib.sanitize import sanitize_path

# Safe path handling
safe_path = sanitize_path(user_input)  # Raises ValueError if dangerous
```

**Attack Prevention Examples**:
- `"; rm -rf /"` → ValueError (contains semicolon)
- `"$(cat /etc/passwd)"` → ValueError (command substitution)
- `"../../etc/shadow"` → Resolved to absolute path (traversal neutralized)
- `"file\x00.txt"` → ValueError (null byte injection)

### Glob Pattern Validation (`lib/sanitize.py::validate_glob_pattern`)

**Purpose**: Ensure glob patterns are safe for file matching operations.

**Security Measures**:
- Allows only safe glob metacharacters (`*`, `?`, `[`, `]`)
- Blocks all shell injection characters
- Prevents command substitution
- Rejects null bytes
- Validates character set (alphanumeric + specific allowed chars)

**Usage**:
```python
from lib.sanitize import validate_glob_pattern

if validate_glob_pattern(pattern):
    # Safe to use in find command
else:
    # Reject the pattern
```

## Shell Injection Prevention

### Shell Quoting (`lib/sanitize.py::quote_for_shell`)

**Purpose**: Safely include user data in shell commands.

**Security Measures**:
- Uses POSIX-compliant `shlex.quote()` for proper escaping
- Rejects null bytes outright (always malicious in shell context)
- Prevents variable expansion
- Escapes all shell metacharacters
- Handles single quotes within strings

**Usage**:
```python
from lib.sanitize import quote_for_shell

# Building safe shell commands
safe_arg = quote_for_shell(user_input)
cmd = f"find {safe_arg} -type f"  # Properly escaped
```

**Protection Examples**:
- `"$HOME"` → `'$HOME'` (prevents expansion)
- `"; rm -rf /"` → `'; rm -rf /'` (treated as literal string)
- `` "`whoami`" `` → `'`whoami`'` (no command execution)

## Credential Management

### Current State
- **No hardcoded credentials** found in codebase (verified via grep scan)
- `.gitignore` properly excludes sensitive files
- No credential storage mechanisms implemented

### Guidelines for V2 (rclone/gdrive)

When implementing external source support:

1. **Never store credentials in code**
   - Use environment variables for API keys
   - Use system keychain for persistent credentials
   - Reference external credential stores

2. **Secure rclone credentials**:
   ```bash
   # Store rclone config outside plugin directory
   export RCLONE_CONFIG="$HOME/.config/rclone/rclone.conf"

   # Use encrypted rclone config
   rclone config create gdrive drive --config-encryption
   ```

3. **Environment variable pattern**:
   ```python
   import os

   # Read from environment, fail gracefully
   api_key = os.environ.get('GDRIVE_API_KEY')
   if not api_key:
       raise ValueError("GDRIVE_API_KEY environment variable not set")
   ```

4. **Never log credentials**:
   ```python
   # Bad: logging.info(f"Using API key: {api_key}")
   # Good: logging.info("API key configured")
   ```

## Path Traversal Prevention

### Implementation Details

The `sanitize_path()` function prevents path traversal through:

1. **Canonicalization**: Resolves all symbolic links and `..` components
2. **Absolute paths**: Converts relative paths to absolute
3. **Boundary validation**: Caller should verify resolved path is within allowed directories

### Recommended Usage Pattern

```python
from lib.sanitize import sanitize_path
import os

ALLOWED_BASE = "/home/user/safe_directory"

def process_user_path(user_input):
    # Sanitize and resolve
    safe_path = sanitize_path(user_input)

    # Verify within boundaries
    if not safe_path.startswith(ALLOWED_BASE):
        raise ValueError("Path outside allowed directory")

    return safe_path
```

## Time-of-Check to Time-of-Use (TOCTOU) Risks

### Overview

TOCTOU vulnerabilities occur when a security check and subsequent use of a resource
are separated in time, allowing an attacker to modify the resource between check and use.

### Current Mitigations

The `sanitize_path()` function uses `Path.resolve()` which:
- Resolves symlinks at check time
- Returns absolute path for subsequent use
- Does NOT use `strict=True` (allows non-existent paths)

### Known Limitations

1. **Symlink races**: An attacker with write access could replace a validated path
   with a symlink between sanitization and file access.

2. **Non-strict resolution**: `Path.resolve()` without `strict=True` allows paths
   that don't exist at check time, which could be created as symlinks before use.

### Recommendations

For high-security deployments:

1. Use `Path.resolve(strict=True)` when the path must exist at validation time
2. Open files with `O_NOFOLLOW` flag to prevent symlink following at use time
3. Validate paths again immediately before use in security-critical operations
4. Consider using file descriptors instead of paths for sensitive operations

### Risk Assessment

| Scenario | Risk Level | Mitigation |
|----------|------------|------------|
| Local user harvesting own files | Low | User controls both paths |
| Shared system with untrusted users | Medium | Use strict mode, O_NOFOLLOW |
| Processing untrusted external paths | High | Additional validation required |

## OWASP Top 10 Coverage

### A03:2021 - Injection ✓

**Threat**: Command injection through user-provided paths or patterns.

**Mitigation**:
- Input validation blocks shell metacharacters
- `quote_for_shell()` properly escapes all user input
- Pattern validation prevents glob injection
- Agent prompts enforce quoting rules

### A01:2021 - Broken Access Control ✓

**Threat**: Path traversal to access unauthorized files.

**Mitigation**:
- Path canonicalization resolves traversal attempts
- Absolute path conversion prevents relative path attacks
- Boundary checking (recommended) limits file access

### A02:2021 - Cryptographic Failures ⚠️

**Threat**: Exposed credentials in source code.

**Mitigation**:
- No credentials stored in code (verified)
- Guidelines for secure credential storage in V2
- `.gitignore` excludes sensitive files

### A04:2021 - Insecure Design ✓

**Threat**: Lack of security controls in design.

**Mitigation**:
- Defense in depth (multiple validation layers)
- Least privilege principle (agents have limited scope)
- Clear trust boundaries defined

### A05:2021 - Security Misconfiguration ⚠️

**Not directly applicable** - Plugin doesn't manage configurations.

**Recommendations**:
- Keep dependencies updated
- Use secure defaults in configs

### A06:2021 - Vulnerable Components ⚠️

**Current state**: Using standard library only (low risk).

**Recommendations**:
- Monitor Python security advisories
- Update Python runtime regularly

### A07:2021 - Identification and Authentication Failures N/A

**Not applicable** - Plugin doesn't handle authentication.

### A08:2021 - Software and Data Integrity Failures ✓

**Threat**: Malicious code execution through compromised inputs.

**Mitigation**:
- All user input sanitized before use
- No dynamic code execution (`eval`, `exec` not used)
- JSON output validation

### A09:2021 - Security Logging and Monitoring ⚠️

**Current state**: No security logging implemented.

**Recommendations**:
- Log validation failures (without sensitive data)
- Monitor for repeated attack patterns
- Alert on suspicious input patterns

### A10:2021 - Server-Side Request Forgery (SSRF) ⚠️

**Future concern** for V2 with external sources.

**Planned mitigation**:
- Validate URLs against allowlist
- Prevent internal network access
- Use timeouts for external requests

## Security Testing

### Test Coverage

The `tests/test_sanitize.py` file provides comprehensive security testing:

1. **Path Traversal Tests**
   - Parent directory traversal (`../`)
   - Classic `/etc/passwd` attempts
   - Symlink resolution

2. **Command Injection Tests**
   - Shell metacharacter injection
   - Command substitution attempts
   - Variable expansion attacks
   - I/O redirection attempts

3. **Null Byte Tests**
   - Path truncation attempts
   - Null byte in various positions

4. **Edge Cases**
   - Empty inputs
   - Type confusion (non-strings)
   - Invalid paths

### Running Security Tests

```bash
# Run only security tests
pytest tests/test_sanitize.py -v

# Run with coverage
pytest tests/test_sanitize.py --cov=lib.sanitize

# Run integration tests
pytest tests/test_agent_behaviors.py -v
```

## Security Checklist for Developers

### Before Adding New Features

- [ ] All user input passes through appropriate sanitization
- [ ] New shell commands use `quote_for_shell()` for arguments
- [ ] File operations verify paths are within expected boundaries
- [ ] No credentials or secrets in code
- [ ] Tests include malicious input cases
- [ ] Agent prompts enforce security rules

### Code Review Security Questions

1. **Does this accept user input?** → Needs sanitization
2. **Does this execute shell commands?** → Use proper quoting
3. **Does this access files?** → Validate paths
4. **Does this handle credentials?** → Use environment variables
5. **Does this parse external data?** → Validate structure
6. **Could this log sensitive data?** → Sanitize log output

## Incident Response

If a security vulnerability is discovered:

1. **Assess impact**: What data/systems could be affected?
2. **Patch immediately**: Fix the vulnerability
3. **Add tests**: Prevent regression
4. **Update this document**: Document the issue and fix
5. **Audit similar code**: Check for the same pattern elsewhere

## Future Security Enhancements

### V2 Considerations

1. **External Source Security**
   - URL validation for remote sources
   - Certificate verification for HTTPS
   - Request timeouts
   - Rate limiting

2. **Credential Management**
   - Integration with system keychains
   - Encrypted credential storage
   - Credential rotation support

3. **Audit Logging**
   - Security event logging
   - Failed validation tracking
   - Anomaly detection

4. **Sandboxing**
   - Consider using subprocess with restricted permissions
   - Limit file system access scope
   - Network isolation for processing

## References

- [OWASP Top 10 2021](https://owasp.org/Top10/)
- [CWE-78: OS Command Injection](https://cwe.mitre.org/data/definitions/78.html)
- [CWE-22: Path Traversal](https://cwe.mitre.org/data/definitions/22.html)
- [Python Security Best Practices](https://python.readthedocs.io/en/stable/library/security_warnings.html)
- [shlex.quote() Documentation](https://docs.python.org/3/library/shlex.html#shlex.quote)
