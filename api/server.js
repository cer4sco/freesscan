require('dotenv').config();

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();
const PORT = process.env.PORT || 3000;

// Database connection
const pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'security_scanner',
    user: process.env.DB_USER || 'scanner',
    password: process.env.DB_PASSWORD
});

// Test database connection
pool.query('SELECT NOW()', (err, res) => {
    if (err) {
        console.error('Database connection error:', err);
    } else {
        console.log('Database connected successfully');
    }
});

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Request logging
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
    next();
});

// Make pool available to routes
app.locals.pool = pool;

// Routes
const scansRouter = require('./routes/scans');
const findingsRouter = require('./routes/findings');
const healthRouter = require('./routes/health');

app.use('/api/scans', scansRouter);
app.use('/api/findings', findingsRouter);
app.use('/health', healthRouter);

// Root endpoint
app.get('/', (req, res) => {
    res.json({
        service: 'Security Scanner Security Scanner API',
        version: '1.0.0',
        endpoints: {
            scans: '/api/scans',
            findings: '/api/findings',
            health: '/health'
        }
    });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({ error: 'Not found' });
});

// Error handler
app.use((err, req, res, next) => {
    console.error('Error:', err.stack);
    res.status(500).json({ error: 'Internal server error' });
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, closing server...');
    pool.end(() => {
        console.log('Database pool closed');
        process.exit(0);
    });
});

// Only start server if this file is run directly (not required by tests)
if (require.main === module) {
    app.listen(PORT, () => {
        console.log(`Security Scanner API running on port ${PORT}`);
    });
}

module.exports = app;
