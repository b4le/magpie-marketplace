# Testing Toolkit Plugin

## Overview

The Testing Toolkit plugin provides comprehensive testing tools for developers, supporting various testing strategies including unit testing, integration testing, and code coverage analysis.

## Features

### Commands

- `/testing-toolkit:test:unit` - Run unit tests for the current project
- `/testing-toolkit:test:integration` - Execute integration tests
- `/testing-toolkit:coverage` - Generate code coverage report

### Skills

- `test-generator` - Automatically generate test cases based on project structure and existing code

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

## Installation

```bash
/plugin marketplace add github https://github.com/company/testing-toolkit
/plugin install testing-toolkit@github
```

## Usage Examples

### Running Unit Tests

```bash
# Run all unit tests
/testing-toolkit:test:unit

# Run unit tests for a specific module
/testing-toolkit:test:unit --module=authentication
```

### Generating Code Coverage Report

```bash
# Generate full coverage report
/testing-toolkit:coverage

# Generate coverage for specific directories
/testing-toolkit:coverage --path=src/modules
```

## Configuration

Configure testing behavior in your project's `.claude/settings.json`:

```json
{
  "testing-toolkit": {
    "coverageThreshold": 80,
    "failOnCoverageBelow": true,
    "testFramework": "jest"
  }
}
```

## Requirements

- Claude Code version 1.0.0 or higher
- Project must have a supported test framework (Jest, Mocha, etc.)

## License

MIT License

## Contributing

1. Fork the repository
2. Create a new branch
3. Make your changes
4. Submit a pull request