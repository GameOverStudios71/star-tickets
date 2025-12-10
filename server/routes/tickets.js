const express = require('express');
const router = express.Router();
const { requireAuth, requireEstablishmentScope, optionalAuth } = require('../middleware/auth');
const queries = require('../database/queries');

module.exports = (db, io) => {

    // 2. Create Ticket (Totem) - PUBLIC route, establishment comes from body
    router.post('/tickets', (req, res) => {
        const { serviceIds, establishmentId = 1, isPriority = false, healthInsuranceName = null } = req.body;
        if (!serviceIds || serviceIds.length === 0) return res.status(400).json({ error: "No services selected" });

        // Generate Display Code (Simplified logic: Get prefix of first service + sequence)
        db.get("SELECT prefix FROM services WHERE id = ?", [serviceIds[0]], (err, row) => {
            if (err) return res.status(500).json({ error: err.message });

            const prefix = row ? row.prefix : 'GEN';

            // Get today's count for this prefix to generate number
            db.get("SELECT count(*) as count FROM tickets WHERE display_code LIKE ? AND date(created_at, 'localtime') = date('now', 'localtime')", [`${prefix}%`], (err, countRow) => {
                const number = (countRow.count + 1).toString().padStart(3, '0');
                const displayCode = `${prefix}${number}`;

                db.run("INSERT INTO tickets (display_code, status, is_priority, health_insurance_name, establishment_id) VALUES (?, 'WAITING_RECEPTION', ?, ?, ?)",
                    [displayCode, isPriority ? 1 : 0, healthInsuranceName, establishmentId],
                    function (err) {
                        if (err) return res.status(500).json({ error: err.message });
                        const ticketId = this.lastID;

                        // Insert Ticket Services
                        const stmt = db.prepare("INSERT INTO ticket_services (ticket_id, service_id, order_sequence, status) VALUES (?, ?, ?, ?)");
                        serviceIds.forEach((serviceId, index) => {
                            // First service is PENDING, others are BLOCKED (conceptually) but we use PENDING + order_sequence logic
                            stmt.run(ticketId, serviceId, index + 1, 'PENDING');
                        });
                        stmt.finalize();

                        io.emit('new_ticket', { ticketId, displayCode, isPriority, healthInsuranceName });
                        res.json({ ticketId, displayCode, isPriority, healthInsuranceName });
                    }
                );
            });
        });
    });

    // 3. Reception - List Tickets (only today's tickets) - PROTECTED route
    router.get('/tickets', requireEstablishmentScope, (req, res) => {
        const { query, params } = queries.ticketQueries.listTodayTickets(req.establishmentId);
        db.all(query, params, (err, rows) => {
            if (err) return queries.handleDbError(res, err);
            res.json(rows);
        });
    });

    // Get services for a specific ticket
    router.get('/tickets/:id/services', (req, res) => {
        const { query, params } = queries.ticketServiceQueries.getByTicket(req.params.id);
        db.all(query, params, (err, rows) => {
            if (err) return queries.handleDbError(res, err);
            res.json(rows);
        });
    });

    // Link Customer to Ticket - PROTECTED
    router.put('/tickets/:id/link', requireEstablishmentScope, (req, res) => {
        const { customerName } = req.body;
        const ticketId = req.params.id;
        const { query, params } = queries.ticketQueries.updateTicket(ticketId, 'temp_customer_name', customerName, req.establishmentId);

        db.run(query, params, function (err) {
            if (err) return queries.handleDbError(res, err);
            if (this.changes === 0) return queries.handleNotFound(res);
            io.emit('ticket_updated', { ticketId, customerName });
            res.json({ success: true });
        });
    });

    // Update health insurance name for a ticket - PROTECTED
    router.put('/tickets/:id/insurance', requireEstablishmentScope, (req, res) => {
        const { healthInsuranceName } = req.body;
        const ticketId = req.params.id;
        const { query, params } = queries.ticketQueries.updateTicket(ticketId, 'health_insurance_name', healthInsuranceName, req.establishmentId);

        db.run(query, params, function (err) {
            if (err) return queries.handleDbError(res, err);
            if (this.changes === 0) return queries.handleNotFound(res);
            io.emit('ticket_updated', { ticketId, healthInsuranceName });
            res.json({ success: true });
        });
    });

    // Update ticket status - PROTECTED
    router.put('/tickets/:id/status', requireEstablishmentScope, (req, res) => {
        const { status } = req.body;
        const ticketId = req.params.id;
        const establishmentId = req.establishmentId;

        // Validate status
        const validStatuses = ['WAITING_RECEPTION', 'CALLED_RECEPTION', 'IN_RECEPTION', 'WAITING_PROFESSIONAL', 'DONE', 'CANCELED'];
        if (!validStatuses.includes(status)) {
            return res.status(400).json({ error: 'Status inválido' });
        }

        let query = "UPDATE tickets SET status = ? WHERE id = ?";
        const params = [status, ticketId];

        if (establishmentId) {
            query = "UPDATE tickets SET status = ? WHERE id = ? AND establishment_id = ?";
            params.push(establishmentId);
        }

        db.run(query, params, function (err) {
            if (err) return res.status(500).json({ error: err.message });
            if (this.changes === 0) {
                return res.status(403).json({ error: 'Ticket não encontrado ou sem permissão' });
            }
            io.emit('ticket_updated', { ticketId, status });
            res.json({ success: true, message: 'Status atualizado com sucesso' });
        });
    });

    // Remove a service from a ticket - PROTECTED
    router.delete('/tickets/services/:id', requireEstablishmentScope, (req, res) => {
        const ticketServiceId = req.params.id;
        const establishmentId = req.establishmentId;

        // Get ticket_id and verify ownership before deleting
        let query = `
            SELECT ts.ticket_id 
            FROM ticket_services ts 
            JOIN tickets t ON ts.ticket_id = t.id 
            WHERE ts.id = ?
        `;
        const params = [ticketServiceId];

        if (establishmentId) {
            query += ` AND t.establishment_id = ?`;
            params.push(establishmentId);
        }

        db.get(query, params, (err, row) => {
            if (err || !row) return res.status(403).json({ error: "Serviço não encontrado ou sem permissão" });

            const ticketId = row.ticket_id;

            db.run("DELETE FROM ticket_services WHERE id = ?", [ticketServiceId], function (err) {
                if (err) return res.status(500).json({ error: err.message });

                io.emit('ticket_updated', { ticketId });
                res.json({ success: true });
            });
        });
    });

    // Add a service to a ticket - PROTECTED
    router.post('/tickets/:id/services', requireEstablishmentScope, (req, res) => {
        const ticketId = req.params.id;
        const { serviceId } = req.body;
        const establishmentId = req.establishmentId;

        // Verify ticket ownership first
        let verifyQuery = "SELECT id FROM tickets WHERE id = ?";
        const verifyParams = [ticketId];

        if (establishmentId) {
            verifyQuery += " AND establishment_id = ?";
            verifyParams.push(establishmentId);
        }

        db.get(verifyQuery, verifyParams, (err, ticket) => {
            if (err || !ticket) {
                return res.status(403).json({ error: 'Ticket não encontrado ou sem permissão' });
            }

            // Get the max order_sequence for this ticket
            db.get("SELECT MAX(order_sequence) as max_seq FROM ticket_services WHERE ticket_id = ?", [ticketId], (err, row) => {
                const nextSequence = (row.max_seq || 0) + 1;

                db.run(
                    "INSERT INTO ticket_services (ticket_id, service_id, order_sequence, status) VALUES (?, ?, ?, 'PENDING')",
                    [ticketId, serviceId, nextSequence],
                    function (err) {
                        if (err) return res.status(500).json({ error: err.message });
                        io.emit('ticket_updated', { ticketId });
                        res.json({ id: this.lastID, success: true });
                    }
                );
            });
        });
    });

    // Move a service up or down in the order
    router.put('/tickets/services/:id/move', (req, res) => {
        const ticketServiceId = req.params.id;
        const { direction } = req.body; // 'up' or 'down'

        // Get current service info
        db.get("SELECT * FROM ticket_services WHERE id = ?", [ticketServiceId], (err, currentService) => {
            if (err || !currentService) return res.status(500).json({ error: "Service not found" });

            const currentSeq = currentService.order_sequence;
            const ticketId = currentService.ticket_id;
            const targetSeq = direction === 'up' ? currentSeq - 1 : currentSeq + 1;

            // Find the service to swap with
            db.get(
                "SELECT * FROM ticket_services WHERE ticket_id = ? AND order_sequence = ?",
                [ticketId, targetSeq],
                (err, targetService) => {
                    if (err || !targetService) return res.status(500).json({ error: "Cannot move in that direction" });

                    // Swap the order_sequence values
                    db.run("UPDATE ticket_services SET order_sequence = ? WHERE id = ?", [targetSeq, ticketServiceId]);
                    db.run("UPDATE ticket_services SET order_sequence = ? WHERE id = ?", [currentSeq, targetService.id], function (err) {
                        if (err) return res.status(500).json({ error: err.message });
                        io.emit('ticket_updated', { ticketId });
                        res.json({ success: true });
                    });
                }
            );
        });
    });

    // Client Tracking API
    router.get('/track/:ticketId', (req, res) => {
        const ticketId = req.params.ticketId;

        // Get ticket info
        const ticketQuery = `
            SELECT t.*, 
            (SELECT group_concat(s.name, ', ') FROM ticket_services ts JOIN services s ON ts.service_id = s.id WHERE ts.ticket_id = t.id) as services_list
            FROM tickets t
            WHERE t.id = ?
        `;

        db.get(ticketQuery, [ticketId], (err, ticket) => {
            if (err || !ticket) {
                return res.status(404).json({ error: 'Senha não encontrada' });
            }

            // Get services details
            const servicesQuery = `
                SELECT ts.*, s.name as serviceName, s.average_time_minutes
                FROM ticket_services ts
                JOIN services s ON ts.service_id = s.id
                WHERE ts.ticket_id = ?
                ORDER BY ts.order_sequence
            `;

            db.all(servicesQuery, [ticketId], (err, services) => {
                // Calculate queue position if waiting
                let queuePosition = null;
                let estimatedWaitMinutes = 0;

                if (ticket.status === 'WAITING') {
                    // Count tickets ahead in queue (created before this one and still waiting)
                    db.get(
                        `SELECT COUNT(*) as position FROM tickets 
                         WHERE created_at < ? AND status = 'WAITING'`,
                        [ticket.created_at],
                        (err, row) => {
                            queuePosition = (row?.position || 0) + 1;

                            // Estimate wait time based on pending services ahead
                            db.get(
                                `SELECT SUM(s.average_time_minutes) as total_time
                                 FROM ticket_services ts
                                 JOIN services s ON ts.service_id = s.id
                                 JOIN tickets t ON ts.ticket_id = t.id
                                 WHERE t.created_at < ? AND t.status = 'WAITING' AND ts.status = 'PENDING'`,
                                [ticket.created_at],
                                (err, timeRow) => {
                                    estimatedWaitMinutes = Math.ceil(timeRow?.total_time || 0);

                                    res.json({
                                        id: ticket.id,
                                        displayCode: ticket.display_code,
                                        status: ticket.status,
                                        customerName: ticket.temp_customer_name,
                                        queuePosition,
                                        estimatedWaitMinutes,
                                        services: services || []
                                    });
                                }
                            );
                        }
                    );
                } else {
                    res.json({
                        id: ticket.id,
                        displayCode: ticket.display_code,
                        status: ticket.status,
                        customerName: ticket.temp_customer_name,
                        queuePosition,
                        estimatedWaitMinutes,
                        services: services || []
                    });
                }
            });
        });
    });

    // 4. Professional - Queue & Actions
    router.get('/queue/:roomId', (req, res) => {
        const roomId = req.params.roomId;

        const query = `
            SELECT ts.id as ticket_service_id, t.id as ticket_id, t.display_code, t.temp_customer_name, t.is_priority, s.name as service_name
            FROM ticket_services ts
            JOIN tickets t ON ts.ticket_id = t.id
            JOIN services s ON ts.service_id = s.id
            JOIN room_services rs ON rs.service_id = s.id
            WHERE rs.room_id = ?
            AND ts.status = 'PENDING'
            AND t.status = 'WAITING_PROFESSIONAL'
            AND t.temp_customer_name IS NOT NULL
            AND t.temp_customer_name != ''
            AND date(t.created_at, 'localtime') = date('now', 'localtime')
            -- Ensure previous services for this ticket are completed
            AND NOT EXISTS (
                SELECT 1 FROM ticket_services ts_prev 
                WHERE ts_prev.ticket_id = ts.ticket_id 
                AND ts_prev.order_sequence < ts.order_sequence 
                AND ts_prev.status != 'COMPLETED'
            )
            ORDER BY t.is_priority DESC, ts.created_at ASC
        `;

        db.all(query, [roomId], (err, rows) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(rows);
        });
    });

    // 5. Professional - History (Completed tickets for this room today)
    router.get('/queue/:roomId/history', (req, res) => {
        const roomId = req.params.roomId;

        const query = `
            SELECT ts.id as ticket_service_id, t.id as ticket_id, t.display_code, t.temp_customer_name, t.is_priority, s.name as service_name, ts.updated_at as finished_at
            FROM ticket_services ts
            JOIN tickets t ON ts.ticket_id = t.id
            JOIN services s ON ts.service_id = s.id
            JOIN room_services rs ON rs.service_id = s.id
            WHERE rs.room_id = ?
            AND ts.status = 'COMPLETED'
            AND date(ts.updated_at, 'localtime') = date('now', 'localtime')
            ORDER BY ts.updated_at DESC
            LIMIT 50
        `;

        db.all(query, [roomId], (err, rows) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(rows);
        });
    });

    // Get reception desks for an establishment - uses session when authenticated
    router.get('/reception-desks', optionalAuth, (req, res) => {
        const establishmentId = req.establishmentId || req.query.establishment_id;
        const { query, params } = queries.receptionDeskQueries.listActive(establishmentId);

        db.all(query, params, (err, rows) => {
            if (err) return queries.handleDbError(res, err);
            res.json(rows || []);
        });
    });

    // Reception - Call ticket to reception desk - PROTECTED
    router.post('/reception/call', requireEstablishmentScope, (req, res) => {
        const { ticketId, deskId } = req.body;

        const getDeskName = (callback) => {
            if (!deskId) return callback(null, 'RECEPÇÃO');
            db.get("SELECT name FROM reception_desks WHERE id = ?", [deskId], (err, desk) => {
                callback(null, desk?.name || 'RECEPÇÃO');
            });
        };

        const { query, params } = queries.ticketQueries.getTicketWithStatus(ticketId, req.establishmentId);
        db.get(query, params, (err, row) => {
            if (err || !row) return queries.handleNotFound(res);
            if (row.status !== 'WAITING_RECEPTION') return res.status(400).json({ error: "Ticket já foi chamado" });

            getDeskName((err, deskName) => {
                const updateQuery = deskId
                    ? "UPDATE tickets SET status = 'CALLED_RECEPTION', reception_desk_id = ? WHERE id = ?"
                    : "UPDATE tickets SET status = 'CALLED_RECEPTION' WHERE id = ?";
                const updateParams = deskId ? [deskId, ticketId] : [ticketId];

                db.run(updateQuery, updateParams, (err) => {
                    if (err) return queries.handleDbError(res, err);
                    io.emit('call_ticket', {
                        ticketId,
                        displayCode: row.display_code,
                        customerName: row.temp_customer_name || 'Cliente',
                        roomName: deskName
                    });
                    res.json({ success: true });
                });
            });
        });
    });

    // Reception - Start attendance - PROTECTED
    router.post('/reception/announce', requireEstablishmentScope, (req, res) => {
        const { ticketId } = req.body;
        const { query, params } = queries.ticketQueries.getTicketWithStatus(ticketId, req.establishmentId);

        db.get(query, params, (err, row) => {
            if (err || !row) return queries.handleNotFound(res);
            if (row.status !== 'CALLED_RECEPTION') return res.status(400).json({ error: "Ticket precisa ser chamado primeiro" });

            db.run("UPDATE tickets SET status = 'IN_RECEPTION' WHERE id = ?", [ticketId], (err) => {
                if (err) return queries.handleDbError(res, err);
                io.emit('ticket_updated', { ticketId });
                res.json({ success: true });
            });
        });
    });

    // Reception - Finish and release to service queues - PROTECTED
    router.post('/reception/finish', requireEstablishmentScope, (req, res) => {
        const { ticketId } = req.body;
        const { query, params } = queries.ticketQueries.updateTicket(ticketId, 'status', 'WAITING_PROFESSIONAL', req.establishmentId);

        db.run(query, params, function (err) {
            if (err) return queries.handleDbError(res, err);
            if (this.changes === 0) return queries.handleNotFound(res);
            io.emit('ticket_updated', { ticketId });
            res.json({ success: true, message: 'Cliente liberado para filas de serviço' });
        });
    });

    // Get all tickets that have been CALLED (for TV rotation)
    router.get('/called-tickets', (req, res) => {
        const { query, params } = queries.calledTicketQueries.list(req.query.establishment_id);
        db.all(query, params, (err, rows) => {
            if (err) return queries.handleDbError(res, err);
            res.json(rows || []);
        });
    });

    // Professional - Call a ticket service - PROTECTED
    router.post('/call', requireEstablishmentScope, (req, res) => {
        const { ticketServiceId, roomId } = req.body;
        const { query, params } = queries.ticketServiceQueries.getCallInfo(ticketServiceId, roomId, req.establishmentId);

        db.get(query, params, (err, row) => {
            if (err || !row) return queries.handleNotFound(res);

            db.run("UPDATE ticket_services SET status = 'CALLED' WHERE id = ?", [ticketServiceId], (err) => {
                if (err) return queries.handleDbError(res, err);
                io.emit('call_ticket', {
                    displayCode: row.display_code,
                    customerName: row.temp_customer_name,
                    roomName: row.room_name,
                    establishmentId: row.establishment_id
                });
                res.json({ success: true });
            });
        });
    });

    // Start service - marks ticket as IN_PROGRESS - PROTECTED
    router.post('/start-service', requireEstablishmentScope, (req, res) => {
        const { ticketServiceId } = req.body;
        const { query, params } = queries.ticketServiceQueries.verifyOwnership(ticketServiceId, req.establishmentId);

        db.get(query, params, (err, row) => {
            if (err || !row) return queries.handleNotFound(res);

            db.run("UPDATE ticket_services SET status = 'IN_PROGRESS', updated_at = CURRENT_TIMESTAMP WHERE id = ?", [ticketServiceId], function (err) {
                if (err) return queries.handleDbError(res, err);
                io.emit('ticket_updated', { ticketServiceId });
                res.json({ success: true });
            });
        });
    });

    // Finish service - marks as COMPLETED - PROTECTED
    router.post('/finish', requireEstablishmentScope, (req, res) => {
        const { ticketServiceId } = req.body;
        const { query, params } = queries.ticketServiceQueries.verifyOwnership(ticketServiceId, req.establishmentId);

        db.get(query, params, (err, row) => {
            if (err || !row) return queries.handleNotFound(res);

            const ticketId = row.ticket_id;
            db.run("UPDATE ticket_services SET status = 'COMPLETED', updated_at = CURRENT_TIMESTAMP WHERE id = ?", [ticketServiceId], function (err) {
                if (err) return queries.handleDbError(res, err);

                db.get("SELECT count(*) as count FROM ticket_services WHERE ticket_id = ? AND status = 'PENDING'", [ticketId], (err, countRow) => {
                    if (countRow.count === 0) {
                        db.run("UPDATE tickets SET status = 'DONE' WHERE id = ?", [ticketId]);
                    }
                    res.json({ success: true });
                });
            });
        });
    });

    // 6. Manager API

    // Overview of all rooms - PROTECTED
    router.get('/manager/overview', requireEstablishmentScope, (req, res) => {
        const { query, params } = queries.roomQueries.getOverview(req.establishmentId);
        db.all(query, params, (err, rows) => {
            if (err) return queries.handleDbError(res, err);
            res.json(rows);
        });
    });

    // Detailed queue for a specific room (Manager View) - PROTECTED
    router.get('/manager/room/:roomId/queue', requireEstablishmentScope, (req, res) => {
        const roomId = req.params.roomId;
        const establishmentId = req.establishmentId;

        let query = `
            SELECT ts.id as ticket_service_id, t.id as ticket_id, t.display_code, t.temp_customer_name, s.name as service_name,
            (SELECT COUNT(*) FROM ticket_services ts2 WHERE ts2.ticket_id = t.id AND ts2.status = 'PENDING' AND ts2.id != ts.id) as other_services_count
            FROM ticket_services ts
            JOIN tickets t ON ts.ticket_id = t.id
            JOIN services s ON ts.service_id = s.id
            JOIN room_services rs ON rs.service_id = s.id
            WHERE rs.room_id = ?
            AND ts.status = 'PENDING'
            AND t.status = 'WAITING_PROFESSIONAL'
            AND date(t.created_at, 'localtime') = date('now', 'localtime')
            AND NOT EXISTS (
                SELECT 1 FROM ticket_services ts_prev 
                WHERE ts_prev.ticket_id = ts.ticket_id 
                AND ts_prev.order_sequence < ts.order_sequence 
                AND ts_prev.status != 'COMPLETED'
            )
        `;
        const params = [roomId];

        if (establishmentId) {
            query += ` AND t.establishment_id = ?`;
            params.push(establishmentId);
        }
        query += ` ORDER BY t.is_priority DESC, ts.created_at ASC`;

        db.all(query, params, (err, rows) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(rows);
        });
    });

    // Prioritize a specific service - PROTECTED
    router.put('/tickets/services/:id/prioritize', requireEstablishmentScope, (req, res) => {
        const ticketServiceId = req.params.id;
        const establishmentId = req.establishmentId;

        // Verify ownership
        let verifyQuery = `
            SELECT ts.ticket_id, ts.order_sequence 
            FROM ticket_services ts
            JOIN tickets t ON ts.ticket_id = t.id
            WHERE ts.id = ?
        `;
        const verifyParams = [ticketServiceId];

        if (establishmentId) {
            verifyQuery += ` AND t.establishment_id = ?`;
            verifyParams.push(establishmentId);
        }

        db.get(verifyQuery, verifyParams, (err, targetService) => {
            if (err || !targetService) return res.status(403).json({ error: "Serviço não encontrado ou sem permissão" });

            const ticketId = targetService.ticket_id;

            db.get(`
                SELECT id, order_sequence FROM ticket_services 
                WHERE ticket_id = ? AND status = 'PENDING' 
                ORDER BY order_sequence ASC LIMIT 1
            `, [ticketId], (err, firstService) => {
                if (err) return res.status(500).json({ error: err.message });
                if (!firstService) return res.status(400).json({ error: "No pending services found" });

                if (firstService.id === parseInt(ticketServiceId)) {
                    return res.json({ success: true, message: "Already at top" });
                }

                const seq1 = firstService.order_sequence;
                const seq2 = targetService.order_sequence;

                db.run("UPDATE ticket_services SET order_sequence = ? WHERE id = ?", [seq2, firstService.id]);
                db.run("UPDATE ticket_services SET order_sequence = ? WHERE id = ?", [seq1, ticketServiceId], (err) => {
                    if (err) return res.status(500).json({ error: err.message });
                    io.emit('ticket_updated', { ticketId });
                    res.json({ success: true });
                });
            });
        });
    });

    // Get candidates for a target room - PROTECTED
    router.get('/manager/candidates/:targetRoomId', requireEstablishmentScope, (req, res) => {
        const targetRoomId = req.params.targetRoomId;
        const establishmentId = req.establishmentId;

        let query = `
            SELECT 
                t.id as ticket_id, 
                t.display_code, 
                t.temp_customer_name,
                ts_target.id as target_service_id,
                current_s.name as current_service_name,
                current_r.name as current_room_name
            FROM tickets t
            JOIN ticket_services ts_target ON t.id = ts_target.ticket_id
            JOIN services s_target ON ts_target.service_id = s_target.id
            JOIN room_services rs_target ON rs_target.service_id = s_target.id
            JOIN ticket_services ts_current ON t.id = ts_current.ticket_id
            JOIN services current_s ON ts_current.service_id = current_s.id
            LEFT JOIN room_services current_rs ON current_rs.service_id = current_s.id
            LEFT JOIN rooms current_r ON current_rs.room_id = current_r.id
            WHERE rs_target.room_id = ?
            AND ts_target.status = 'PENDING'
            AND t.status = 'WAITING_PROFESSIONAL'
            AND date(t.created_at, 'localtime') = date('now', 'localtime')
            AND t.temp_customer_name IS NOT NULL
            AND t.temp_customer_name != ''
            AND ts_current.status = 'PENDING'
            AND NOT EXISTS (
                SELECT 1 FROM ticket_services ts_prev 
                WHERE ts_prev.ticket_id = t.id 
                AND ts_prev.status = 'PENDING'
                AND ts_prev.order_sequence < ts_current.order_sequence
            )
            AND ts_target.id != ts_current.id
        `;
        const params = [targetRoomId];

        if (establishmentId) {
            query += ` AND t.establishment_id = ?`;
            params.push(establishmentId);
        }
        query += ` ORDER BY t.is_priority DESC, t.created_at ASC`;

        db.all(query, params, (err, rows) => {
            if (err) return res.status(500).json({ error: err.message });

            // For each ticket, fetch all pending services
            const ticketsWithServices = rows.map(ticket => {
                return new Promise((resolve) => {
                    const servicesQuery = `
                        SELECT s.name, ts.order_sequence
                        FROM ticket_services ts
                        JOIN services s ON ts.service_id = s.id
                        WHERE ts.ticket_id = ? AND ts.status = 'PENDING'
                        ORDER BY ts.order_sequence
                    `;
                    db.all(servicesQuery, [ticket.ticket_id], (err, services) => {
                        resolve({
                            ...ticket,
                            pending_services: services || []
                        });
                    });
                });
            });

            Promise.all(ticketsWithServices).then(results => {
                res.json(results);
            });
        });
    });

    // Bulk Prioritize - PROTECTED
    router.post('/manager/bulk-prioritize', requireEstablishmentScope, (req, res) => {
        const { ticketIds, targetRoomId } = req.body;

        if (!ticketIds || !Array.isArray(ticketIds) || ticketIds.length === 0) {
            return res.status(400).json({ error: "Invalid ticket IDs" });
        }

        // We process them sequentially to avoid race conditions on DB locks, though parallel is likely fine for small scale.
        // Using a promise chain or simple loop.

        const processTicket = (ticketId) => {
            return new Promise((resolve, reject) => {
                // 1. Find the target service for this ticket and room
                db.get(`
                    SELECT ts.id, ts.order_sequence 
                    FROM ticket_services ts
                    JOIN services s ON ts.service_id = s.id
                    JOIN room_services rs ON rs.service_id = s.id
                    WHERE ts.ticket_id = ? AND rs.room_id = ? AND ts.status = 'PENDING'
            `, [ticketId, targetRoomId], (err, targetService) => {
                    if (err) return reject(err);
                    if (!targetService) return resolve(); // Skip if not found (shouldn't happen if list is fresh)

                    // 2. Find current first service
                    db.get(`
                        SELECT id, order_sequence FROM ticket_services 
                        WHERE ticket_id = ? AND status = 'PENDING' 
                        ORDER BY order_sequence ASC LIMIT 1
            `, [ticketId], (err, firstService) => {
                        if (err) return reject(err);
                        if (!firstService || firstService.id === targetService.id) return resolve(); // Already first or none

                        // 3. Swap
                        const seq1 = firstService.order_sequence;
                        const seq2 = targetService.order_sequence;

                        db.serialize(() => {
                            db.run("UPDATE ticket_services SET order_sequence = ? WHERE id = ?", [seq2, firstService.id]);
                            db.run("UPDATE ticket_services SET order_sequence = ? WHERE id = ?", [seq1, targetService.id], (err) => {
                                if (err) return reject(err);
                                io.emit('ticket_updated', { ticketId });
                                resolve();
                            });
                        });
                    });
                });
            });
        };

        Promise.all(ticketIds.map(processTicket))
            .then(() => res.json({ success: true }))
            .catch(err => res.status(500).json({ error: err.message }));
    });

    return router;
};
