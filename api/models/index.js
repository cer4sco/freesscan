const { Pool } = require('pg');

// Database connection configuration
const config = {
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'security_scanner',
    user: process.env.DB_USER || 'scanner',
    password: process.env.DB_PASSWORD,
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
};

const pool = new Pool(config);

// Error handling
pool.on('error', (err, client) => {
    console.error('Unexpected error on idle client', err);
    process.exit(-1);
});

// Helper functions
const query = (text, params) => pool.query(text, params);

const getClient = () => pool.connect();

module.exports = {
    pool,
    query,
    getClient
};
