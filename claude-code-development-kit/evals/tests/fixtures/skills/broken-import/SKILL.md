---
name: broken-import
description: A skill that references a nonexistent file via an at-path import to test import resolution
allowed-tools:
  - Read
---

This skill uses a broken import reference:

@references/nonexistent-file.md

The file above does not exist.
