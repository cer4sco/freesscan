# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-06

### Added

- **Secret Scanner**: Detect hardcoded credentials in source code
  - AWS Access Keys and Secret Keys
  - GitHub Personal Access Tokens
  - Generic API keys and passwords
  - RSA/SSH private keys
  - JWT secrets
  - Cloud provider credentials (GCP, Azure, Heroku)

- **Port Scanner**: Network reconnaissance with service detection
  - Common port scanning (21, 22, 80, 443, 3306, 5432, etc.)
  - Banner grabbing for service identification
  - Severity-based risk assessment
  - Configurable port ranges and timeouts

- **REST API**: Full HTTP interface for automation
  - `POST /api/scans` - Start new scans
  - `GET /api/scans/:id` - Get scan details with findings
  - `GET /api/findings` - List/filter findings
  - `PATCH /api/findings/:id` - Mark false positives
  - `GET /api/findings/stats/summary` - Aggregate statistics
  - `GET /health` - Health check with DB status

- **Database Storage**: PostgreSQL backend
  - Persistent scan history
  - Severity classification (CRITICAL, HIGH, MEDIUM, LOW, INFO)
  - False positive tracking
  - Custom pattern storage

- **CI/CD Integration**: Pipeline-ready design
  - Exit code 2 for CRITICAL findings
  - Exit code 1 for HIGH findings
  - Exit code 0 for clean scans
  - JSON output format for parsing

- **Container Support**: Docker/Podman deployment
  - Multi-container setup via docker-compose
  - Mac-optimized UID handling for Podman
  - Health checks and graceful shutdown

- **Test Suite**: Comprehensive testing (50 tests)
  - Scanner unit tests (24 tests)
  - API unit tests (26 tests)
  - Integration test runner
  - Proper mock isolation

### Fixed

- Scanner exit codes now properly preserved for CI/CD integration
- API server conditional startup prevents port conflicts in tests
- Database mocking uses `app.locals.pool` replacement pattern
- Health endpoint returns proper 503 on database failure
- Container UID conflicts resolved for Mac/Podman users
- API container port: 8080
- Test files (`.test.js`) excluded from secret scanning

### Security

- Secrets redacted in output (shows first 4 chars only)
- Non-root container users
- Helmet.js security headers on API
- CORS configuration
- Prepared statements for SQL queries

### Documentation

- Complete README with usage examples
- API reference documentation
- CI/CD integration guides (GitHub Actions, GitLab CI)
- Troubleshooting section
- Architecture diagram (Mermaid)

## [Unreleased]

### Planned

- WebSocket support for real-time scan updates
- Slack/Teams notifications
- SARIF output format for GitHub Security tab
- Kubernetes Helm chart
- Multi-repo batch scanning
- Custom pattern management UI

---

## Release Notes

### v1.0.0 Highlights

This is the first stable release of freesscan, a self-hosted vulnerability detection tool designed for DevSecOps pipelines.

**Target Platform**: macOS (Apple Silicon) with Podman
**Built With**: Skills from [freeCodeCamp](https://freecodecamp.org)

**Quick Start**:

```bash
# Clone and start
git clone https://github.com/cer4sco/freesscan.git
cd freesscan
podman-compose up -d

# Run a scan
curl -X POST http://localhost:8080/api/scans \
  -H "Content-Type: application/json" \
  -d '{"scan_type":"secret","target":"/path/to/repo"}'
```

**Run Tests**:

```bash
cd tests
npm install
npm test  # 50 passing
```
