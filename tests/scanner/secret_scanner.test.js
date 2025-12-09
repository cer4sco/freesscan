const chai = require('chai');
const { execSync } = require('child_process');
const path = require('path');
const { expect } = chai;

// Helper: Scanner exits non-zero when findings are found (CI/CD behavior)
// We need stdout regardless of exit code for tests
function execScannerAllowFail(command, options = {}) {
    try {
        return execSync(command, { encoding: 'utf-8', ...options });
    } catch (error) {
        // Scanner exits non-zero when CRITICAL/HIGH findings found - capture stdout anyway
        return error.stdout || '[]';
    }
}

describe('Secret Scanner', () => {
    const fixturesPath = path.join(__dirname, '../fixtures/sample_repo');
    const scannerPath = path.join(__dirname, '../../scanner/main.py');

    describe('AWS Credentials Detection', () => {
        it('should detect AWS access key ID', () => {
            const testFile = path.join(fixturesPath, 'aws_credentials.env');

            const result = execScannerAllowFail(
                `python3 "${scannerPath}" --type secret --target "${testFile}" --format json`
            );

            const findings = JSON.parse(result);
            const awsKeyFindings = findings.filter(f => f.type === 'aws_access_key_id');

            expect(awsKeyFindings.length).to.be.greaterThan(0);
            expect(awsKeyFindings[0]).to.have.property('severity');
            expect(awsKeyFindings[0].severity).to.equal('CRITICAL');
        });

        it('should detect AWS secret access key', () => {
            const testFile = path.join(fixturesPath, 'aws_credentials.env');

            const result = execScannerAllowFail(
                `python3 "${scannerPath}" --type secret --target "${testFile}" --format json`
            );

            const findings = JSON.parse(result);
            const awsSecretFindings = findings.filter(f => f.type === 'aws_secret_access_key');

            expect(awsSecretFindings.length).to.be.greaterThan(0);
            expect(awsSecretFindings[0].severity).to.equal('CRITICAL');
        });

        it('should redact AWS secrets (show only first 4 chars)', () => {
            const testFile = path.join(fixturesPath, 'aws_credentials.env');

            const result = execScannerAllowFail(
                `python3 "${scannerPath}" --type secret --target "${testFile}" --format json`
            );

            const findings = JSON.parse(result);
            const awsFindings = findings.filter(f => f.type.startsWith('aws_'));

            awsFindings.forEach(finding => {
                expect(finding.match).to.include('*');
                expect(finding.match).to.not.include('EXAMPLE'); // Should be redacted
            });
        });
    });

    describe('Generic Secret Detection', () => {
        it('should detect hardcoded database passwords', () => {
            const testFile = path.join(fixturesPath, 'config.py');

            const result = execScannerAllowFail(
                `python3 "${scannerPath}" --type secret --target "${testFile}" --format json`
            );

            const findings = JSON.parse(result);
            const passwordFindings = findings.filter(f =>
                f.type === 'generic_secret' || f.description.toLowerCase().includes('password')
            );

            expect(passwordFindings.length).to.be.greaterThan(0);
        });

        it('should detect API keys', () => {
            const testFile = path.join(fixturesPath, 'config.py');

            const result = execScannerAllowFail(
                `python3 "${scannerPath}" --type secret --target "${testFile}" --format json`
            );

            const findings = JSON.parse(result);
            const apiKeyFindings = findings.filter(f =>
                f.type === 'generic_api_key' || f.description.toLowerCase().includes('api')
            );

            expect(apiKeyFindings.length).to.be.greaterThan(0);
        });
    });

    describe('Private Key Detection', () => {
        it('should detect RSA private keys', () => {
            const testFile = path.join(fixturesPath, 'id_rsa.fake');

            const result = execScannerAllowFail(
                `python3 "${scannerPath}" --type secret --target "${testFile}" --format json`
            );

            const findings = JSON.parse(result);
            const keyFindings = findings.filter(f => f.type === 'private_key');

            expect(keyFindings.length).to.be.greaterThan(0);
            expect(keyFindings[0].severity).to.equal('CRITICAL');
            expect(keyFindings[0].match).to.include('*'); // Redacted format
        });
    });

    describe('GitHub Token Detection', () => {
        it('should detect GitHub personal access tokens', () => {
            const testFile = path.join(fixturesPath, '.env.example');

            const result = execScannerAllowFail(
                `python3 "${scannerPath}" --type secret --target "${testFile}" --format json`
            );

            const findings = JSON.parse(result);
            const githubFindings = findings.filter(f =>
                f.type.toLowerCase().includes('github') ||
                f.description.toLowerCase().includes('github')
            );

            expect(githubFindings.length).to.be.greaterThan(0);
        });
    });

    describe('JWT Secret Detection', () => {
        it('should detect JWT secrets', () => {
            const testFile = path.join(fixturesPath, 'app.js');

            const result = execScannerAllowFail(
                `python3 "${scannerPath}" --type secret --target "${testFile}" --format json`
            );

            const findings = JSON.parse(result);
            const jwtFindings = findings.filter(f =>
                f.description.toLowerCase().includes('jwt') ||
                f.description.toLowerCase().includes('secret')
            );

            expect(jwtFindings.length).to.be.greaterThan(0);
        });
    });

    describe('Directory Scanning', () => {
        it('should scan entire directory recursively', () => {
            const result = execScannerAllowFail(
                `python3 "${scannerPath}" --type secret --target "${fixturesPath}" --format json`
            );

            const findings = JSON.parse(result);

            // Should find secrets across multiple files
            expect(findings.length).to.be.greaterThan(10);

            // Should have findings from different files
            const uniqueFiles = [...new Set(findings.map(f => f.file))];
            expect(uniqueFiles.length).to.be.greaterThan(3);
        });

        it('should include file path and line number', () => {
            const result = execScannerAllowFail(
                `python3 "${scannerPath}" --type secret --target "${fixturesPath}" --format json`
            );

            const findings = JSON.parse(result);

            findings.forEach(finding => {
                expect(finding).to.have.property('file');
                expect(finding).to.have.property('line');
                expect(finding.line).to.be.a('number');
                expect(finding.line).to.be.greaterThan(0);
            });
        });
    });

    describe('Whitelist Functionality', () => {
        it('should respect file whitelist (*.test.js)', () => {
            const result = execScannerAllowFail(
                `python3 "${scannerPath}" --type secret --target "${fixturesPath}" --format json`
            );

            const findings = JSON.parse(result);

            // whitelist.test.js should NOT appear in findings
            const whitelistFindings = findings.filter(f => f.file.includes('whitelist.test.js'));
            expect(whitelistFindings).to.have.lengthOf(0);
        });
    });

    describe('Severity Classification', () => {
        it('should classify secrets by severity', () => {
            const result = execScannerAllowFail(
                `python3 "${scannerPath}" --type secret --target "${fixturesPath}" --format json`
            );

            const findings = JSON.parse(result);

            const bySeverity = {
                CRITICAL: findings.filter(f => f.severity === 'CRITICAL'),
                HIGH: findings.filter(f => f.severity === 'HIGH'),
                MEDIUM: findings.filter(f => f.severity === 'MEDIUM'),
                LOW: findings.filter(f => f.severity === 'LOW')
            };

            // Should have at least some CRITICAL findings (AWS keys, private keys)
            expect(bySeverity.CRITICAL.length).to.be.greaterThan(0);

            // All findings should have a valid severity
            findings.forEach(finding => {
                expect(finding.severity).to.be.oneOf(['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'INFO']);
            });
        });
    });

    describe('Output Formats', () => {
        it('should support JSON format', () => {
            const result = execScannerAllowFail(
                `python3 "${scannerPath}" --type secret --target "${fixturesPath}/aws_credentials.env" --format json`
            );

            expect(() => JSON.parse(result)).to.not.throw();
            const findings = JSON.parse(result);
            expect(findings).to.be.an('array');
        });

        it('should support summary format', () => {
            const result = execScannerAllowFail(
                `python3 "${scannerPath}" --type secret --target "${fixturesPath}/aws_credentials.env" --format summary`
            );

            expect(result).to.be.a('string');
            expect(result).to.include('CRITICAL');
        });
    });
});
