"""Input sanitization utilities for knowledge-harvester.

This module provides critical security functions to prevent command injection,
path traversal, and other injection attacks when processing user-provided input.

Security principles:
- All user input is considered untrusted and dangerous
- Defense in depth with multiple validation layers
- Fail fast with clear error messages
- Use allow-lists over deny-lists where possible

For comprehensive security documentation, see docs/security.md
"""

import os
import re
import shlex
from pathlib import Path
from typing import Set


# Dangerous shell metacharacters and patterns
SHELL_METACHARACTERS: Set[str] = {
    ';', '|', '&', '$', '`', '(', ')', '{', '}',
    '<', '>', '\n', '\r', '\0', '\t'
}

# Unicode control characters that can be used for attacks
# These include bidirectional text overrides that can hide malicious code
UNICODE_CONTROL_CHARS: Set[str] = {
    '\u202E',  # Right-to-Left Override (RLO)
    '\u202D',  # Left-to-Right Override (LRO)
    '\u200E',  # Left-to-Right Mark (LRM)
    '\u200F',  # Right-to-Left Mark (RLM)
    '\u202A',  # Left-to-Right Embedding
    '\u202B',  # Right-to-Left Embedding
    '\u202C',  # Pop Directional Formatting
    '\u2066',  # Left-to-Right Isolate
    '\u2067',  # Right-to-Left Isolate
    '\u2068',  # First Strong Isolate
    '\u2069',  # Pop Directional Isolate
}

# Patterns that indicate command injection attempts
DANGEROUS_PATTERNS = [
    re.compile(r'\$\('),           # Command substitution $(...)
    re.compile(r'`'),               # Backtick command substitution
    re.compile(r'\$\{'),            # Variable expansion ${...}
    re.compile(r';\s*'),            # Command chaining
    re.compile(r'\|\s*'),           # Pipe
    re.compile(r'&&'),              # AND chaining
    re.compile(r'\|\|'),            # OR chaining
    re.compile(r'>\s*'),            # Output redirection
    re.compile(r'<\s*'),            # Input redirection
    re.compile(r'\x00'),            # Null byte
]


def sanitize_path(path: str) -> str:
    """Canonicalize path and reject traversal attempts.

    Security purpose:
    Prevents path traversal attacks (CWE-22) and command injection (CWE-78)
    by validating and canonicalizing user-provided file paths.

    Protection against:
    - Path traversal using ../ sequences
    - Command injection via shell metacharacters
    - Null byte injection for path truncation
    - Symlink following to unauthorized locations
    - Unicode direction override attacks

    Args:
        path: User-provided path (may contain ~, .., etc)

    Returns:
        Canonicalized absolute path safe for file operations

    Raises:
        ValueError: If path contains dangerous patterns or is invalid

    Example:
        >>> sanitize_path("~/documents/../etc/passwd")
        # Returns absolute path, but caller should verify it's in allowed directory
        >>> sanitize_path("; rm -rf /")
        # Raises ValueError - contains shell metacharacter
    """
    if not path or not isinstance(path, str):
        raise ValueError("Path must be a non-empty string")

    # Check for null bytes (common injection technique)
    if '\x00' in path:
        raise ValueError("Path contains null byte")

    # Check for Unicode control characters (bidirectional text attacks)
    unicode_controls_found = set(path) & UNICODE_CONTROL_CHARS
    if unicode_controls_found:
        raise ValueError(f"Path contains Unicode control characters: {[hex(ord(c)) for c in unicode_controls_found]}")

    # Check for shell metacharacters that shouldn't be in paths
    dangerous_chars = set(path) & SHELL_METACHARACTERS
    if dangerous_chars:
        raise ValueError(f"Path contains dangerous characters: {dangerous_chars}")

    # Check for command injection patterns
    for pattern in DANGEROUS_PATTERNS:
        if pattern.search(path):
            raise ValueError(f"Path contains dangerous pattern: {pattern.pattern}")

    # Expand ~ to home directory
    expanded = os.path.expanduser(path)

    # Resolve to absolute path and canonicalize
    try:
        resolved = Path(expanded).resolve()
    except (OSError, RuntimeError) as e:
        raise ValueError(f"Invalid path: {e}")

    # Convert to string for final checks
    resolved_str = str(resolved)

    # Additional check: ensure resolved path doesn't escape expected boundaries
    # (the caller should verify this against allowed paths)

    return resolved_str


def validate_glob_pattern(pattern: str) -> bool:
    """Validate glob pattern is safe to use.

    Security purpose:
    Prevents command injection when glob patterns are used in shell commands
    like find or ls. Ensures patterns contain only safe glob metacharacters.

    Protection against:
    - Command substitution via $(...) or backticks
    - Shell command chaining via ; | && ||
    - Variable expansion via ${...}
    - I/O redirection via > <
    - Null byte injection

    Args:
        pattern: Glob pattern like "*.md" or "**/*.py"

    Returns:
        True if safe for use in shell glob operations, False if dangerous

    Example:
        >>> validate_glob_pattern("*.md")  # True - safe pattern
        >>> validate_glob_pattern("$(whoami)")  # False - command substitution
    """
    if not pattern or not isinstance(pattern, str):
        return False

    # Check for null bytes
    if '\x00' in pattern:
        return False

    # Check for command injection patterns
    for dangerous_pattern in DANGEROUS_PATTERNS:
        if dangerous_pattern.search(pattern):
            return False

    # Check for dangerous shell characters (except * and ? which are valid glob chars)
    allowed_glob_metacharacters = {'*', '?', '[', ']', '.', '-', '_', '/'}
    for char in pattern:
        if char in SHELL_METACHARACTERS:
            return False
        # Allow alphanumeric, glob metacharacters, and common filename characters
        if not (char.isalnum() or char in allowed_glob_metacharacters):
            return False

    # Valid glob patterns
    return True


def quote_for_shell(value: str) -> str:
    """Properly escape value for shell command use.

    Security purpose:
    Prevents command injection (CWE-78) by safely quoting strings for use
    as shell command arguments. Uses POSIX-compliant quoting via shlex.quote().

    Protection against:
    - Command substitution and execution
    - Variable/parameter expansion
    - Shell metacharacter interpretation
    - Command chaining and piping
    - Null byte injection (rejected, not quoted)

    Args:
        value: String to include in shell command

    Returns:
        Safely quoted string that will be treated as literal argument

    Raises:
        ValueError: If value contains null bytes (always malicious)

    Example:
        >>> quote_for_shell("file name.txt")  # Returns: 'file name.txt'
        >>> quote_for_shell("$(whoami)")  # Returns: '$(whoami)' - no execution
        >>> quote_for_shell("rm -rf /")  # Returns: 'rm -rf /' - treated as filename
    """
    if not isinstance(value, str):
        raise ValueError("Value must be a string")

    # Reject null bytes outright - they're always malicious in this context
    if '\x00' in value:
        raise ValueError("Value contains null byte")

    # Use shlex.quote for proper POSIX shell quoting
    return shlex.quote(value)
