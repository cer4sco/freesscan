// Fake application config with hardcoded credentials - DO NOT DO THIS
// All credentials here are fake for testing purposes

const express = require('express');
const app = express();

// Hardcoded database credentials - BAD PRACTICE
const MONGODB_URI = "mongodb://root:password123@mongo.example.com:27017/prod";
const POSTGRES_URI = "postgresql://dbuser:dbpass789@pg.example.com:5432/app_db";

// JWT secret hardcoded - BAD PRACTICE
const JWT_SECRET = "my-super-secret-jwt-key-do-not-share-with-anyone";

// Third-party webhooks and tokens
const SLACK_WEBHOOK = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX";
const GITHUB_TOKEN = "ghp_1234567890abcdefghijklmnopqrstuvwxyz";

// API keys hardcoded
const MAILGUN_API_KEY = "key-1234567890abcdef1234567890abcdef";
const DATADOG_API_KEY = "abcdef1234567890abcdef1234567890";

app.get('/health', (req, res) => {
    res.json({ status: 'ok' });
});

module.exports = app;
