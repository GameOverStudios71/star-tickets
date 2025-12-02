const express = require('express');
const router = express.Router();

module.exports = (db) => {

    // General Stats
    router.get('/stats', (req, res) => {
        // Use establishment from session if available, otherwise allow query param (for admin)
        const establishmentId = req.establishmentId || req.query.establishment_id;

        const queries = {
            totalToday: `SELECT COUNT(*) as count FROM tickets WHERE DATE(created_at) = DATE('now') ${establishmentId ? 'AND establishment_id = ?' : ''}`,
            waiting: `SELECT COUNT(*) as count FROM tickets WHERE status = 'WAITING' ${establishmentId ? 'AND establishment_id = ?' : ''}`,
            inService: `SELECT COUNT(*) as count FROM tickets WHERE status IN ('CALLED', 'IN_SERVICE') ${establishmentId ? 'AND establishment_id = ?' : ''}`,
            completed: `SELECT COUNT(*) as count FROM tickets WHERE status = 'DONE' AND DATE(created_at) = DATE('now') ${establishmentId ? 'AND establishment_id = ?' : ''}`,
            avgTime: `SELECT AVG(CAST((julianday(finished_at) - julianday(started_at)) * 24 * 60 AS INTEGER)) as avg_minutes 
                      FROM attendance_logs 
                      WHERE finished_at IS NOT NULL 
                      AND DATE(started_at) = DATE('now')
                      ${establishmentId ? 'AND user_id IN (SELECT id FROM users WHERE establishment_id = ?)' : ''}`
        };

        const params = establishmentId ? [establishmentId] : [];

        Promise.all([
            new Promise((resolve) => db.get(queries.totalToday, params, (err, row) => resolve(row?.count || 0))),
            new Promise((resolve) => db.get(queries.waiting, params, (err, row) => resolve(row?.count || 0))),
            new Promise((resolve) => db.get(queries.inService, params, (err, row) => resolve(row?.count || 0))),
            new Promise((resolve) => db.get(queries.completed, params, (err, row) => resolve(row?.count || 0))),
            new Promise((resolve) => db.get(queries.avgTime, params, (err, row) => resolve(Math.round(row?.avg_minutes || 0))))
        ]).then(([totalToday, waiting, inService, completed, avgTime]) => {
            res.json({
                totalToday,
                waiting,
                inService,
                completed,
                avgTime
            });
        });
    });

    // Active Tickets
    router.get('/tickets', (req, res) => {
        const establishmentId = req.establishmentId || req.query.establishment_id;

        const query = `
            SELECT 
                t.id,
                t.display_code,
                t.status,
                t.temp_customer_name,
                t.created_at,
                e.name as establishment_name,
                e.code as establishment_code,
                (SELECT group_concat(s.name, ', ') FROM ticket_services ts JOIN services s ON ts.service_id = s.id WHERE ts.ticket_id = t.id) as services_list
            FROM tickets t
            JOIN establishments e ON t.establishment_id = e.id
            WHERE t.status NOT IN ('DONE', 'CANCELED')
            ${establishmentId ? 'AND t.establishment_id = ?' : ''}
            ORDER BY t.created_at DESC
            LIMIT 50
        `;

        const params = establishmentId ? [establishmentId] : [];

        db.all(query, params, (err, rows) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(rows);
        });
    });

    // Tickets by Hour (for charts)
    router.get('/tickets-by-hour', (req, res) => {
        const establishmentId = req.query.establishment_id;

        const query = `
            SELECT 
                strftime('%H', created_at) as hour,
                COUNT(*) as count
            FROM tickets
            WHERE DATE(created_at) = DATE('now')
            ${establishmentId ? 'AND establishment_id = ?' : ''}
            GROUP BY hour
            ORDER BY hour
        `;

        const params = establishmentId ? [establishmentId] : [];

        db.all(query, params, (err, rows) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(rows);
        });
    });

    return router;
};
