# Behavioral Evals

Specification files that describe expected behavioral outcomes for the
claude-code-development-kit plugin. These are reference documents—not
executable test suites. They define what correct behavior looks like so
that future tooling, human reviewers, or automated runners can verify it.

## What Behavioral Evals Are

Behavioral evals test the observable behavior of Claude Code when the
development kit is installed:

- **Skill discovery** — given a user request, does Claude select the right
  skill from the available set?
- **Schema accuracy** — are the schema examples in this plugin valid, and do
  the documented invalid inputs correctly fail validation?

These complement the structural validation scripts in `evals/` (which check
file layout, frontmatter syntax, and manifest fields) by testing semantic
correctness—whether the content behaves as intended at runtime.

## File Overview

| File | What it tests |
|------|---------------|
| `skill-discovery.yaml` | User inputs map to the correct skill identifier |
| `schema-accuracy.yaml` | Schema examples produce the expected valid/invalid result |

## YAML Format

### skill-discovery.yaml

Each test case has the following fields:

```yaml
tests:
  - input: "The user's natural language request"
    expected_skill: "skill-name"   # matches the `name` in SKILL.md frontmatter
    rationale: >
      Why this skill should be selected given its description and the user's
      intent. Used for review and debugging.
```

### schema-accuracy.yaml

Each test case has the following fields:

```yaml
tests:
  - name: "Human-readable name for the test"
    schema: "schemas/plugin.schema.json"   # relative to plugin root
    input:                                 # the object to validate
      name: "example"
    expected: valid                        # or: invalid
    reason: >
      Explanation of why the input should pass or fail. Used for review
      and to produce useful output from a future test runner.
```

The `expected` field takes exactly one of two string values:

- `valid` — the input must satisfy the schema with no errors
- `invalid` — the schema must reject the input

## How to Run These Evals

These files are specifications. There is no executable runner yet. To use
them today:

**Manual review**

Read each test case and verify the outcome by hand:

1. For `skill-discovery.yaml`: load the skill and check whether the input
   phrase matches its `description` field in SKILL.md.
2. For `schema-accuracy.yaml`: validate the `input` against the named schema
   using a JSON Schema validator such as `ajv-cli`:

   ```bash
   # Install ajv-cli (requires Node.js)
   npm install -g ajv-cli

   # Validate a single input inline
   echo '{"name": "test"}' | ajv validate \
     -s schemas/plugin.schema.json \
     --data /dev/stdin
   ```

**Automated runner (future)**

When a runner is implemented, it should:

1. Parse the YAML file.
2. For `skill-discovery.yaml`: send each `input` to Claude Code with the
   plugin installed and assert that the selected skill matches
   `expected_skill`.
3. For `schema-accuracy.yaml`: validate each `input` against the referenced
   schema and assert that the result matches `expected`.
4. Report pass/fail per test case with the `name` or `input` as the label.

## How to Add New Test Cases

### Adding a skill-discovery case

1. Open `skill-discovery.yaml`.
2. Append a new entry to the `tests` list:

   ```yaml
   - input: "I need to do X"
     expected_skill: "skill-name"
     rationale: >
       Explain what in the skill description matches this input and why
       no other skill is a better fit.
   ```

3. Ensure `expected_skill` exactly matches the `name` field in the target
   skill's SKILL.md frontmatter.
4. If you are adding a new skill to the plugin, add at least one positive
   test case for it and one case that should NOT select it (to verify
   disambiguation).

### Adding a schema-accuracy case

1. Open `schema-accuracy.yaml`.
2. Append a new entry to the `tests` list:

   ```yaml
   - name: "Short description of what is being tested"
     schema: "schemas/plugin.schema.json"
     input:
       field: value
     expected: valid   # or: invalid
     reason: >
       Explain which constraint causes the outcome.
   ```

3. Add cases for both valid and invalid inputs when introducing a new
   schema field or constraint.
4. Prefer minimal inputs—include only the fields needed to exercise the
   specific constraint being tested.

## Relationship to Other Evals

```
evals/
  *.sh                    # Structural validators (file layout, JSON syntax)
  ci/                     # CI/CD integration for structural validators
  behavioral/             # This directory: semantic / behavioral specs
    skill-discovery.yaml
    schema-accuracy.yaml
    README.md
```

Structural validators (`evals/*.sh`) answer: "Is the plugin well-formed?"
Behavioral evals answer: "Does the plugin behave correctly?"

Both layers are needed for confidence in a plugin release.
