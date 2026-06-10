---
domain: python-practices
status: active
maintainer: archaeology-skill
last_updated: 2026-02-26
version: 1.0.0
agent_count: 4

keywords:
  primary:
    - "def "
    - "class "
    - pytest
    - "async def"
    - dataclass
    - "match "
    - "case "
  secondary:
    - type hint
    - "-> "
    - Optional
    - List
    - Dict
    - TypedDict
    - Protocol
    - ParamSpec
    - TypeVar
    - Generic
    - pydantic
    - FastAPI
    - import
    - "__init__"
    - decorator
    - "@"
    - "try:"
    - except
    - with
    - context manager
    - generator
    - yield
    - unittest
    - hypothesis
    - "@given"
    - coverage
    - ":="
    - argparse
    - click
    - typer
    - logging
    - logger
  exclusion:
    - node_modules
    - venv
    - __pycache__
    - ".pyc"

locations:
  - path: "~/.claude/projects/-Users-*-{PROJECT_PATH_PATTERN}/"
    purpose: "Conversation history with Python code"
    priority: high
  - path: "~/{PROJECT_ROOT}/**/*.py"
    purpose: "Python source files"
    priority: high
  - path: "~/{PROJECT_ROOT}/src/**/*.py"
    purpose: "Modern src/ layout source files"
    priority: high
  - path: "~/{PROJECT_ROOT}/tests/"
    purpose: "Test files and patterns"
    priority: medium
  - path: "~/{PROJECT_ROOT}/conftest.py"
    purpose: "Pytest configuration and fixtures"
    priority: medium
  - path: "~/{PROJECT_ROOT}/pyproject.toml"
    purpose: "Project configuration"
    priority: low
  - path: "~/{PROJECT_ROOT}/**/*.pyi"
    purpose: "Type stub files"
    priority: low

outputs:
  - file: README.md
    required: true
    template: readme
  - file: code-patterns.md
    required: true
    template: patterns
  - file: testing-patterns.md
    required: true
    template: patterns
  - file: type-annotations.md
    required: false
    template: patterns
  - file: anti-patterns.md
    required: false
    template: patterns
  - file: async-patterns.md
    required: false
    template: patterns
  - file: framework-usage.md
    required: false
    template: patterns
  - file: dependency-management.md
    required: false
    template: patterns
---

# Python Practices Domain

**Description:** Python coding patterns, testing approaches, type annotation styles, and architectural decisions extracted from Claude Code conversation history

---

## Metadata

| Field | Value |
|-------|-------|
| Domain ID | python-practices |
| Version | 1.0.0 |
| Created | 2026-02-26 |
| Updated | 2026-02-26 |
| Maintainer | archaeology-skill |
| Agent Count | 4 |

## Search Keywords

**Primary keywords** (high-confidence Python signals):
- `def ` - Function definitions
- `class ` - Class definitions
- `pytest` - Testing framework usage
- `async def` - Async/await patterns
- `dataclass` - Data class decorators

**Secondary keywords** (Python idioms and patterns):
- `type hint`, `-> `, `Optional`, `List`, `Dict` - Type annotation patterns
- `pydantic`, `FastAPI` - Modern Python frameworks
- `import`, `__init__` - Module structure
- `decorator`, `@` - Decorator usage
- `try:`, `except` - Error handling patterns
- `with`, `context manager` - Resource management
- `generator`, `yield` - Generator patterns

**Exclusion keywords** (filter out build artifacts):
- `node_modules` - Non-Python dependencies
- `venv`, `__pycache__` - Virtual environments and bytecode
- `.pyc` - Compiled Python files

## Search Locations

> **Note:** Agent labels below are illustrative for readability. In practice, each agent searches all locations — assignment is not 1:1.

| Agent | Location | Purpose | Priority |
|-------|----------|---------|----------|
| Python-Extract-1 | ~/.claude/projects/-Users-*-{PROJECT_PATH_PATTERN}/ | Conversation history with Python code blocks and discussions | High |
| Python-Extract-2 | ~/{PROJECT_ROOT}/**/*.py | Python source files from actual projects | High |
| Python-Extract-3 | ~/{PROJECT_ROOT}/tests/ | Test files, pytest fixtures, mocking patterns | Medium |
| Python-Extract-4 | ~/{PROJECT_ROOT}/pyproject.toml, requirements.txt, setup.py | Project configuration, dependencies, tooling | Low |

## Extraction Pattern

For each Python code instance found, extract:

