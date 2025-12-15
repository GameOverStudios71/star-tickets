const express = require('express');
const router = express.Router();
const queries = require('../database/queries');

module.exports = (db) => {

    // ==================== SERVICES ====================

    router.get('/services', (req, res) => {
        const { query, params } = queries.serviceQueries.list(req.establishmentId);
        db.all(query, params, (err, rows) => {
            if (err) return queries.handleDbError(res, err);
            res.json(rows);
        });
    });

    router.post('/services', (req, res) => {
        const { name, prefix, average_time_minutes, description } = req.body;
        const establishmentId = req.establishmentId; // Associate with user's establishment

        db.run(
            "INSERT INTO services (name, prefix, average_time_minutes, description, establishment_id) VALUES (?, ?, ?, ?, ?)",
            [name, prefix, average_time_minutes || 15, description || '', establishmentId],
            function (err) {
                if (err) return res.status(500).json({ error: err.message });
                res.json({ id: this.lastID, name, prefix });
            }
        );
    });

    router.put('/services/:id', (req, res) => {
        const { name, prefix, average_time_minutes, description } = req.body;
        const establishmentId = req.establishmentId;
        const serviceId = req.params.id;

        // Verify ownership: service must belong to user's establishment or be global (admin can edit global)
        let whereClause = "id = ?";
        const params = [name, prefix, average_time_minutes, description, serviceId];

        if (establishmentId && !req.isAdmin) {
            whereClause += " AND (establishment_id = ? OR establishment_id IS NULL)";
            params.push(establishmentId);
        }

        db.run(
            `UPDATE services SET name = ?, prefix = ?, average_time_minutes = ?, description = ? WHERE ${whereClause}`,
            params,
            function (err) {
                if (err) return res.status(500).json({ error: err.message });
                if (this.changes === 0) {
                    return res.status(403).json({ error: 'Serviço não encontrado ou sem permissão' });
                }
                res.json({ success: true, changes: this.changes });
            }
        );
    });

    router.delete('/services/:id', (req, res) => {
        const serviceId = req.params.id;
        const establishmentId = req.establishmentId;

        // Security check: ensure service belongs to establishment
        let checkQuery = "SELECT id FROM services WHERE id = ?";
        const checkParams = [serviceId];

        if (establishmentId && !req.isAdmin) {
            checkQuery += " AND (establishment_id = ? OR establishment_id IS NULL)";
            checkParams.push(establishmentId);
        }

        db.get(checkQuery, checkParams, (err, row) => {
            if (err) return res.status(500).json({ error: err.message });
            if (!row) return res.status(403).json({ error: 'Serviço não encontrado ou sem permissão' });

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
    });

    // ==================== ROOMS ====================

    router.get('/rooms', (req, res) => {
        const { query, params } = queries.roomQueries.list(req.establishmentId);
        db.all(query, params, (err, rows) => {
            if (err) return queries.handleDbError(res, err);
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
        const establishmentId = req.establishmentId;
        const roomId = req.params.id;

        // Verify ownership
        let whereClause = "id = ?";
        const params = [name, type, is_active, roomId];

        if (establishmentId) {
            whereClause += " AND establishment_id = ?";
            params.push(establishmentId);
        }

        db.run(
            `UPDATE rooms SET name = ?, type = ?, is_active = ? WHERE ${whereClause}`,
            params,
            function (err) {
                if (err) return res.status(500).json({ error: err.message });
                if (this.changes === 0) {
                    return res.status(403).json({ error: 'Sala não encontrada ou sem permissão' });
                }
                res.json({ success: true, changes: this.changes });
            }
        );
    });

    router.delete('/rooms/:id', (req, res) => {
        const roomId = req.params.id;
        const establishmentId = req.establishmentId;

        // Verify ownership first
        let verifyQuery = "SELECT id FROM rooms WHERE id = ?";
        const verifyParams = [roomId];

        if (establishmentId) {
            verifyQuery += " AND establishment_id = ?";
            verifyParams.push(establishmentId);
        }

        db.get(verifyQuery, verifyParams, (err, room) => {
            if (err) return res.status(500).json({ error: err.message });
            if (!room) {
                return res.status(403).json({ error: 'Sala não encontrada ou sem permissão' });
            }

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
        const establishmentId = req.establishmentId;
        const isAdmin = req.isAdmin;

        // Security: Verify if room belongs to user's establishment
        let checkRoomQuery = "SELECT id FROM rooms WHERE id = ?";
        const params = [room_id];

        if (establishmentId && !isAdmin) {
            checkRoomQuery += " AND establishment_id = ?";
            params.push(establishmentId);
        }

        db.get(checkRoomQuery, params, (err, row) => {
            if (err) return res.status(500).json({ error: err.message });
            if (!row) return res.status(403).json({ error: 'Sala inválida ou sem permissão' });

            db.run(
                "INSERT INTO room_services (room_id, service_id) VALUES (?, ?)",
                [room_id, service_id],
                function (err) {
                    if (err) return res.status(500).json({ error: err.message });
                    res.json({ id: this.lastID });
                }
            );
        });
    });

    router.delete('/room-services/:id', (req, res) => {
        const id = req.params.id;
        const establishmentId = req.establishmentId;
        const isAdmin = req.isAdmin;

        // Security: Delete only if the room (linked via room_id) belongs to establishment
        // SQLite DELETE with JOIN/Subquery
        let query = "DELETE FROM room_services WHERE id = ?";
        const params = [id];

        if (establishmentId && !isAdmin) {
            query += ` AND room_id IN (SELECT id FROM rooms WHERE establishment_id = ?)`;
            params.push(establishmentId);
        }

        db.run(query, params, function (err) {
            if (err) return res.status(500).json({ error: err.message });
            if (this.changes === 0) {
                return res.status(403).json({ error: 'Item não encontrado ou permissão negada' });
            }
            res.json({ success: true });
        });
    });

    // ==================== MENUS ====================

    router.get('/menus', (req, res) => {
        const establishmentId = req.establishmentId;

        let query = `
            SELECT sm.*, s.name as service_name 
            FROM service_menus sm 
            LEFT JOIN services s ON sm.service_id = s.id 
            WHERE 1=1
        `;
        const params = [];

        if (establishmentId) {
            query += " AND (sm.establishment_id = ? OR sm.establishment_id IS NULL)";
            params.push(establishmentId);
        }
        query += " ORDER BY sm.parent_id, sm.order_index";

        db.all(query, params, (err, rows) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(rows);
        });
    });

    router.post('/menus', (req, res) => {
        const { parent_id, label, service_id, order_index, icon } = req.body;
        const establishmentId = req.establishmentId;

        db.run(
            "INSERT INTO service_menus (parent_id, label, service_id, order_index, icon, establishment_id) VALUES (?, ?, ?, ?, ?, ?)",
            [parent_id || null, label, service_id || null, order_index || 0, icon || '', establishmentId],
            function (err) {
                if (err) return res.status(500).json({ error: err.message });
                res.json({ id: this.lastID, label });
            }
        );
    });

    router.put('/menus/:id', (req, res) => {
        const { parent_id, label, service_id, order_index, icon } = req.body;
        const establishmentId = req.establishmentId;
        const isAdmin = req.isAdmin;

        let query = "UPDATE service_menus SET parent_id = ?, label = ?, service_id = ?, order_index = ?, icon = ? WHERE id = ?";
        const params = [parent_id || null, label, service_id || null, order_index, icon, req.params.id];

        if (establishmentId && !isAdmin) {
            query += " AND establishment_id = ?";
            params.push(establishmentId);
        }

        db.run(query, params,
            function (err) {
                if (err) return res.status(500).json({ error: err.message });
                if (this.changes === 0) {
                    return res.status(403).json({ error: 'Menu não encontrado ou permissão negada' });
                }
                res.json({ success: true, changes: this.changes });
            }
        );
    });

    router.delete('/menus/:id', (req, res) => {
        const menuId = req.params.id;
        const establishmentId = req.establishmentId;
        const isAdmin = req.isAdmin;

        // Verify ownership
        let checkQuery = "SELECT id FROM service_menus WHERE id = ?";
        const checkParams = [menuId];

        if (establishmentId && !isAdmin) {
            checkQuery += " AND establishment_id = ?";
            checkParams.push(establishmentId);
        }

        db.get(checkQuery, checkParams, (err, row) => {
            if (err) return res.status(500).json({ error: err.message });
            if (!row) return res.status(403).json({ error: 'Menu não encontrado ou permissão negada' });

            // Delete children first
            // Implicit assumption: We trust the parent check, or we should loop delete safely. 
            // Ideally Cascade delete in DB, but here manual.
            // We can proceed since we verified the parent menu belongs to us.
            db.run("DELETE FROM service_menus WHERE parent_id = ?", [menuId], (err) => {
                if (err) return res.status(500).json({ error: err.message });

                // Then delete the menu item itself
                let deleteQuery = "DELETE FROM service_menus WHERE id = ?";
                const deleteParams = [menuId];

                // Extra safety on delete
                if (establishmentId && !isAdmin) {
                    deleteQuery += " AND establishment_id = ?";
                    deleteParams.push(establishmentId);
                }

                db.run(deleteQuery, deleteParams, function (err) {
                    if (err) return res.status(500).json({ error: err.message });
                    res.json({ success: true, message: 'Item de menu excluído com sucesso' });
                });
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

    // ==================== USERS ====================

    router.get('/users', (req, res) => {
        const establishmentId = req.establishmentId;
        const isAdmin = req.isAdmin;

        let query = "SELECT id, name, username, role, establishment_id FROM users WHERE 1=1";
        const params = [];

        // Non-admin only sees users from their own establishment
        if (establishmentId && !isAdmin) {
            query += " AND establishment_id = ?";
            params.push(establishmentId);
        }
        // Admin sees all users, or can filter by establishment_id query param
        else if (establishmentId && isAdmin) {
            query += " AND establishment_id = ?";
            params.push(establishmentId);
        }
        query += " ORDER BY name";

        db.all(query, params, (err, rows) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(rows);
        });
    });

    router.post('/users', (req, res) => {
        const { name, username, password, role } = req.body;
        const establishmentId = req.establishmentId;

        // Validation: Manager cannot create Admin
        if (!req.isAdmin && role === 'admin') {
            return res.status(403).json({ error: 'Gerentes não podem criar Administradores' });
        }

        // In production, hash the password!
        db.run(
            "INSERT INTO users (name, username, password, role, establishment_id) VALUES (?, ?, ?, ?, ?)",
            [name, username, password, role || 'PROFESSIONAL', establishmentId],
            function (err) {
                if (err) return res.status(500).json({ error: err.message });
                res.json({ id: this.lastID, name, username });
            }
        );
    });

    router.put('/users/:id', (req, res) => {
        const { name, username, password, role } = req.body;
        const userId = req.params.id;
        const establishmentId = req.establishmentId;
        const isAdmin = req.isAdmin;

        // Security: Non-admin can only update users from their own establishment
        let whereClause = "id = ?";
        const params = [name, username];

        // Passowrd update logic
        let querySet = "SET name = ?, username = ?";

        if (password) {
            querySet += ", password = ?";
            params.push(password);
        }

        if (role) {
            // Manager cannot promote to Admin
            if (!isAdmin && role === 'admin') {
                return res.status(403).json({ error: 'Nao é permitido atribuir perfil de Administrador' });
            }
            querySet += ", role = ?";
            params.push(role);
        }

        params.push(userId);

        if (!isAdmin) {
            whereClause += " AND establishment_id = ?";
            params.push(establishmentId);
        }

        const fullQuery = `UPDATE users ${querySet} WHERE ${whereClause}`;

        db.run(fullQuery, params, function (err) {
            if (err) return res.status(500).json({ error: err.message });
            if (this.changes === 0) {
                return res.status(403).json({ error: 'Usuário não encontrado ou permissão negada' });
            }
            res.json({ success: true, changes: this.changes });
        });
    });

    router.delete('/users/:id', (req, res) => {
        const userId = req.params.id;
        const establishmentId = req.establishmentId;
        const isAdmin = req.isAdmin;

        let query = "DELETE FROM users WHERE id = ?";
        const params = [userId];

        if (!isAdmin) {
            query += " AND establishment_id = ?";
            params.push(establishmentId);
        }

        db.run(query, params, function (err) {
            if (err) return res.status(500).json({ error: err.message });
            if (this.changes === 0) {
                return res.status(403).json({ error: 'Usuário não encontrado ou permissão negada' });
            }
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
                avg((julianday(al.finished_at) - julianday(al.started_at)) * 24 * 60) as avg_duration_minutes
            FROM attendance_logs al
            JOIN ticket_services ts ON al.ticket_service_id = ts.id
            JOIN services s ON ts.service_id = s.id
            WHERE al.finished_at IS NOT NULL
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
