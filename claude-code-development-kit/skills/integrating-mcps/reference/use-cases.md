# Common Use Cases

## 1. Issue Tracker Integration (Jira, Linear, GitHub)

```bash
claude mcp add --transport http jira https://jira.company.com/mcp
/mcp  # Authenticate
```

**Usage**:
```
Create a Jira ticket for the bug we just found
List all open issues assigned to me
Update PROJ-123 status to "In Progress"
```

## 2. Database Access

```bash
claude mcp add --transport stdio postgres -- npx mcp-postgres-server
```

**Usage**:
```
Query the users table for accounts created this week
Show me the schema for the orders table
Insert a test record into the products table
```

## 3. Design Tool Integration (Figma)

```bash
claude mcp add --transport http figma https://api.figma.com/mcp
/mcp  # Authenticate with Figma
```

**Usage**:
```
Review the latest designs from @figma:file://project/dashboard
Extract color palette from the design file
Compare current implementation with design specs
```

## 4. Monitoring & Analytics

```bash
claude mcp add --transport http datadog https://api.datadoghq.com/mcp
```

**Usage**:
```
Check error rates for the API service in the last hour
Show me the performance metrics for the database
Analyze the recent spike in response times
```

## 5. Documentation Systems

```bash
claude mcp add --transport stdio notion -- npx mcp-notion-server
```

**Usage**:
```
Search our documentation for authentication flow
Update the onboarding guide with new steps
Create a new page for this feature documentation
```

## 6. Cloud Providers (AWS, GCP, Azure)

```bash
claude mcp add --transport stdio aws -- aws-mcp-server --profile dev
```

**Usage**:
```
List all S3 buckets in the development account
Check the status of the production ECS service
View CloudWatch logs for the lambda function
```
