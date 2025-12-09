# Security Scanner - Test Suite

Complete test suite with fixtures, unit tests, and integration tests.

## Structure

```text
tests/
├── fixtures/
│   ├── sample_repo/          # Fake repo with planted secrets
│   │   ├── aws_credentials.env
│   │   ├── config.py
│   │   ├── app.js
│   │   ├── docker-compose.yml
│   │   ├── id_rsa.fake
│   │   ├── .env.example
│   │   └── whitelist.test.js  # Should be ignored by scanner
│   └── expected/              # Expected scan outputs
│       ├── secret-scan-results.json
│       └── port-scan-results.json
├── api/                       # API unit tests
│   ├── health.test.js
│   ├── scans.test.js
│   └── findings.test.js
├── scanner/                   # Scanner unit tests
│   ├── secret_scanner.test.js
│   └── port_scanner.test.js
├── integration/
│   └── run-all.sh            # Full integration test suite
├── package.json              # Test dependencies
└── README.md                 # This file
```

## Running Tests

### Unit Tests Only

```bash
cd tests
npm test
```

Runs all Mocha unit tests (API + scanner).

### API Tests Only

```bash
cd tests
npm run test:api
```

### Scanner Tests Only

```bash
cd tests
npm run test:scanner
```

### Integration Tests (Full Suite)

```bash
./tests/integration/run-all.sh
```

Runs complete test suite:

1. Prerequisites check (python3, node, psql, docker, jq)
2. Database initialization and seed data
3. Secret scanner tests on fixtures
4. Port scanner tests on localhost
5. API server tests (health, scans, findings)
6. Mocha unit tests
7. Docker deployment tests (optional)

Results saved to `test-results.log`.

### Coverage Report

```bash
cd tests
npm run test:coverage
```

Generates code coverage report using nyc.

## Test Fixtures

All secrets in `fixtures/sample_repo/` are **fake** and safe to commit:

- AWS keys use `AKIAIOSFODNN7EXAMPLE` pattern
- Private keys are truncated/invalid
- Tokens are random strings with no real access
- Passwords are obvious test values

### Fixture Contents

| File | Secrets | Severity |
| ---- | ------- | -------- |
| `aws_credentials.env` | AWS access key, secret key, session token | CRITICAL |
| `config.py` | Database passwords, API keys, Redis password | HIGH |
| `app.js` | JWT secret, MongoDB URI, Slack webhook, GitHub token | HIGH/MEDIUM |
| `docker-compose.yml` | Hardcoded database passwords | MEDIUM |
| `id_rsa.fake` | Fake RSA private key | CRITICAL |
| `.env.example` | GitHub, Stripe, SendGrid keys | HIGH/MEDIUM |
| `whitelist.test.js` | Should be ignored (*.test.js pattern) | N/A |

## Expected Results

Files in `fixtures/expected/` show what successful scans should return:

- `secret-scan-results.json`: Minimum 15 findings across 6 files
- `port-scan-results.json`: Variable based on local services

Use these to validate scanner behavior in tests.

## Test Coverage

### API Tests (50+ test cases)

- **health.test.js**: Health endpoint, database connection, error handling
- **scans.test.js**: GET/POST scans, validation, scan details, errors
- **findings.test.js**: GET findings, filters, route ordering, PATCH updates

### Scanner Tests (30+ test cases)

- **secret_scanner.test.js**:
  - AWS credentials detection (access key, secret key)
  - Generic secrets (passwords, API keys)
  - Private key detection (RSA)
  - GitHub tokens
  - JWT secrets
  - Directory scanning
  - Whitelist functionality
  - Severity classification
  - Secret redaction
  - Output formats (JSON, summary)

- **port_scanner.test.js**:
  - Localhost scanning
  - Service identification
  - Severity assessment
  - Banner grabbing
  - Performance validation (<45s)
  - Socket leak prevention

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: changeme
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'

      - name: Install dependencies
        run: |
          cd api && npm install
          cd ../tests && npm install

      - name: Run integration tests
        run: ./tests/integration/run-all.sh
```

## Debugging Test Failures

### View Full Test Output

```bash
cat test-results.log
```

### Run Specific Test

```bash
cd tests
npx mocha api/health.test.js
```

### Increase Mocha Timeout

For slow port scans:

```bash
npx mocha --timeout 60000 scanner/port_scanner.test.js
```

### Check Database

```bash
psql -U scanner -d security_scanner -c "SELECT * FROM scans;"
psql -U scanner -d security_scanner -c "SELECT * FROM findings LIMIT 5;"
```

## Known Issues

1. **Port scanner tests may fail if no ports are open**
   - Solution: Tests expect at least PostgreSQL (5432) to be running

2. **Docker tests require Docker daemon running**
   - Solution: Start Docker Desktop or skip with Ctrl+C during Docker phase

3. **Database connection errors**
   - Solution: Run `./db/scripts/init-db.sh` manually

## Adding New Tests

### New API Test

```javascript
// tests/api/new-endpoint.test.js
const chai = require('chai');
const chaiHttp = require('chai-http');
const { expect } = chai;

chai.use(chaiHttp);

describe('New Endpoint', () => {
    let app;

    beforeEach(() => {
        app = require('../../api/server.js');
    });

    it('should do something', (done) => {
        chai.request(app)
            .get('/api/new-endpoint')
            .end((err, res) => {
                expect(res).to.have.status(200);
                done();
            });
    });
});
```

### New Scanner Test

```javascript
// tests/scanner/new-scanner.test.js
const { execSync } = require('child_process');
const path = require('path');
const { expect } = chai;

describe('New Scanner', () => {
    it('should scan something', () => {
        const result = execSync(
            `python3 ${scannerPath} --type new --target /tmp`,
            { encoding: 'utf-8' }
        );

        expect(result).to.not.be.empty;
    });
});
```

## Maintenance

### Update Test Fixtures

When adding new pattern detection:

1. Add sample to `fixtures/sample_repo/`
2. Update `expected/secret-scan-results.json`
3. Add test case in `scanner/secret_scanner.test.js`
4. Run tests to validate

### Update Expected Findings

If scanner behavior changes legitimately:

1. Run scanner on fixtures
2. Review output
3. Update `expected/*.json` if changes are correct
4. Re-run tests to confirm

## Resources

- [Mocha Documentation](https://mochajs.org/)
- [Chai Assertions](https://www.chaijs.com/)
- [Chai-HTTP](https://www.chaijs.com/plugins/chai-http/)
- [Sinon.js (Mocking)](https://sinonjs.org/)

## License

MIT - Test fixtures contain only fake credentials safe for public repos.
