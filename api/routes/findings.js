const express = require('express');
const router = express.Router();

// GET /api/findings - List findings with filters
router.get('/', async (req, res) => {
    const pool = req.app.locals.pool;
    const { severity, type, scan_id, is_false_positive, limit = 500 } = req.query;

    let query = `
        SELECT f.*, sl.name as severity_name, s.target, s.scan_type
        FROM findings f
        JOIN severity_levels sl ON f.severity_id = sl.id
        JOIN scans s ON f.scan_id = s.id
        WHERE 1=1
    `;
    const params = [];
    let paramCount = 0;

    if (severity) {
        paramCount++;
        query += ` AND sl.name = $${paramCount}`;
        params.push(severity.toUpperCase());
    }

    if (type) {
        paramCount++;
        query += ` AND f.finding_type = $${paramCount}`;
        params.push(type);
    }

    if (scan_id) {
        paramCount++;
        query += ` AND f.scan_id = $${paramCount}`;
        params.push(parseInt(scan_id));
    }

    if (is_false_positive !== undefined) {
        paramCount++;
        query += ` AND f.is_false_positive = $${paramCount}`;
        params.push(is_false_positive === 'true');
    }

    paramCount++;
    query += ` ORDER BY sl.weight DESC, f.created_at DESC LIMIT $${paramCount}`;
    params.push(parseInt(limit));

    try {
        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /api/findings/stats/summary - Aggregate stats (must come before /:id)
router.get('/stats/summary', async (req, res) => {
    const pool = req.app.locals.pool;
    const { scan_id } = req.query;

    try {
        let query = `
            SELECT
                sl.name as severity,
                COUNT(f.id) as total_count,
                COUNT(f.id) FILTER (WHERE f.is_false_positive = FALSE) as real_count,
                COUNT(f.id) FILTER (WHERE f.is_false_positive = TRUE) as false_positive_count
            FROM severity_levels sl
            LEFT JOIN findings f ON sl.id = f.severity_id
        `;

        const params = [];
        if (scan_id) {
            query += ' WHERE f.scan_id = $1';
            params.push(parseInt(scan_id));
        }

        query += ` GROUP BY sl.id, sl.name, sl.weight ORDER BY sl.weight DESC`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /api/findings/:id - Get finding details
router.get('/:id', async (req, res) => {
    const pool = req.app.locals.pool;

    try {
        const result = await pool.query(
            `SELECT f.*, sl.name as severity_name, s.target, s.scan_type
             FROM findings f
             JOIN severity_levels sl ON f.severity_id = sl.id
             JOIN scans s ON f.scan_id = s.id
             WHERE f.id = $1`,
            [req.params.id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Finding not found' });
        }

        res.json(result.rows[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// PATCH /api/findings/:id - Update finding (mark false positive, reviewed)
router.patch('/:id', async (req, res) => {
    const pool = req.app.locals.pool;
    const { is_false_positive, reviewed_by, notes } = req.body;

    try {
        const updates = [];
        const params = [];
        let paramCount = 0;

        if (is_false_positive !== undefined) {
            paramCount++;
            updates.push(`is_false_positive = $${paramCount}`);
            params.push(is_false_positive);
        }

        if (reviewed_by !== undefined) {
            paramCount++;
            updates.push(`reviewed_by = $${paramCount}`);
            params.push(reviewed_by);
            updates.push('reviewed_at = NOW()');
        }

        if (notes !== undefined) {
            paramCount++;
            updates.push(`notes = $${paramCount}`);
            params.push(notes);
        }

        if (updates.length === 0) {
            return res.status(400).json({ error: 'No valid fields to update' });
        }

        paramCount++;
        params.push(req.params.id);

        const query = `
            UPDATE findings
            SET ${updates.join(', ')}
            WHERE id = $${paramCount}
            RETURNING *
        `;

        const result = await pool.query(query, params);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Finding not found' });
        }

        res.json(result.rows[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
