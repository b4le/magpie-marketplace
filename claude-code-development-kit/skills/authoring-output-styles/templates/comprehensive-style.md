---
# Required Fields
name: comprehensive-example
purpose: |
  This is a comprehensive example demonstrating all available fields and options
  for creating output styles in Claude Code. Use this as a reference template
  when building custom output styles for skills, agents, reports, or documents.

  Target audience: Skill authors, plugin developers, and teams standardizing outputs.
category: skill-output  # Options: skill-output | document | agent | report

# Optional Metadata Fields
version: 1.0.0
author: Claude Code
created: 2025-12-06
tags: [template, reference, comprehensive, example]

# Structure Definition
# Defines the sections, order, format, and constraints for the output
structure:
  # Section 1: Summary (Required, Paragraph Format)
  - section: Summary
    required: true
    format: paragraph
    max_lines: 5
    max_words: 150
    content: |
      A concise overview of the main findings, conclusions, or deliverables.
      Should be readable as a standalone executive summary.
    guidelines:
      - Start with the most critical information
      - Avoid technical jargon unless necessary
      - Include key metrics or outcomes when applicable

  # Section 2: Key Findings (Required, Bullet List)
  - section: Key Findings
    required: true
    format: bullet-list
    max_items: 7
    min_items: 3
    content: |
      Main discoveries, insights, or results presented as concise bullets.
      Each bullet should be independently valuable.
    guidelines:
      - Start each bullet with a strong verb
      - Quantify findings when possible
      - Order by importance or impact

  # Section 3: Details (Optional, Structured List)
  - section: Details
    required: false
    format: structured-list
    max_items: 10
    content: |
      In-depth information organized as key-value pairs or structured bullets.
      Include supporting evidence, methodology, or implementation details.
    example: |
      - **Approach**: Analyzed 15 files across 3 modules
      - **Duration**: 2.5 hours of investigation
      - **Tools Used**: Grep, Read, static analysis

  # Section 4: Code Examples (Optional, Code Block)
  - section: Code Examples
    required: false
    format: code-block
    language: auto  # Options: auto | javascript | python | bash | etc.
    max_lines: 30
    content: |
      Relevant code snippets, configurations, or examples with syntax highlighting.
      Include file paths and line numbers for reference.
    guidelines:
      - Use absolute file paths in comments
      - Highlight changed/important lines
      - Keep examples focused and minimal

  # Section 5: Recommendations (Optional, Numbered List)
  - section: Recommendations
    required: false
    format: numbered-list
    max_items: 5
    priority_order: true  # Sort by priority/importance
    content: |
      Actionable next steps, improvements, or decisions needed.
      Each recommendation should be clear and implementable.
    guidelines:
      - Start with highest-priority items
      - Include owner or responsible party if known
      - Specify timeline or urgency when applicable

  # Section 6: Technical Details (Optional, Table)
  - section: Technical Details
    required: false
    format: table
    columns: [Metric, Value, Notes]
    max_rows: 10
    content: |
      Structured data presented in tabular format for easy scanning.
      Use for comparisons, metrics, configurations, or specifications.
    example: |
      | Metric | Value | Notes |
      |--------|-------|-------|
      | Files Modified | 8 | Across 3 modules |
      | Test Coverage | 87% | +5% from baseline |

  # Section 7: References (Optional, Link List)
  - section: References
    required: false
    format: link-list
    content: |
      Related files, documentation, issues, or external resources.
      Use absolute paths for files and full URLs for web resources.
    example: |
      - [Authentication Flow](/src/auth/flow.ts)
      - [Security Guidelines](https://docs.example.com/security)
      - [JIRA Ticket](https://jira.example.com/PROJECT-123)

  # Section 8: Metadata (Optional, Key-Value)
  - section: Metadata
    required: false
    format: key-value
    content: |
      Supplementary information about the output itself.
      Include timestamps, versions, agents used, or other context.
    example: |
      - Generated: 2025-12-06 14:30:00 UTC
      - Agent: claude-sonnet-4-5
      - Duration: 45 seconds
      - Context Size: 12K tokens

# Variable Definitions
# Define dynamic values that can be injected into the output
variables:
  - name: project_name
    type: string
    required: true
    description: Name of the project or codebase
    example: "auth-service"

  - name: completion_percentage
    type: number
    required: false
    description: Percentage of task completion
    default: 0
    min: 0
    max: 100

  - name: include_code_examples
    type: boolean
    required: false
    description: Whether to include code examples section
    default: true

  - name: report_date
    type: date
    required: false
    description: Date of report generation
    format: "YYYY-MM-DD"
    default: today

  - name: tags
    type: list
    required: false
    description: Classification tags for the output
    example: ["security", "performance", "refactoring"]

# Constraint Definitions
# Global rules applied across the entire output
constraints:
  max_total_lines: 150
  max_total_words: 2000
  required_sections: [Summary, Key Findings]
  prohibited_sections: []  # Sections to never include
  tone: professional  # Options: professional | casual | technical | executive
  audience: technical  # Options: technical | business | mixed | executive

# Conditional Logic (Advanced)
# Rules for when to include/exclude sections based on variables
conditionals:
  - condition: include_code_examples == true
    action: include
    sections: [Code Examples]

  - condition: completion_percentage < 100
    action: require
    sections: [Recommendations]

  - condition: audience == "executive"
    action: exclude
    sections: [Technical Details, Code Examples]

# Validation Rules
# Ensure output quality and consistency
validation:
  - rule: no_empty_sections
    message: "All included sections must have content"

  - rule: max_section_length
    threshold: 30
    message: "Individual sections should not exceed 30 lines"

  - rule: require_file_paths
    sections: [Code Examples, References]
    message: "File references must use absolute paths"

---

## Section Format Options

The following table shows all available format types for sections:

| Format | Description | Use Case | Example |
|--------|-------------|----------|---------|
| `paragraph` | Continuous prose text | Summaries, explanations | Executive summary |
| `bullet-list` | Unordered list with bullets | Key points, features | Main findings |
| `numbered-list` | Ordered list with numbers | Steps, priorities | Recommendations |
| `structured-list` | Key-value or labeled bullets | Details, attributes | Technical specs |
| `code-block` | Syntax-highlighted code | Examples, snippets | Implementation |
| `table` | Markdown table | Comparisons, metrics | Performance data |
| `link-list` | List of hyperlinks | References, resources | Related files |
| `key-value` | Label: value pairs | Metadata, config | Output metadata |

## Variable Types Reference

Variables allow dynamic content injection. Supported types:

| Type | Description | Properties | Example |
|------|-------------|------------|---------|
| `string` | Text value | `required`, `default`, `example` | `"project-name"` |
| `number` | Numeric value | `required`, `default`, `min`, `max` | `85` |
| `boolean` | True/false flag | `required`, `default` | `true` |
| `date` | Date/timestamp | `required`, `default`, `format` | `"2025-12-06"` |
| `list` | Array of values | `required`, `default`, `example` | `["tag1", "tag2"]` |

## Constraint Options Reference

Global constraints applied to the entire output:

| Constraint | Type | Description | Example |
|------------|------|-------------|---------|
| `max_total_lines` | number | Maximum lines for entire output | `150` |
| `max_total_words` | number | Maximum words for entire output | `2000` |
| `required_sections` | list | Sections that must be included | `[Summary]` |
| `prohibited_sections` | list | Sections to never include | `[Debug]` |
| `tone` | enum | Writing tone/style | `professional` |
| `audience` | enum | Target audience level | `technical` |

## Customization Notes

### Adapting This Template

1. **Copy and Rename**: Save as `your-style-name.md` in your styles directory
2. **Update Required Fields**: Change `name`, `purpose`, and `category`
3. **Customize Structure**: Add/remove sections based on your needs
4. **Define Variables**: Add dynamic values specific to your use case
5. **Set Constraints**: Adjust length limits and requirements
6. **Test**: Generate sample output to validate the style

### Best Practices

- **Start Minimal**: Begin with 3-4 core sections and expand as needed
- **Be Consistent**: Use the same format type for similar content across styles
- **Document Examples**: Include clear examples for complex sections
- **Version Control**: Increment `version` when making breaking changes
- **Test Edge Cases**: Validate with minimum and maximum content scenarios

### Common Patterns

**Executive Style**: Short Summary + Key Findings + Recommendations
**Technical Style**: Summary + Details + Code Examples + Technical Details + References
**Report Style**: Summary + structured sections + Metadata
**Agent Output**: Summary + Key Findings + References (concise, scannable)

### Integration with Skills

Reference this style in your SKILL.md:

```yaml
output_style: comprehensive-example
output_format: markdown
```

Or use inline in agent prompts:

```
Return results following the comprehensive-example output style.
Include all required sections and format code examples properly.
```
