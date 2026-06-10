# ADR-005: Schema Versioning Strategy

## Status
Accepted

## Context

The knowledge-harvester system uses multiple JSON schemas to define data contracts between pipeline stages. As the system evolves, these schemas will need to change to:
- Add new fields for additional functionality
- Modify existing structures for better performance
- Remove deprecated fields during refactoring

Currently, the system has no versioning strategy in place, which creates several challenges:
- No clear way to track schema evolution
- Difficult to identify breaking changes
- No standard for communicating compatibility
- Ambiguity about which schema version produced a given data file

Since this is a fresh system not yet in production, we have the opportunity to establish a versioning strategy from the beginning without backward compatibility constraints.

## Decision

Adopt semantic versioning (semver) for all schema versions following these guidelines:

### Version Format
- Use `MAJOR.MINOR.PATCH` format (e.g., 1.0.0)
- Start all schemas at version 1.0.0
- Include a `schemaVersion` field in all intermediate data files

### Version Increments
- **MAJOR**: Breaking changes
  - Removing required fields
  - Changing field types (e.g., string to array)
  - Renaming fields
  - Changing semantic meaning of fields
- **MINOR**: Backward-compatible additions
  - Adding new optional fields
  - Adding new enum values
  - Relaxing validation constraints
- **PATCH**: Non-functional changes
  - Documentation updates
  - Description improvements
  - Example additions
  - Comment clarifications

### Implementation Requirements
1. Every schema file must include a version property:
   ```json
   {
     "$schema": "http://json-schema.org/draft-07/schema#",
     "version": "1.0.0",
     "title": "Schema Name",
     ...
   }
   ```

2. Every intermediate data file must include the schema version:
   ```json
   {"schemaVersion": "1.0.0", "timestamp": "...", "data": {...}}
   ```

3. Schema changes must update the version according to the rules above

### No Backward Compatibility
Since this is a fresh system:
- No migration tooling required initially
- Breaking changes are acceptable
- Focus on getting schemas right rather than maintaining compatibility
- Future migration tooling can be added when needed

## Consequences

### Positive
- **Clear evolution path**: Developers can track how schemas change over time
- **Industry standard**: Semver is widely understood and has tooling support
- **Version comparison**: Tools exist for comparing and validating semver strings
- **Explicit contracts**: Data files clearly indicate which schema version they conform to
- **Future-ready**: When backward compatibility becomes important, the framework exists

### Negative
- **Manual updates**: Developers must remember to update versions on schema changes
- **Version drift**: Without automation, schema and data versions may get out of sync
- **No migration path**: Breaking changes require manual intervention or data regeneration
- **Additional metadata**: Every data file carries version overhead

### Future Considerations
- Implement schema validation tooling to enforce versioning rules
- Add migration scripts when backward compatibility becomes necessary
- Consider automated version bumping based on schema diffs
- Build tooling to validate data files against their declared schema version
