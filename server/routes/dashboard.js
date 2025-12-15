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
                (SELECT group_concat(s.name, ', ') FROM ticket_services ts JOIN services s ON ts.service_id = s.id WHERE ts.ticket_id = t.id) as services_list,
                (SELECT status FROM ticket_services WHERE ticket_id = t.id ORDER BY updated_at DESC LIMIT 1) as service_status,
                (SELECT room_id FROM ticket_services WHERE ticket_id = t.id ORDER BY updated_at DESC LIMIT 1) as current_room_id,
                (SELECT name FROM rooms WHERE id = (SELECT room_id FROM ticket_services WHERE ticket_id = t.id ORDER BY updated_at DESC LIMIT 1)) as room_name
            FROM tickets t
            JOIN establishments e ON t.establishment_id = e.id
            WHERE (t.status NOT IN ('CANCELED') OR (t.status = 'DONE' AND DATE(t.created_at) = DATE('now')))
            ${clause}
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

    // Ticket Timeline - Search by ticket code or customer name
    router.get('/ticket-timeline', (req, res) => {
        const { ticket_code, customer_name, date } = req.query;
        const establishmentId = req.establishmentId || req.query.establishment_id;

        if (!ticket_code && !customer_name && !date) {
            return res.status(400).json({ error: 'Informe o código da senha, nome do cliente ou data.' });
        }

        // First, find the ticket
        let ticketQuery = `
            SELECT t.id, t.display_code, t.status, t.temp_customer_name, t.created_at, t.is_priority,
                   t.health_insurance_name, e.name as establishment_name
            FROM tickets t
            JOIN establishments e ON t.establishment_id = e.id
            WHERE 1=1
        `;
        const ticketParams = [];

        if (ticket_code) {
            ticketQuery += ` AND t.display_code LIKE ?`;
            ticketParams.push(`%${ticket_code}%`);
        }

        if (customer_name) {
            ticketQuery += ` AND t.temp_customer_name LIKE ?`;
            ticketParams.push(`%${customer_name}%`);
        }

        if (date) {
            ticketQuery += ` AND DATE(t.created_at) = ?`;
            ticketParams.push(date);
        }

        if (establishmentId) {
            ticketQuery += ` AND t.establishment_id = ?`;
            ticketParams.push(establishmentId);
        }

        ticketQuery += ` ORDER BY t.created_at DESC LIMIT 20`;

        db.all(ticketQuery, ticketParams, (err, tickets) => {
            if (err) return queries.handleDbError(res, err);

            if (tickets.length === 0) {
                return res.json({ tickets: [], message: 'Nenhum ticket encontrado' });
            }

            // For each ticket, get the timeline
            const ticketIds = tickets.map(t => t.id);
            const placeholders = ticketIds.map(() => '?').join(',');

            const timelineQuery = `
                SELECT 
                    tsl.id, tsl.ticket_id, tsl.status, tsl.changed_at, tsl.notes,
                    u.name as user_name,
                    r.name as room_name,
                    rd.name as desk_name
                FROM ticket_status_logs tsl
                LEFT JOIN users u ON tsl.user_id = u.id
                LEFT JOIN rooms r ON tsl.room_id = r.id
                LEFT JOIN reception_desks rd ON tsl.desk_id = rd.id
                WHERE tsl.ticket_id IN (${placeholders})
                ORDER BY tsl.ticket_id, tsl.changed_at ASC
            `;

            db.all(timelineQuery, ticketIds, (err, logs) => {
                if (err) return queries.handleDbError(res, err);

                // Group logs by ticket_id
                const logsMap = {};
                logs.forEach(log => {
                    if (!logsMap[log.ticket_id]) {
                        logsMap[log.ticket_id] = [];
                    }
                    logsMap[log.ticket_id].push(log);
                });

                // Attach timeline to each ticket
                const result = tickets.map(ticket => ({
                    ...ticket,
                    timeline: logsMap[ticket.id] || []
                }));

                res.json({ tickets: result });
            });
        });
    });

    return router;
};
