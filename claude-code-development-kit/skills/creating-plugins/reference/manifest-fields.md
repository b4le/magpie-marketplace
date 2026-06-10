# Plugin Manifest (plugin.json) Field Reference

## Required Fields

Only `name` is strictly required. `version` and `description` are strongly recommended.

```json
{
  "name": "my-plugin"
}
```

## Complete Field Descriptions

### Required

### 1. name
- **Type**: String
- **Required**: Yes
- **Description**: Unique plugin identifier
- **Constraints**:
  - Lowercase
  - Use hyphens for spaces
  - Must be unique across all plugins
- **Example**: `"react-toolkit"`

## Strongly Recommended Fields

### 2. version
- **Type**: String
- **Required**: No (strongly recommended)
- **Description**: Semantic version of the plugin
- **Format**: `major.minor.patch`
- **Examples**:
  - `"1.0.0"`
  - `"2.1.3"`
  - `"0.9.5-alpha"`

### 3. description
- **Type**: String
- **Required**: No (strongly recommended)
- **Description**: Concise explanation of what the plugin does
- **Best Practices**:
  - Keep it clear and succinct
  - Explain primary purpose
- **Example**: `"Comprehensive React development toolkit with components, testing, and docs generation"`

## Optional Fields

### 4. author
- **Type**: Object
- **Description**: Creator's name and contact information
- **Required properties**: `name` (string)
- **Optional properties**: `email` (string), `url` (string)
- **Example**:
  ```json
  {"name": "Development Team", "email": "dev@company.com"}
  ```

### 5. homepage
- **Type**: URL string
- **Description**: Plugin's website or documentation
- **Example**: `"https://github.com/company/react-toolkit"`

### 6. repository
- **Type**: String (URI)
- **Description**: Source code repository URL
- **Example**: `"https://github.com/company/react-toolkit"`

### 7. license
- **Type**: String
- **Description**: Open-source license type
- **Common Examples**:
  - `"MIT"`
  - `"Apache-2.0"`
  - `"GPL-3.0"`

### 8. keywords
- **Type**: Array of strings
- **Description**: Search and discovery terms
- **Example**: `["react", "components", "testing", "typescript"]`

## Complete Example

```json
{
  "name": "react-toolkit",
  "version": "2.1.0",
  "description": "Comprehensive React development toolkit with components, testing, and docs generation",
  "author": {
    "name": "Development Team",
    "email": "dev@company.com"
  },
  "homepage": "https://github.com/company/react-toolkit",
  "repository": "https://github.com/company/react-toolkit",
  "license": "MIT",
  "keywords": ["react", "components", "testing", "typescript"]
}
```

## Validation

- Ensure `name` is present (the only required field)
- Use semantic versioning for `version` if provided
- Validate JSON syntax
- Keep descriptions clear and concise
- Specify version requirements carefully