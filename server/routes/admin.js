const express = require('express');
const router = express.Router();

// This will be imported in server/index.js and passed the db instance
module.exports = (db) => {

    // ==================== SERVICES ====================

    router.get('/services', (req, res) => {
        db.all("SELECT * FROM services ORDER BY name", [], (err, rows) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(rows);
        });
    });

    router.post('/services', (req, res) => {
        const { name, prefix, average_time_minutes, description } = req.body;
        db.run(
            "INSERT INTO services (name, prefix, average_time_minutes, description) VALUES (?, ?, ?, ?)",
            [name, prefix, average_time_minutes || 15, description || ''],
            function (err) {
                if (err) return res.status(500).json({ error: err.message });
                res.json({ id: this.lastID, name, prefix });
            }
        );
    });

    router.put('/services/:id', (req, res) => {
        const { name, prefix, average_time_minutes, description } = req.body;
        db.run(
            "UPDATE services SET name = ?, prefix = ?, average_time_minutes = ?, description = ? WHERE id = ?",
            [name, prefix, average_time_minutes, description, req.params.id],
            function (err) {
                if (err) return res.status(500).json({ error: err.message });
                res.json({ success: true, changes: this.changes });
            }
        );
    });

    router.delete('/services/:id', (req, res) => {
        const serviceId = req.params.id;

        // Check if service is in use in tickets
        db.get("SELECT count(*) as count FROM ticket_services WHERE service_id = ?", [serviceId], (err, row) => {
            if (err) return res.status(500).json({ error: err.message });
            if (row.count > 0) {
                return res.status(400).json({ error: "Serviço está em uso em senhas e não pode ser excluído" });
            }

            // Delete related records first in proper sequence
            db.run("DELETE FROM room_services WHERE service_id = ?", [serviceId], (err) => {
                if (err) return res.status(500).json({ error: err.message });

                db.run("DELETE FROM service_menus WHERE service_id = ?", [serviceId], (err) => {
                    if (err) return res.status(500).json({ error: err.message });

                    // Finally delete the service itself
                    db.run("DELETE FROM services WHERE id = ?", [serviceId], function (err) {
                        if (err) return res.status(500).json({ error: err.message });
                        res.json({ success: true, message: 'Serviço excluído com sucesso' });
                    });
                });
            });
        });
    });

    // ==================== ROOMS ====================

    router.get('/rooms', (req, res) => {
        db.all("SELECT * FROM rooms ORDER BY name", [], (err, rows) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(rows);
        });
    });

    router.post('/rooms', (req, res) => {
        const { name, type, is_active } = req.body;
        const establishmentId = req.establishmentId || 1; // Fallback for safety, though middleware should handle it

        db.run(
            "INSERT INTO rooms (name, type, is_active, establishment_id) VALUES (?, ?, ?, ?)",
            [name, type || '', is_active !== undefined ? is_active : 1, establishmentId],
            function (err) {
                if (err) return res.status(500).json({ error: err.message });
                res.json({ id: this.lastID, name });
            }
        );
    });

    router.put('/rooms/:id', (req, res) => {
        const { name, type, is_active } = req.body;
        db.run(
            "UPDATE rooms SET name = ?, type = ?, is_active = ? WHERE id = ?",
            [name, type, is_active, req.params.id],
            function (err) {
                if (err) return res.status(500).json({ error: err.message });
                res.json({ success: true, changes: this.changes });
            }
        );
    });

    router.delete('/rooms/:id', (req, res) => {
        const roomId = req.params.id;

        // Delete related room_services first
        db.run("DELETE FROM room_services WHERE room_id = ?", [roomId], (err) => {
            if (err) return res.status(500).json({ error: err.message });

            // Then delete the room
            db.run("DELETE FROM rooms WHERE id = ?", [roomId], function (err) {
                if (err) return res.status(500).json({ error: err.message });
                res.json({ success: true, message: 'Sala excluída com sucesso' });
            });
        });
    });

    // ==================== ROOM SERVICES ====================

    router.get('/room-services/:roomId', (req, res) => {
        const query = `
            SELECT rs.*, s.name as service_name 
            FROM room_services rs 
            JOIN services s ON rs.service_id = s.id 
            WHERE rs.room_id = ?
        `;
        db.all(query, [req.params.roomId], (err, rows) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(rows);
        });
    });

    router.post('/room-services', (req, res) => {
        const { room_id, service_id } = req.body;
        db.run(
            "INSERT INTO room_services (room_id, service_id) VALUES (?, ?)",
            [room_id, service_id],
            function (err) {
                if (err) return res.status(500).json({ error: err.message });
                res.json({ id: this.lastID });
            }
        );
    });

    router.delete('/room-services/:id', (req, res) => {
        db.run("DELETE FROM room_services WHERE id = ?", [req.params.id], function (err) {
            if (err) return res.status(500).json({ error: err.message });
            res.json({ success: true });
        });
    });

    // ==================== MENUS ====================

    router.get('/menus', (req, res) => {
        const query = `
            SELECT sm.*, s.name as service_name 
            FROM service_menus sm 
            LEFT JOIN services s ON sm.service_id = s.id 
            ORDER BY sm.parent_id, sm.order_index
        `;
        db.all(query, [], (err, rows) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(rows);
        });
    });

    router.post('/menus', (req, res) => {
        const { parent_id, label, service_id, order_index, icon } = req.body;
        db.run(
            "INSERT INTO service_menus (parent_id, label, service_id, order_index, icon) VALUES (?, ?, ?, ?, ?)",
            [parent_id || null, label, service_id || null, order_index || 0, icon || ''],
            function (err) {
                if (err) return res.status(500).json({ error: err.message });
                res.json({ id: this.lastID, label });
            }
        );
    });

    router.put('/menus/:id', (req, res) => {
        const { parent_id, label, service_id, order_index, icon } = req.body;
        db.run(
            "UPDATE service_menus SET parent_id = ?, label = ?, service_id = ?, order_index = ?, icon = ? WHERE id = ?",
            [parent_id || null, label, service_id || null, order_index, icon, req.params.id],
            function (err) {
                if (err) return res.status(500).json({ error: err.message });
                res.json({ success: true, changes: this.changes });
            }
        );
    });

    router.delete('/menus/:id', (req, res) => {
        const menuId = req.params.id;

        // Delete children first
        db.run("DELETE FROM service_menus WHERE parent_id = ?", [menuId], (err) => {
            if (err) return res.status(500).json({ error: err.message });

            // Then delete the menu item itself
            db.run("DELETE FROM service_menus WHERE id = ?", [menuId], function (err) {
                if (err) return res.status(500).json({ error: err.message });
                res.json({ success: true, message: 'Item de menu excluído com sucesso' });
            });
        });
    });

    // ==================== ESTABLISHMENTS ====================

    router.get('/establishments', (req, res) => {
        db.all("SELECT * FROM establishments ORDER BY name", [], (err, rows) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(rows);
        });
    });

    // ==================== USERS ====================

    router.get('/users', (req, res) => {
        db.all("SELECT id, name, username, role FROM users ORDER BY name", [], (err, rows) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(rows);
        });
    });

    router.post('/users', (req, res) => {
        const { name, username, password, role } = req.body;
        // In production, hash the password!
        db.run(
            "INSERT INTO users (name, username, password, role) VALUES (?, ?, ?, ?)",
            [name, username, password, role || 'PROFESSIONAL'],
            function (err) {
                if (err) return res.status(500).json({ error: err.message });
                res.json({ id: this.lastID, name, username });
            }
        );
    });

    router.put('/users/:id', (req, res) => {
        const { name, username, password, role } = req.body;
        let query, params;

        if (password) {
            query = "UPDATE users SET name = ?, username = ?, password = ?, role = ? WHERE id = ?";
            params = [name, username, password, role, req.params.id];
        } else {
            query = "UPDATE users SET name = ?, username = ?, role = ? WHERE id = ?";
            params = [name, username, role, req.params.id];
        }

        db.run(query, params, function (err) {
            if (err) return res.status(500).json({ error: err.message });
            res.json({ success: true, changes: this.changes });
        });
    });

    router.delete('/users/:id', (req, res) => {
        db.run("DELETE FROM users WHERE id = ?", [req.params.id], function (err) {
            if (err) return res.status(500).json({ error: err.message });
            res.json({ success: true });
        });
    });

    // ==================== REPORTS ====================

    router.get('/reports/tickets', (req, res) => {
        const { start_date, end_date } = req.query;
        let query = `
            SELECT 
                date(created_at) as date,
                count(*) as total_tickets,
                count(DISTINCT customer_id) as unique_customers
            FROM tickets
        `;

        const params = [];
        if (start_date && end_date) {
            query += " WHERE date(created_at) BETWEEN ? AND ?";
            params.push(start_date, end_date);
        }

        query += " GROUP BY date(created_at) ORDER BY date DESC LIMIT 30";

        db.all(query, params, (err, rows) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(rows);
        });
    });

    router.get('/reports/attendance', (req, res) => {
        const query = `
            SELECT 
                s.name as service_name,
                count(al.id) as total_attendances,
                avg((julianday(al.end_time) - julianday(al.start_time)) * 24 * 60) as avg_duration_minutes
            FROM attendance_logs al
            JOIN ticket_services ts ON al.ticket_service_id = ts.id
            JOIN services s ON ts.service_id = s.id
            WHERE al.end_time IS NOT NULL
            GROUP BY s.id
            ORDER BY total_attendances DESC
        `;

        db.all(query, [], (err, rows) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(rows);
        });
    });

    return router;
};
