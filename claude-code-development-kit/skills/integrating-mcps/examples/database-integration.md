# Database Integration Example

## Scenario

You want to query your local database directly from Claude Code to:
- Inspect table schemas and data
- Run analytical queries
- Debug data issues
- Generate reports from database content

This example shows PostgreSQL and SQLite integration using MCP servers.

---

## Prerequisites

- Local PostgreSQL or SQLite database
- Python 3.10+ (for Python-based MCP servers)
- Claude Code installed
- `uv` or `uvx` installed (Python package runner)

---

## Option A: PostgreSQL Integration

### Step 1: Setup PostgreSQL

```bash
# Install PostgreSQL (if not already installed)
# macOS
brew install postgresql@15
brew services start postgresql@15

# Create a test database
createdb testdb

# Create sample table and data
psql testdb <<EOF
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100),
  email VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (name, email) VALUES
  ('Alice Smith', 'alice@example.com'),
  ('Bob Jones', 'bob@example.com'),
  ('Carol White', 'carol@example.com');
EOF
```

### Step 2: Install PostgreSQL MCP Server

```bash
# Install using uvx (recommended)
uvx install mcp-server-postgres

# Or using pip
pip install mcp-server-postgres
```

### Step 3: Configure Connection

Create environment variables:

```bash
export POSTGRES_CONNECTION_STRING="postgresql://localhost/testdb"
```

For production databases with authentication:

```bash
export POSTGRES_CONNECTION_STRING="postgresql://username:password@localhost:5432/dbname"
```

Add to `~/.zshrc` to persist:

```bash
echo 'export POSTGRES_CONNECTION_STRING="postgresql://localhost/testdb"' >> ~/.zshrc
source ~/.zshrc
```

### Step 4: Configure Claude Code

Edit `~/.claude.json`:

```json
{
  "mcpServers": {
    "postgres": {
      "transport": {
        "type": "stdio",
        "command": "uvx",
        "args": [
          "mcp-server-postgres"
        ]
      },
      "env": {
        "POSTGRES_CONNECTION_STRING": "${POSTGRES_CONNECTION_STRING}"
      }
    }
  }
}
```

### Step 5: Restart Claude Code and Test

In Claude Code:

```
Show me the schema for the users table
```

```
How many users are in the database?
```

```
List all users created in the last 7 days
```

---

## Option B: SQLite Integration

### Step 1: Create SQLite Database

```bash
# Create test database
sqlite3 ~/test.db <<EOF
CREATE TABLE products (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  price REAL,
  category TEXT,
  in_stock BOOLEAN
);

INSERT INTO products (name, price, category, in_stock) VALUES
  ('Laptop', 999.99, 'Electronics', 1),
  ('Mouse', 29.99, 'Electronics', 1),
  ('Desk', 299.99, 'Furniture', 0),
  ('Chair', 199.99, 'Furniture', 1);
EOF
```

### Step 2: Install SQLite MCP Server

```bash
# Install using uvx
uvx install mcp-server-sqlite

# Or using pip
pip install mcp-server-sqlite
```

### Step 3: Configure Claude Code

Edit `~/.claude.json`:

```json
{
  "mcpServers": {
    "sqlite": {
      "transport": {
        "type": "stdio",
        "command": "uvx",
        "args": [
          "mcp-server-sqlite"
        ]
      },
      "env": {
        "SQLITE_DB_PATH": "/Users/yourusername/test.db"
      }
    }
  }
}
```

**Important**: Use absolute paths for SQLite database files.

### Step 4: Test Integration

```
Show me all tables in the SQLite database
```

```
What products are in stock?
```

```
Calculate the average price by category
```

---

## Example Queries

### Schema Inspection

```
What tables exist in my database?
```

```
Describe the schema for the users table including indexes and constraints
```

```
Show me all foreign key relationships in the database
```

### Data Analysis

```
Count users by email domain
```

```
Find duplicate email addresses
```

```
Show me the top 10 products by price
```

### Complex Queries

```
Generate a report of monthly user registrations for the last 6 months
```

```
Find all products with price > $100 that are out of stock
```

```
Join users and orders tables to show total spending per user
```

### Data Validation

```
Check for NULL values in the email column
```

```
Find records with invalid email formats
```

```
Identify orphaned records (foreign key violations)
```

---

## Advanced Configuration

### Multiple Databases

