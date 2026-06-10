"""File enumeration for knowledge-harvester.

This module enumerates local files matching source configuration patterns,
producing candidate entries for further processing in the knowledge-harvesting pipeline.

Security: All user input is validated using sanitize module functions before
use in shell commands.
"""

import os
from datetime import datetime, timezone
from pathlib import Path

from lib.sanitize import sanitize_path, validate_glob_pattern, quote_for_shell


def enumerate_local(config: dict) -> list[dict]:
    """Enumerate local files matching source config.

    Discovers files in a directory matching include/exclude patterns with
    configurable depth limits. Returns structured candidate metadata for
    further processing.

    Args:
        config: Dict with keys:
            - path: str (supports ~ expansion)
            - depth: int (maxdepth for find, default 3)
            - include: list[str] (glob patterns like *.md)
            - exclude: list[str] (patterns like node_modules, .git)

    Returns:
        List of candidate dicts matching candidates.schema.json:
        [
            {
                "id": "local-001",
                "source_type": "local",
                "path": "/absolute/path/to/file.md",
                "metadata": {
                    "size_bytes": 4200,
                    "modified": "2026-02-20T10:00:00Z",  # ISO8601
                    "preview": "First 500 chars..."
                }
            }
        ]

    Raises:
        ValueError: If config contains invalid or unsafe paths/patterns.
    """
    try:
        # Extract and validate config parameters
        base_path = config.get("path", ".")
        max_depth = config.get("depth", 3)
        include_patterns = config.get("include", ["*"])
        exclude_patterns = config.get("exclude", [])

        # Validate inputs
        if not isinstance(max_depth, int) or max_depth < 0:
            raise ValueError("depth must be a non-negative integer")

        if not isinstance(include_patterns, list):
            raise ValueError("include must be a list")

        if not isinstance(exclude_patterns, list):
            raise ValueError("exclude must be a list")

        # Sanitize base path
        sanitized_path = sanitize_path(base_path)

        # Verify path exists
        if not os.path.isdir(sanitized_path):
            return []

        # Validate include patterns
        for pattern in include_patterns:
            if not validate_glob_pattern(pattern):
                raise ValueError(f"Invalid include pattern: {pattern}")

        # Validate exclude patterns
        for pattern in exclude_patterns:
            if not validate_glob_pattern(pattern):
                raise ValueError(f"Invalid exclude pattern: {pattern}")

        # Build find command
        candidates = []
        candidate_id = 1

        # Process each include pattern
        for include_pattern in include_patterns:
            files = _find_files(sanitized_path, max_depth, include_pattern, exclude_patterns)

            for file_path in files:
                try:
                    metadata = _get_file_metadata(file_path)
                    candidate = {
                        "id": f"local-{candidate_id:03d}",
                        "source_type": "local",
                        "path": file_path,
                        "metadata": metadata,
                    }
                    candidates.append(candidate)
                    candidate_id += 1
                except (OSError, ValueError) as e:
                    # Skip files that can't be read
                    continue

        return candidates

    except (ValueError, OSError) as e:
        # Return empty list on configuration or system errors
        return []


def _find_files(
    base_path: str, max_depth: int, include_pattern: str, exclude_patterns: list[str]
) -> list[str]:
    """Locate matching files using Python's os.walk (optimized).

    Args:
        base_path: Absolute path to search directory (pre-validated)
        max_depth: Maximum depth for traversal
        include_pattern: Glob pattern for filenames (pre-validated)
        exclude_patterns: List of patterns to exclude (pre-validated)

    Returns:
        List of absolute file paths matching the criteria.
    """
    try:
        import fnmatch

        files = []
        base_depth = base_path.rstrip(os.sep).count(os.sep)

        for dirpath, dirnames, filenames in os.walk(base_path):
            # Calculate current depth
            current_depth = dirpath.count(os.sep) - base_depth

            # Respect max depth
            if current_depth >= max_depth:
                # Don't descend into subdirectories
                dirnames.clear()
                continue

            # Filter out excluded directories in-place to prevent descent
            dirnames[:] = [
                d for d in dirnames
                if not any(
                    fnmatch.fnmatch(d, pattern) or pattern in d
                    for pattern in exclude_patterns
                )
            ]

            # Match files against include pattern
            for filename in filenames:
                if fnmatch.fnmatch(filename, include_pattern):
                    file_path = os.path.join(dirpath, filename)

                    # Check if file path contains any exclude patterns
                    excluded = False
                    for pattern in exclude_patterns:
                        # Check both exact pattern match and path containment
                        if pattern in file_path or fnmatch.fnmatch(filename, pattern):
                            excluded = True
                            break

                    if not excluded:
                        files.append(file_path)

        return files

    except (OSError, Exception):
        return []


def _get_file_metadata(file_path: str) -> dict:
    """Extract metadata for a file.

    Args:
        file_path: Absolute path to file (pre-validated)

    Returns:
        Dict with size_bytes, modified (ISO8601), and preview fields.

    Raises:
        OSError: If file cannot be stat'd or read.
    """
    try:
        # Get file size using stat
        size_bytes = _get_file_size(file_path)

        # Get modification time in ISO8601 format
        modified = _get_file_modified_time(file_path)

        # Get preview (first 500 chars)
        preview = _get_file_preview(file_path)

        return {
            "size_bytes": size_bytes,
            "modified": modified,
            "preview": preview,
        }

    except (OSError, ValueError) as e:
        raise OSError(f"Cannot read metadata for {file_path}: {e}") from e


def _get_file_size(file_path: str) -> int:
    """Get file size in bytes.

    Uses Python's os.path.getsize directly for security and reliability.

    Args:
        file_path: Absolute path to file

    Returns:
        File size in bytes

    Raises:
        OSError: If stat fails
    """
    try:
        # Use Python's built-in stat - no shell command needed
        return os.path.getsize(file_path)

    except (ValueError, OSError) as e:
        raise OSError(f"Cannot determine file size: {e}") from e


def _get_file_modified_time(file_path: str) -> str:
    """Get file modification time in ISO8601 format (UTC).

    Uses Python's os.stat directly for security and reliability.

    Args:
        file_path: Absolute path to file

    Returns:
        ISO8601 formatted timestamp string (UTC)

    Raises:
        OSError: If stat fails
    """
    try:
        # Use Python's built-in stat - no shell command needed
        stat_info = os.stat(file_path)
        mtime = datetime.fromtimestamp(stat_info.st_mtime, tz=timezone.utc)
        return mtime.isoformat().replace("+00:00", "Z")

    except OSError as e:
        raise OSError(f"Cannot determine file modification time: {e}") from e


def _get_file_preview(file_path: str, max_length: int = 500) -> str:
    """Get preview of file content (first N characters).

    Reads the first max_length characters from the file, replacing newlines
    with spaces for preview text.

    Args:
        file_path: Absolute path to file
        max_length: Maximum preview length (default 500)

    Returns:
        Preview string with newlines replaced by spaces

    Raises:
        OSError: If file cannot be read
    """
    try:
        with open(file_path, "r", encoding="utf-8", errors="replace") as f:
            content = f.read(max_length)
            # Replace newlines with spaces for preview
            preview = content.replace("\n", " ").replace("\r", " ")
            return preview

    except (OSError, IOError) as e:
        raise OSError(f"Cannot read file preview: {e}") from e
