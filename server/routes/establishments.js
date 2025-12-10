const express = require('express');
const router = express.Router();

module.exports = (db) => {

    // 1. Config (Menus & Services)
    router.get('/config', (req, res) => {
        const establishmentId = req.query.establishment_id || 1; // Default to establishment 1

        const query = `
            SELECT sm.*, s.name as service_name, s.prefix, s.average_time_minutes, s.id as service_id
            FROM service_menus sm 
            LEFT JOIN services s ON sm.service_id = s.id 
            WHERE sm.establishment_id = ?
            ORDER BY sm.order_index
        `;
        db.all(query, [establishmentId], (err, rows) => {
            if (err) return res.status(500).json({ error: err.message });

            // Get wait time estimates for each service
            const waitTimeQuery = `
                SELECT 
                    ts.service_id,
                    COUNT(*) as pending_count,
                    s.average_time_minutes
                FROM ticket_services ts
                JOIN services s ON ts.service_id = s.id
                WHERE ts.status = 'PENDING'
                AND date(ts.created_at, 'localtime') = date('now', 'localtime')
                GROUP BY ts.service_id
            `;

            db.all(waitTimeQuery, [], (err, waitTimes) => {
                const waitTimeMap = {};
                (waitTimes || []).forEach(wt => {
                    // Estimate: pending count * average time per service
                    waitTimeMap[wt.service_id] = Math.ceil(wt.pending_count * wt.average_time_minutes);
                });

                // Transform flat list into tree
                const menuMap = {};
                const rootMenus = [];

                rows.forEach(row => {
                    const estimatedWait = row.service_id ? (waitTimeMap[row.service_id] || row.average_time_minutes || 0) : 0;
                    menuMap[row.id] = {
                        ...row,
                        children: [],
                        estimated_wait_minutes: estimatedWait
                    };
                });

                rows.forEach(row => {
                    if (row.parent_id) {
                        if (menuMap[row.parent_id]) {
                            menuMap[row.parent_id].children.push(menuMap[row.id]);
                        }
                    } else {
                        rootMenus.push(menuMap[row.id]);
                    }
                });

                res.json(rootMenus);
            });
        });
    });

    router.get('/rooms', (req, res) => {
        const establishmentId = req.establishmentId || req.query.establishment_id;

        let query = "SELECT * FROM rooms WHERE is_active = 1";
        const params = [];

        if (establishmentId) {
            query += " AND establishment_id = ?";
            params.push(establishmentId);
        }

        query += " ORDER BY name";

        db.all(query, params, (err, rows) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(rows);
        });
    });

    // Get services for a specific room
    router.get('/rooms/:id/services', (req, res) => {
        const roomId = req.params.id;
        const query = `
            SELECT DISTINCT s.id, s.name, s.prefix, s.average_time_minutes
            FROM services s
            JOIN room_services rs ON s.id = rs.service_id
            WHERE rs.room_id = ?
            ORDER BY s.name
        `;
        db.all(query, [roomId], (err, rows) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(rows || []);
        });
    });

    // Establishments API
    router.get('/establishments', (req, res) => {
        db.all("SELECT * FROM establishments WHERE is_active = 1 ORDER BY name", [], (err, rows) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(rows);
        });
    });

    router.get('/establishments/:id', (req, res) => {
        db.get("SELECT * FROM establishments WHERE id = ?", [req.params.id], (err, row) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(row);
        });
    });

    return router;
};
