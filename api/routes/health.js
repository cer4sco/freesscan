const express = require('express');
const router = express.Router();

// GET /health - Health check
router.get('/', async (req, res) => {
    const pool = req.app.locals.pool;

    try {
        // Check database connection
        const result = await pool.query('SELECT NOW() as time');

        res.json({
            status: 'healthy',
            timestamp: new Date().toISOString(),
            database: {
                connected: true,
                server_time: result.rows[0].time
            }
        });
    } catch (err) {
        res.status(503).json({
            status: 'unhealthy',
            timestamp: new Date().toISOString(),
            database: {
                connected: false,
                error: err.message
            }
        });
    }
});

module.exports = router;