**Code Structure:**
- Function/class definitions with complete signatures
- Docstrings (Google, NumPy, or reStructuredText style)
- Type annotations (function parameters, return types, variable hints)
- Decorator usage and custom decorator patterns
- Import organization (stdlib, third-party, local)

**Testing Patterns:**
- Test structure (AAA pattern: Arrange, Act, Assert)
- Pytest fixtures and their scopes (function, module, session)
- Parametrized tests (`@pytest.mark.parametrize`)
- Mocking strategies (unittest.mock, pytest-mock)
- Test file organization (mirror source structure vs flat)

**Error Handling:**
- Exception patterns (custom exceptions, exception hierarchies)
- Try/except/else/finally usage
- Context managers for resource cleanup
- Defensive programming patterns

**Design Patterns:**
- Async/await usage (asyncio patterns, event loops)
- Data classes vs traditional classes
- Pydantic models for validation
- Factory patterns, singletons, builders
- Dependency injection patterns
- String formatting patterns (f-strings vs .format() vs %)
- Comprehension patterns (list/dict/set comprehensions vs loops)
- Magic method implementations (__str__, __repr__, __eq__, __hash__)
- Logging patterns (logger setup, log levels, structured logging)
- Walrus operator (:=) usage patterns

**Context to Capture:**
- Why was this pattern chosen? (from conversation context)
- What problem does it solve?
- Were alternatives discussed?
- Performance or maintainability considerations
- Evolution: did the pattern change during development?

## Output Files

| File | Content | Required |
|------|---------|----------|
| README.md | Index, summary of findings, most common patterns | Yes |
| code-patterns.md | Function/class organization, decorator usage, idioms | Yes |
| testing-patterns.md | Pytest patterns, fixtures, mocking strategies | Yes |
| type-annotations.md | Type hint styles, mypy usage, generics | If type hints found |
| anti-patterns.md | Common mistakes, patterns to avoid | If anti-patterns identified |
| async-patterns.md | Asyncio, concurrent.futures, async best practices | If async code found |
| framework-usage.md | FastAPI, Flask, Django patterns by framework | If frameworks detected |

## Validation Rules

**Pre-execution checks:**
- At least one Python file exists in search locations
- Output directory is writable
- No accidental exposure of API keys in code samples

**Post-execution validation:**
- Results contain actual Python code, not just file paths
- Code samples are complete enough to understand context
- Type annotations are preserved exactly as written
- Test examples include both test code AND code under test
- No sensitive data (database credentials, API keys, secrets) in output
- All output files have proper YAML frontmatter
- Cross-references between files are valid

**Quality checks:**
- At least 10 distinct code patterns OR document why fewer found
- Patterns are categorized by type (structural, testing, async, etc.)
- Each pattern includes: code example, context, rationale (if known)
- Anti-patterns include explanation of why they're problematic

## Success Criteria

Findings should comprehensively answer:

1. **What Python patterns are commonly used?**
   - Class vs function organization
   - Decorator usage frequency and types
   - Async vs sync approaches

2. **How is testing structured?**
   - Pytest vs unittest
   - Fixture patterns and reuse
   - Mocking strategies (when to mock, what to mock)
   - Test coverage expectations

3. **What type annotation style is preferred?**
   - Inline vs stub files
   - Use of `Optional`, `Union`, generics
   - Runtime validation (Pydantic) vs static (mypy)
   - Type alias patterns

4. **What anti-patterns should be avoided?**
   - Mutable default arguments
   - Bare except clauses
   - Circular imports
   - Global state misuse
   - Over-engineering vs under-engineering

5. **How has code style evolved?**
   - Migration from older Python versions (e.g., 3.6 → 3.11)
   - Adoption of type hints over time
   - Shift to async patterns
   - Framework changes (Flask → FastAPI, etc.)

6. **How are dependencies managed?**
   - requirements.txt vs poetry vs pipenv
   - Virtual environment patterns
   - Dependency pinning strategies

7. **How is configuration handled?**
   - Environment variables vs config files
   - Pydantic Settings usage
   - Configuration validation patterns

## Anti-Patterns to Avoid During Extraction

**Do NOT extract:**
- Generated code without understanding its context or purpose
- Copy-pasted code blocks that were rejected or replaced
- Incomplete implementations (unless evolution is being tracked)
- Code from error messages (unless analyzing what went wrong)
- Hardcoded credentials, API keys, or secrets
- Highly project-specific code that won't generalize

**Do NOT conflate:**
- "Code that was written" vs "code that worked"
- "One-time experiment" vs "established pattern"
- "Suggested by Claude" vs "accepted by developer"

