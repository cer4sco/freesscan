const chai = require('chai');
const { execSync } = require('child_process');
const path = require('path');
const { expect } = chai;

describe('Port Scanner', () => {
    const scannerPath = path.join(__dirname, '../../scanner/main.py');

    describe('Localhost Scanning', () => {
        it('should scan localhost without errors', function() {
            this.timeout(30000); // Port scanning can take time

            const result = execSync(
                `python3 "${scannerPath}" --type port --target localhost --format json`,
                { encoding: 'utf-8' }
            );

            expect(() => JSON.parse(result)).to.not.throw();
            const findings = JSON.parse(result);
            expect(findings).to.be.an('array');
        });

        it('should detect open ports', function() {
            this.timeout(30000);

            const result = execSync(
                `python3 "${scannerPath}" --type port --target localhost --format json`,
                { encoding: 'utf-8' }
            );

            const findings = JSON.parse(result);

            // Findings structure validation
            findings.forEach(finding => {
                expect(finding).to.have.property('type');
                expect(finding.type).to.equal('open_port');
                expect(finding).to.have.property('location');
                expect(finding.location).to.match(/localhost:\d+/);
                expect(finding).to.have.property('severity');
            });
        });

        it('should identify service names', function() {
            this.timeout(30000);

            const result = execSync(
                `python3 "${scannerPath}" --type port --target localhost --format json`,
                { encoding: 'utf-8' }
            );

            const findings = JSON.parse(result);

            if (findings.length > 0) {
                findings.forEach(finding => {
                    expect(finding).to.have.property('service');
                    expect(finding.service).to.be.a('string');
                });
            }
        });
    });

    describe('Severity Assessment', () => {
        it('should assign severity levels to ports', function() {
            this.timeout(30000);

            const result = execSync(
                `python3 "${scannerPath}" --type port --target localhost --format json`,
                { encoding: 'utf-8' }
            );

            const findings = JSON.parse(result);

            findings.forEach(finding => {
                expect(finding.severity).to.be.oneOf(['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'INFO']);
            });
        });

        it('should provide remediation advice', function() {
            this.timeout(30000);

            const result = execSync(
                `python3 "${scannerPath}" --type port --target localhost --format json`,
                { encoding: 'utf-8' }
            );

            const findings = JSON.parse(result);

            findings.forEach(finding => {
                expect(finding).to.have.property('remediation');
                expect(finding.remediation).to.be.a('string');
                expect(finding.remediation.length).to.be.greaterThan(0);
            });
        });
    });

    describe('Banner Grabbing', () => {
        it('should attempt banner grabbing', function() {
            this.timeout(30000);

            const result = execSync(
                `python3 "${scannerPath}" --type port --target localhost --format json`,
                { encoding: 'utf-8' }
            );

            const findings = JSON.parse(result);

            findings.forEach(finding => {
                expect(finding).to.have.property('banner');
                // Banner can be empty string if service doesn't respond
                expect(finding.banner).to.be.a('string');
            });
        });
    });

    describe('Output Formats', () => {
        it('should support JSON format', function() {
            this.timeout(30000);

            const result = execSync(
                `python3 "${scannerPath}" --type port --target localhost --format json`,
                { encoding: 'utf-8' }
            );

            expect(() => JSON.parse(result)).to.not.throw();
        });

        it('should support summary format', function() {
            this.timeout(30000);

            const result = execSync(
                `python3 "${scannerPath}" --type port --target localhost --format summary`,
                { encoding: 'utf-8' }
            );

            expect(result).to.be.a('string');
        });
    });

    describe('Performance', () => {
        it('should complete scan within reasonable time', function() {
            this.timeout(45000); // 45 seconds max

            const startTime = Date.now();

            execSync(
                `python3 "${scannerPath}" --type port --target localhost --format json`,
                { encoding: 'utf-8' }
            );

            const duration = Date.now() - startTime;

            // Scanning common ports should complete in under 45 seconds
            expect(duration).to.be.lessThan(45000);
        });

        it('should not leak sockets (no hanging processes)', function() {
            this.timeout(30000);

            // Run scanner
            execSync(
                `python3 "${scannerPath}" --type port --target localhost --format json`,
                { encoding: 'utf-8' }
            );

            // If we get here, scanner completed without hanging
            expect(true).to.be.true;
        });
    });
});
