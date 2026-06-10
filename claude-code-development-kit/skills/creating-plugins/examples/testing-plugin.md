# Testing Toolkit Plugin Example

## Overview
This plugin provides comprehensive testing tools for unit, integration, and code coverage analysis.

## Plugin Structure
```
testing-toolkit/
├── .claude-plugin/
│   └── plugin.json
├── commands/
│   ├── test-unit.md
│   ├── test-integration.md
│   └── coverage.md
├── skills/
│   └── test-generator/
│       └── SKILL.md
└── README.md
```

## Plugin Configuration
**File**: `.claude-plugin/plugin.json`
```json
{
  "name": "testing-toolkit",
  "version": "1.0.0",
  "description": "Comprehensive testing tools for unit, integration, and coverage",
  "author": { "name": "QA Team" },
  "keywords": ["testing", "unit-tests", "code-coverage"]
}
```

## Commands

### Unit Testing Command
**File**: `commands/test-unit.md`
```markdown
---
description: Run unit tests for the current project
---

Run comprehensive unit tests using the project's default testing framework.

### Usage
\`\`\`bash
/testing-toolkit:test-unit
\`\`\`

### Options
- `--coverage`: Generate code coverage report
- `--verbose`: Show detailed test output
```

### Integration Testing Command
**File**: `commands/test-integration.md`
```markdown
---
description: Execute integration test suite
---

Run end-to-end and integration tests across the project.

### Usage
\`\`\`bash
/testing-toolkit:test-integration
\`\`\`

### Options
- `--filter`: Run specific integration test groups
- `--timeout`: Set maximum test execution time
```

### Code Coverage Command
**File**: `commands/coverage.md`
```markdown
---
description: Generate code coverage report
---

Generate and display code coverage metrics for the project.

### Usage
\`\`\`bash
/testing-toolkit:coverage
\`\`\`

### Output Formats
- HTML report
- Console summary
- XML for CI/CD integration
```

## Test Generator Skill
**File**: `skills/test-generator/SKILL.md`
```yaml
---
name: test-generator
description: Automatically generate test cases for different project types
---

# Test Case Generator Skill

## When to Use
- Bootstrapping new projects
- Adding tests to existing codebases
- Generating comprehensive test coverage

## Supported Frameworks
- Jest (JavaScript/TypeScript)
- PyTest (Python)
- RSpec (Ruby)
- JUnit (Java)
```

## README
**File**: `README.md`
```markdown
# Testing Toolkit Plugin

Comprehensive testing tools for modern development workflows.

## Features

- Unit Testing
- Integration Testing
- Code Coverage Analysis
- Test Case Generation

## Installation

\`\`\`bash
/plugin marketplace add testing-toolkit
/plugin install testing-toolkit
\`\`\`

## Usage

### Commands
- `/testing-toolkit:test-unit` - Run unit tests
- `/testing-toolkit:test-integration` - Run integration tests
- `/testing-toolkit:coverage` - Generate code coverage report

### Skills
- `test-generator` - Automatically generate test cases
```

## When to Use This Plugin Pattern
- For projects requiring standardized testing workflows
- Teams wanting to enforce testing best practices
- Continuous Integration (CI) pipelines
- Microservice and monorepo environments

## Best Practices
- Keep tests framework-agnostic
- Provide clear, concise command options
- Generate human-readable reports
- Support multiple output formats
```