**Do NOT over-index on:**
- Boilerplate code (standard if __name__ == "__main__", etc.)
- Auto-generated code (ORM models, protobuf stubs)
- Trivial examples used for teaching

## Quick Extraction Commands

```bash
# Find all class definitions in conversation history
grep -r "^class " ~/.claude/projects/ --include="*.jsonl" | head -50

# Find pytest fixtures
grep -r "@pytest.fixture" ~/.claude/projects/ --include="*.jsonl"

# Find type-annotated functions
grep -r "def.*->.*:" ~/.claude/projects/ --include="*.jsonl"

# Find async patterns
grep -r "async def" ~/.claude/projects/ --include="*.jsonl"

# Find Pydantic models
grep -r "class.*BaseModel" ~/.claude/projects/ --include="*.jsonl"

# Find context managers
grep -r "with.*as.*:" ~/.claude/projects/ --include="*.jsonl"

# Find error handling patterns
grep -r "try:" ~/.claude/projects/ -A 5 --include="*.jsonl"

# Find dataclasses
grep -r "@dataclass" ~/.claude/projects/ --include="*.jsonl"

# Find decorator definitions
grep -r "def.*decorator" ~/.claude/projects/ --include="*.jsonl"

# Count Python file edits by framework
grep -r "FastAPI\|Flask\|Django" ~/.claude/projects/ --include="*.jsonl" | \
  cut -d: -f1 | sort | uniq -c | sort -rn
```

## Analysis Framework

### Key Questions for Each Pattern

1. **Context**: What problem was being solved when this pattern was used?
2. **Decision**: What approach was chosen? (e.g., class vs function, sync vs async)
3. **Rationale**: Why this approach? Was it discussed in conversation?
4. **Trade-offs**: Were alternatives mentioned? What were pros/cons?
5. **Evolution**: Did the pattern change during development? Why?
6. **Dependencies**: What libraries/frameworks does this pattern rely on?
7. **Testing**: How was this pattern tested? What made testing easy/hard?

### Extraction Checklist

For each Python pattern documented:

- [ ] Extract complete, runnable code example (not snippets)
- [ ] Include docstrings and comments (preserve developer intent)
- [ ] Document type annotations exactly as written
- [ ] Capture imports and dependencies
- [ ] Note Python version if relevant (e.g., 3.10+ union syntax)
- [ ] Link to related patterns (e.g., fixture used by this test)
- [ ] Flag experimental/deprecated patterns
- [ ] Document performance characteristics if discussed
- [ ] Note security considerations if applicable
- [ ] Cross-reference to conversation context

### Output Structure

For this domain, organize findings as:

```markdown
## Pattern: [Descriptive Name]

**Category:** [Structural | Testing | Async | Type Hints | Error Handling | etc.]
**Status:** [Common | Occasional | Experimental | Deprecated]
**Python Version:** [Minimum required version]

**Purpose:**
[What problem does this pattern solve? When should it be used?]

**Example:**
```python
# Complete, runnable example with context
from typing import Optional, List
import pytest

@pytest.fixture
def example_data() -> List[str]:
    """Fixture docstring explaining purpose."""
    return ["item1", "item2"]

def test_example(example_data: List[str]) -> None:
    """Test docstring."""
    assert len(example_data) == 2
```

**Context:**
[Where/when was this pattern used? What was the project context?]

**Rationale:**
[Why was this approach chosen? Were alternatives discussed?]

**Trade-offs:**
- **Pros:** [Advantages of this pattern]
- **Cons:** [Disadvantages or limitations]

**Related Patterns:**
- [Link to complementary or alternative patterns]

**Anti-Pattern Warning:** [If applicable, what NOT to do]

**References:**
- [Conversation: path/to/conversation.jsonl:line-range]
- [Source file: path/to/file.py]
```

## Common Patterns to Watch For

### Pattern Categories

1. **Function/Class Organization**
   - Pure functions vs stateful classes
   - Class hierarchies vs composition
   - Dataclasses for data vs traditional classes for behavior
   - Module organization (flat vs nested packages)

2. **Type System Usage**
   - Progressive typing (gradually adding hints)
   - Generic types and TypeVar usage
   - Protocol for structural subtyping
   - Literal types for enums/constants
   - Type guards and narrowing

3. **Async Programming**
   - When to use async vs threads vs processes
   - Async context managers
   - Async generators
   - Error handling in async code
   - Mixing sync and async code

4. **Testing Strategies**
   - Test organization (one test file per module vs by feature)
   - Fixture scope decisions
   - Mock vs fake vs stub
   - Integration test patterns
   - Test data builders/factories

