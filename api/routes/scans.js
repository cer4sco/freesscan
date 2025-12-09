const express = require('express');
const router = express.Router();
const { spawn } = require('child_process');
const path = require('path');

// GET /api/scans - List all scans
router.get('/', async (req, res) => {
    const pool = req.app.locals.pool;
    const { status, limit = 100 } = req.query;

    try {
        let query = `
            SELECT s.*,
                   COUNT(f.id) as findings_count,
                   COUNT(f.id) FILTER (WHERE sl.name = 'CRITICAL') as critical_count,
                   COUNT(f.id) FILTER (WHERE sl.name = 'HIGH') as high_count
            FROM scans s
            LEFT JOIN findings f ON s.id = f.scan_id
            LEFT JOIN severity_levels sl ON f.severity_id = sl.id
        `;

        const params = [];
        if (status) {
            query += ' WHERE s.status = $1';
            params.push(status);
        }

        query += ' GROUP BY s.id ORDER BY s.started_at DESC LIMIT $' + (params.length + 1);
        params.push(parseInt(limit));

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /api/scans/:id - Get scan details
router.get('/:id', async (req, res) => {
    const pool = req.app.locals.pool;

    try {
        const scanResult = await pool.query(
            'SELECT * FROM scans WHERE id = $1',
            [req.params.id]
        );

        if (scanResult.rows.length === 0) {
            return res.status(404).json({ error: 'Scan not found' });
        }

        const findingsResult = await pool.query(
            `SELECT f.*, sl.name as severity_name
             FROM findings f
             JOIN severity_levels sl ON f.severity_id = sl.id
             WHERE f.scan_id = $1
             ORDER BY sl.weight DESC, f.created_at DESC`,
            [req.params.id]
        );

        res.json({
            scan: scanResult.rows[0],
            findings: findingsResult.rows
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// POST /api/scans - Start new scan
router.post('/', async (req, res) => {
    const pool = req.app.locals.pool;
    const { scan_type, target, created_by = 'api' } = req.body;

    if (!scan_type || !target) {
        return res.status(400).json({ error: 'scan_type and target required' });
    }

    if (!['secret', 'port', 'full'].includes(scan_type)) {
        return res.status(400).json({ error: 'Invalid scan_type. Must be: secret, port, or full' });
    }

    try {
        // Create scan record
        const scanResult = await pool.query(
            `INSERT INTO scans (scan_type, target, status, created_by)
             VALUES ($1, $2, 'running', $3)
             RETURNING *`,
            [scan_type, target, created_by]
        );

        const scan = scanResult.rows[0];

        // Spawn scanner process
        // Support both local and Docker environments
        const scannerPath = process.env.SCANNER_PATH || path.join(__dirname, '../../scanner/main.py');

        const scanner = spawn('python3', [
            scannerPath,
            '--type', scan_type,
            '--target', target,
            '--scan-id', scan.id.toString(),
            '--format', 'json'
        ], {
            env: {
                ...process.env,
                DB_HOST: process.env.DB_HOST || 'localhost',
                DB_PORT: process.env.DB_PORT || '5432',
                DB_NAME: process.env.DB_NAME || 'security_scanner',
                DB_USER: process.env.DB_USER || 'scanner',
                DB_PASSWORD: process.env.DB_PASSWORD
            }
        });

        scanner.on('close', async (code) => {
            const status = code === 0 || code === 1 || code === 2 ? 'completed' : 'failed';
            await pool.query(
                `UPDATE scans
                 SET status = $1, completed_at = NOW()
                 WHERE id = $2`,
                [status, scan.id]
            );
        });

        scanner.on('error', async (err) => {
            console.error('Scanner error:', err);
            await pool.query(
                `UPDATE scans
                 SET status = 'failed', completed_at = NOW()
                 WHERE id = $1`,
                [scan.id]
            );
        });

        res.status(201).json(scan);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// DELETE /api/scans/:id - Delete scan
router.delete('/:id', async (req, res) => {
    const pool = req.app.locals.pool;

    try {
        const result = await pool.query(
            'DELETE FROM scans WHERE id = $1 RETURNING *',
            [req.params.id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Scan not found' });
        }

        res.json({ message: 'Scan deleted', scan: result.rows[0] });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
