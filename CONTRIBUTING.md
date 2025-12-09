# Contributing to freesscan

Contributions are welcome. This document outlines the process and standards for contributing to the project.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/your-username/freesscan.git`
3. Create a branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test your changes
6. Commit with clear messages
7. Push to your fork
8. Open a pull request

## Development Setup

### Prerequisites

- Python 3.9+
- Node.js 18+
- PostgreSQL 15+
- jq (for CI/CD scripts)
- Docker (optional, for testing)

### Install Dependencies

```bash
# Python dependencies
cd scanner
pip install -r requirements.txt

# Node.js dependencies
cd api
npm install

# Test dependencies
cd tests
npm install
```

### Start Development Environment

```bash
# Using Docker Compose
docker-compose up -d

# Manual setup
./db/scripts/init-db.sh
cd api && npm run dev
```

## Code Standards

### Python

- Follow PEP 8 style guide
- Use type hints where applicable
- Maximum line length: 100 characters
- Use docstrings for all functions and classes

```python
def scan_file(self, filepath: str) -> Generator[Dict, None, None]:
    """Scan single file for secrets.

    Args:
        filepath: Path to file to scan

    Yields:
        Dict containing finding information
    """
```

### JavaScript

- Use ES6+ syntax
- Async/await over callbacks
- Maximum line length: 100 characters
- JSDoc comments for functions

```javascript
/**
 * Start new security scan
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
async function startScan(req, res) {
    // Implementation
}
```

### Shell Scripts

- Use `#!/bin/bash` shebang
- Set `set -e` for error handling
- Quote all variables: `"$VAR"`
- Use meaningful variable names

## Adding Detection Patterns

### Pattern Structure

```python
{
    'name': 'pattern_identifier',
    'regex': r'regex_pattern',
    'severity': 'CRITICAL|HIGH|MEDIUM|LOW|INFO',
    'description': 'What this pattern detects',
    'remediation': 'How to fix the issue'
}
```

### Adding New Pattern

1. Add to appropriate file in `scanner/patterns/`:
   - `aws.py` for AWS credentials
   - `generic.py` for general secrets
   - `cloud.py` for cloud provider credentials

2. Add test case in `tests/fixtures/sample_repo/`

3. Add test in `tests/scanner/secret_scanner.test.js`

4. Update documentation if needed

### Pattern Guidelines

- Use specific patterns over generic ones
- Test regex thoroughly
- Minimize false positives
- Include clear remediation steps
- Consider performance impact

## Database Changes

### Schema Modifications

1. Update `db/schema.sql`
2. Create migration script if needed
3. Update seed data in `db/seed.sql`
4. Test migration path
5. Document changes in pull request

### Adding Tables

```sql
CREATE TABLE IF NOT EXISTS table_name (
    id SERIAL PRIMARY KEY,
    -- columns
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_table_field ON table_name(field);
```

## API Changes

### Adding Endpoints

1. Create route handler in `api/routes/`
2. Add endpoint to router
3. Update API documentation in README
4. Add integration tests
5. Test error handling

### Example Route

```javascript
// GET /api/resource/:id
router.get('/:id', async (req, res) => {
    const pool = req.app.locals.pool;

    try {
        const result = await pool.query(
            'SELECT * FROM table WHERE id = $1',
            [req.params.id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Not found' });
        }

        res.json(result.rows[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});
```

## Documentation

### Code Documentation

- Document all public APIs
- Include usage examples
- Document configuration options
- Explain non-obvious logic

### README Updates

Update README.md when:

- Adding new features
- Changing API endpoints
- Modifying configuration
- Adding dependencies

## Commit Messages

### Format

```text
type(scope): subject

body

footer
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Test additions or changes
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `chore`: Build/tooling changes

### Examples

```text
feat(scanner): add support for Terraform secrets

Add detection patterns for Terraform Cloud tokens and
AWS provider credentials in .tf files.

Closes #123
```

```text
fix(api): handle database connection timeout

Add retry logic and proper error handling for database
connection failures in API routes.
```

## Pull Request Process

### Before Submitting

- Run all tests locally
- Update documentation
- Add tests for new features
- Follow code style guidelines
- Rebase on latest main branch

### PR Description

Include:

- Summary of changes
- Motivation and context
- Testing performed
- Screenshots (if UI changes)
- Related issues

### Review Process

1. Automated tests must pass
2. Code review by maintainer
3. Address review feedback
4. Squash commits if requested
5. Maintainer merges when approved

## Questions

For questions or discussions, open an issue with the `question` label.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