5. **Error Handling Philosophy**
   - EAFP vs LBYL ("Easier to Ask Forgiveness" vs "Look Before You Leap")
   - Custom exception hierarchies
   - Error message quality
   - Logging vs raising

6. **Dependency Management**
   - Import style (absolute vs relative)
   - Circular dependency resolution
   - Lazy imports for performance
   - Optional dependencies handling

## Edge Cases & Gotchas

### False Positives

**Pattern:** Code in markdown code blocks that's illustrative, not production
**Why:** Conversations often include simplified examples for teaching
**Filter:** Check if code was actually written to files vs just discussed

**Pattern:** Error messages containing Python tracebacks
**Why:** grep matches `def ` and `class ` in stack traces
**Filter:** Look for message context vs file modification context

### False Negatives

**Pattern:** Python code in .ipynb (Jupyter notebooks)
**Why:** JSON structure makes grep less effective
**Mitigation:** Use jq or notebook-specific tools to extract code cells

**Pattern:** Dynamically generated code (exec, eval, code generation)
**Why:** Not searchable with static grep
**Mitigation:** Search for "exec(", "eval(", code generation frameworks

### Ambiguous Cases

**Scenario:** Code suggested by Claude but modified by developer
**Decision criteria:** Document both versions if discussion reveals reasoning
**Cross-reference:** Link to conversation showing evolution

**Scenario:** Pattern used once in experimental code
**Decision criteria:** Mark as "Experimental" vs "Common Pattern"
**Cross-reference:** Note limited usage in metadata

## Maintenance Notes

### Update Triggers

This domain definition should be reviewed when:
- Python version updates (3.11 → 3.12, new syntax features)
- Major framework adoption (adding FastAPI, dropping Flask)
- Type system changes (mypy → pyright, new typing features)
- Testing framework changes (unittest → pytest)

### Known Limitations

- **Jupyter notebooks**: Require special handling (not plain text grep)
- **Generated code**: ORM models, protobuf stubs hard to distinguish from handwritten
- **Dynamic imports**: Code using `importlib` or `__import__` harder to analyze
- **Inline scripts**: Python in CI/CD configs, Dockerfiles, shell scripts

### Related Domains

- **testing-patterns**: Overlaps with testing-patterns.md in this domain; consider if separate domain needed for language-agnostic testing
- **api-design**: REST/GraphQL API patterns often use Python frameworks (FastAPI, Flask)
- **data-modeling**: Pydantic models, dataclasses, ORM patterns
- **async-architecture**: Event-driven systems, message queues (asyncio, celery)

## Validation

### Self-Check Questions

Before publishing findings from this domain:

1. Did you verify code examples are complete and runnable?
2. Did you preserve type annotations exactly as written?
3. Did you exclude test code from __pycache__ or venv directories?
4. Did you document the "why" (rationale) not just the "what" (code)?
5. Did you link patterns to conversation context where applicable?
6. Did you check for and redact any API keys, secrets, or credentials?
7. Did you distinguish "common patterns" from "one-time experiments"?

### Quality Criteria

**Minimum viable analysis:**
- [ ] At least 10 distinct code patterns documented
- [ ] All pattern categories represented or marked as "Not Found"
- [ ] Clear distinction between active and deprecated patterns
- [ ] Type annotation patterns documented (if any type hints found)
- [ ] Testing patterns documented (if tests found)
- [ ] Import organization patterns noted

**Excellent analysis additionally includes:**
- [ ] Evolution of patterns over time (e.g., added type hints later)
- [ ] Trade-offs discussed in conversations captured
- [ ] Framework-specific patterns grouped (FastAPI, pytest, etc.)
- [ ] Anti-patterns identified with explanations
- [ ] Performance considerations documented
- [ ] Security patterns noted (input validation, SQL injection prevention)
- [ ] Recommendations for future development

## References

### Internal

- Related domain: testing-patterns (planned — not yet a separate domain)
- Related domain: api-design (planned — not yet a separate domain)

### External

- [Python Official Docs](https://docs.python.org/3/)
- [PEP 8 - Style Guide](https://peps.python.org/pep-0008/)
- [PEP 484 - Type Hints](https://peps.python.org/pep-0484/)
- [pytest Documentation](https://docs.pytest.org/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Pydantic Documentation](https://docs.pydantic.dev/)
- [Python Patterns](https://python-patterns.guide/)

---

**Created:** 2026-02-26
**Version:** 1.0.0
**Maintainer:** archaeology-skill