```json
{
  "mcpServers": {
    "postgres-prod": {
      "transport": {
        "type": "stdio",
        "command": "uvx",
        "args": ["mcp-server-postgres"]
      },
      "env": {
        "POSTGRES_CONNECTION_STRING": "${POSTGRES_PROD_URL}"
      }
    },
    "postgres-dev": {
      "transport": {
        "type": "stdio",
        "command": "uvx",
        "args": ["mcp-server-postgres"]
      },
      "env": {
        "POSTGRES_CONNECTION_STRING": "${POSTGRES_DEV_URL}"
      }
    },
    "sqlite-local": {
      "transport": {
        "type": "stdio",
        "command": "uvx",
        "args": ["mcp-server-sqlite"]
      },
      "env": {
        "SQLITE_DB_PATH": "/Users/yourusername/local.db"
      }
    }
  }
}
```

### Read-Only Access (PostgreSQL)

```bash
# Create read-only user
psql dbname <<EOF
CREATE USER readonly WITH PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE dbname TO readonly;
GRANT USAGE ON SCHEMA public TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly;
EOF

# Use in connection string
export POSTGRES_CONNECTION_STRING="postgresql://readonly:secure_password@localhost:5432/dbname"
```

### Connection Pooling

```json
{
  "mcpServers": {
    "postgres": {
      "transport": {
        "type": "stdio",
        "command": "uvx",
        "args": ["mcp-server-postgres"]
      },
      "env": {
        "POSTGRES_CONNECTION_STRING": "${POSTGRES_CONNECTION_STRING}",
        "POSTGRES_POOL_SIZE": "5",
        "POSTGRES_MAX_OVERFLOW": "10"
      }
    }
  }
}
```

---

## Common Issues

### Issue: "Connection refused"

**Solution**:
- Verify PostgreSQL is running: `pg_isready`
- Check connection string format
- Test connection manually: `psql $POSTGRES_CONNECTION_STRING`

### Issue: "Database file not found" (SQLite)

**Solution**:
- Use absolute path, not relative path
- Verify file exists: `ls -la /path/to/database.db`
- Check file permissions: `chmod 644 /path/to/database.db`

### Issue: "Permission denied on table"

**Solution**:
- Check user has SELECT permissions
- For PostgreSQL: `GRANT SELECT ON tablename TO username;`
- For SQLite: Verify file permissions allow read access

### Issue: "SSL connection required"

**Solution**:
```bash
# Add SSL mode to connection string
export POSTGRES_CONNECTION_STRING="postgresql://user:pass@host:5432/db?sslmode=require"
```

### Issue: "Too many connections"

**Solution**:
- Check active connections: `SELECT count(*) FROM pg_stat_activity;`
- Reduce connection pool size in configuration
- Close unused connections

### Issue: "Python/uvx not found"

**Solution**:
```bash
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Or use pip
pip install mcp-server-postgres mcp-server-sqlite
```

Then use `python3 -m mcp_server_postgres` instead of `uvx mcp-server-postgres`

---

## Security Best Practices

1. **Use read-only database users** for Claude Code access
2. **Store credentials in environment variables**, never in config files
3. **Use SSL/TLS** for remote database connections
4. **Limit network access** - use localhost or VPN for production DBs
5. **Audit queries** - monitor what queries are executed
6. **Set query timeouts** to prevent long-running queries
7. **Use connection pooling** to limit concurrent connections

---

## Query Best Practices

1. **Start with simple queries** - Verify connection before complex queries
2. **Use LIMIT clauses** - Prevent accidentally returning huge result sets
3. **Test queries manually** - Verify SQL before running through MCP
4. **Be specific** - Include table names and column names in requests
5. **Check explain plans** - For slow queries, ask for EXPLAIN ANALYZE

---

## Next Steps

- Set up read replicas for heavy analytical queries
- Create database views for common queries
- Integrate with other MCP servers (Slack notifications for data alerts)
- Build custom MCP tools for complex business logic
- Schedule automated reports using database queries

---

## Resources

- PostgreSQL MCP Server: https://github.com/modelcontextprotocol/servers/tree/main/src/postgres
- SQLite MCP Server: https://github.com/modelcontextprotocol/servers/tree/main/src/sqlite
- PostgreSQL Documentation: https://www.postgresql.org/docs/
- SQLite Documentation: https://www.sqlite.org/docs.html
- MCP Specification: https://spec.modelcontextprotocol.io/
