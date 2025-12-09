// This file should be IGNORED by the scanner (matches *.test.js whitelist pattern)
// Even though it contains secrets, they should NOT be reported

const EXAMPLE_KEY = "this-should-not-be-detected";
const FAKE_SECRET = "also-should-be-ignored";
const TEST_PASSWORD = "test123456";

// AWS keys that would normally be CRITICAL
const AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE";

describe('Whitelist Test', () => {
    it('should not scan this file', () => {
        // This file matches the whitelist pattern in config/patterns.json
    });
});
