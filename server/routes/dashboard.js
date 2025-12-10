const express = require('express');
const router = express.Router();
const queries = require('../database/queries');

module.exports = (db) => {

    // General Stats
    router.get('/stats', (req, res) => {
        const establishmentId = req.establishmentId || req.query.establishment_id;
        const { clause, params } = queries.addEstablishmentFilter('establishment_id', establishmentId);

        const statsQueries = {
            totalToday: `SELECT COUNT(*) as count FROM tickets WHERE DATE(created_at) = DATE('now')${clause}`,
            waiting: `SELECT COUNT(*) as count FROM tickets WHERE status = 'WAITING'${clause}`,
            inService: `SELECT COUNT(*) as count FROM tickets WHERE status IN ('CALLED', 'IN_SERVICE')${clause}`,
            completed: `SELECT COUNT(*) as count FROM tickets WHERE status = 'DONE' AND DATE(created_at) = DATE('now')${clause}`,
            avgTime: `SELECT AVG(CAST((julianday(finished_at) - julianday(started_at)) * 24 * 60 AS INTEGER)) as avg_minutes 
                      FROM attendance_logs 
                      WHERE finished_at IS NOT NULL 
                      AND DATE(started_at) = DATE('now')${establishmentId ? ' AND user_id IN (SELECT id FROM users WHERE establishment_id = ?)' : ''}`
        };

        Promise.all([
            new Promise((resolve) => db.get(statsQueries.totalToday, params, (err, row) => resolve(row?.count || 0))),
            new Promise((resolve) => db.get(statsQueries.waiting, params, (err, row) => resolve(row?.count || 0))),
            new Promise((resolve) => db.get(statsQueries.inService, params, (err, row) => resolve(row?.count || 0))),
            new Promise((resolve) => db.get(statsQueries.completed, params, (err, row) => resolve(row?.count || 0))),
            new Promise((resolve) => db.get(statsQueries.avgTime, params, (err, row) => resolve(Math.round(row?.avg_minutes || 0))))
        ]).then(([totalToday, waiting, inService, completed, avgTime]) => {
            res.json({ totalToday, waiting, inService, completed, avgTime });
        });
    });

    // Active Tickets
    router.get('/tickets', (req, res) => {
        const establishmentId = req.establishmentId || req.query.establishment_id;
        const { clause, params } = queries.addEstablishmentFilter('t.establishment_id', establishmentId);

        const query = `
            SELECT 
                t.id, t.display_code, t.status, t.temp_customer_name, t.created_at,
                e.name as establishment_name, e.code as establishment_code,
                (SELECT group_concat(s.name, ', ') FROM ticket_services ts JOIN services s ON ts.service_id = s.id WHERE ts.ticket_id = t.id) as services_list
            FROM tickets t
            JOIN establishments e ON t.establishment_id = e.id
            WHERE t.status NOT IN ('DONE', 'CANCELED')${clause}
            ORDER BY t.created_at DESC
            LIMIT 50
        `;

        db.all(query, params, (err, rows) => {
            if (err) return queries.handleDbError(res, err);
            res.json(rows);
        });
    });

    // Tickets by Hour (for charts)
    router.get('/tickets-by-hour', (req, res) => {
        const { clause, params } = queries.addEstablishmentFilter('establishment_id', req.query.establishment_id);

        const query = `
            SELECT strftime('%H', created_at) as hour, COUNT(*) as count
            FROM tickets
            WHERE DATE(created_at) = DATE('now')${clause}
            GROUP BY hour
            ORDER BY hour
        `;

        db.all(query, params, (err, rows) => {
            if (err) return queries.handleDbError(res, err);
            res.json(rows);
        });
    });

    return router;
};
