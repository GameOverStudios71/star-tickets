const express = require('express');
const router = express.Router();
const { requireAuth, requireEstablishmentScope, optionalAuth } = require('../middleware/auth');
const queries = require('../database/queries');

module.exports = (db, io) => {

    // Helper function to log status changes for timeline tracking
    const logStatusChange = (ticketId, status, options = {}) => {
        const { userId = null, roomId = null, deskId = null, notes = null } = options;
        db.run(
            `INSERT INTO ticket_status_logs (ticket_id, status, user_id, room_id, desk_id, notes) VALUES (?, ?, ?, ?, ?, ?)`,
            [ticketId, status, userId, roomId, deskId, notes],
            (err) => {
                if (err) {
                    const logger = require('../utils/logger');
                    logger.error('Error logging status change:', err);
                }
            }
        );
    };

    // 2. Create Ticket (Totem) - PUBLIC route, establishment comes from body
    router.post('/tickets', (req, res) => {
        const { serviceIds, establishmentId = 1, isPriority = false, healthInsuranceName = null } = req.body;

        // Debug Log
        const logger = require('../utils/logger');
        logger.info(`Creating ticket for Services: [${serviceIds}], Priority: ${isPriority}`);

        if (!serviceIds || serviceIds.length === 0) return res.status(400).json({ error: "No services selected" });

        db.serialize(() => {
            db.get("SELECT prefix FROM services WHERE id = ?", [serviceIds[0]], (err, row) => {
                if (err) {
                    logger.error("Error fetching service prefix", err);
                    return res.status(500).json({ error: err.message });
                }

                const prefix = row ? row.prefix : 'GEN';

                // Get today's count for this prefix to generate number
                db.get("SELECT count(*) as count FROM tickets WHERE display_code LIKE ? AND date(created_at, 'localtime') = date('now', 'localtime')", [`${prefix}%`], (err, countRow) => {
                    if (err) {
                        logger.error("Error generating ticket number", err);
                        return res.status(500).json({ error: err.message });
                    }

                    const number = (countRow.count + 1).toString().padStart(3, '0');
                    const displayCode = `${prefix}${number}`;

                    db.run("INSERT INTO tickets (display_code, status, is_priority, health_insurance_name, establishment_id) VALUES (?, 'WAITING_RECEPTION', ?, ?, ?)",
                        [displayCode, isPriority ? 1 : 0, healthInsuranceName, establishmentId],
                        function (err) {
                            if (err) {
                                logger.error("Error inserting ticket", err);
                                return res.status(500).json({ error: err.message });
                            }
                            const ticketId = this.lastID;

                            // Insert Ticket Services
                            const stmt = db.prepare("INSERT INTO ticket_services (ticket_id, service_id, order_sequence, status) VALUES (?, ?, ?, ?)");
                            serviceIds.forEach((serviceId, index) => {
                                // First service is PENDING, others are BLOCKED (conceptually) but we use PENDING + order_sequence logic
                                stmt.run(ticketId, serviceId, index + 1, 'PENDING');
                            });
                            stmt.finalize((err) => {
                                if (err) {
                                    logger.error("Error finalizing ticket services", err);
                                    // We don't rollback here (sqlite limitations in this simple flow), but we log it.
                                }

                                // Log initial status
                                logStatusChange(ticketId, 'WAITING_RECEPTION', { notes: 'Senha gerada no totem' });

                                logger.info(`Ticket created: ${displayCode} (ID: ${ticketId})`);
                                io.emit('new_ticket', { ticketId, displayCode, isPriority, healthInsuranceName });
                                res.json({ ticketId, displayCode, isPriority, healthInsuranceName });
                            });
                        }
                    );
                });
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
            AND t.temp_customer_name != ''
            AND date(t.created_at) = date('now')
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

        if (!deskId) return res.status(400).json({ error: "Desk ID is required" });

        const getDeskName = (callback) => {
            db.get("SELECT name FROM reception_desks WHERE id = ?", [deskId], (err, desk) => {
                callback(null, desk?.name || 'RECEPÇÃO');
            });
        };

        // 1. [SECURITY CHECK] Verify if this desk already has an active ticket
        // Statuses that imply the desk is busy: CALLED_RECEPTION (calling), IN_RECEPTION (attending)
        const checkDeskBusyQuery = `
            SELECT id, display_code, temp_customer_name, status 
            FROM tickets 
            WHERE reception_desk_id = ? 
            AND status IN ('CALLED_RECEPTION', 'IN_RECEPTION')
            ${req.establishmentId ? 'AND establishment_id = ?' : ''}
        `;
        const checkParams = req.establishmentId ? [deskId, req.establishmentId] : [deskId];

        db.get(checkDeskBusyQuery, checkParams, (err, busyRow) => {
            if (err) return queries.handleDbError(res, err);

            if (busyRow) {
                // Determine user friendly message
                const action = busyRow.status === 'CALLED_RECEPTION' ? 'chamando' : 'atendendo';
                return res.status(409).json({
                    error: 'desk_busy',
                    message: `Você já está ${action} a senha ${busyRow.display_code}. Finalize-a antes de chamar outra.`
                });
            }

            // 2. Fetch ticket to be called
            const ticketQuery = `
                SELECT t.id, t.display_code, t.temp_customer_name, t.status, t.reception_desk_id,
                       rd.name as current_desk_name
                FROM tickets t
                LEFT JOIN reception_desks rd ON t.reception_desk_id = rd.id
                WHERE t.id = ? ${req.establishmentId ? 'AND t.establishment_id = ?' : ''}
            `;
            const ticketParams = req.establishmentId ? [ticketId, req.establishmentId] : [ticketId];

            db.get(ticketQuery, ticketParams, (err, row) => {
                if (err || !row) return queries.handleNotFound(res);

                // 3. [SECURITY CHECK] Verify if ticket is already being attended by SOMEONE ELSE
                if (row.status !== 'WAITING_RECEPTION') {
                    return res.status(409).json({
                        error: 'already_in_progress',
                        message: `Esta senha já está sendo atendida${row.current_desk_name ? ' pela ' + row.current_desk_name : ''}`,
                        attendingDesk: row.current_desk_name
                    });
                }

                getDeskName((err, deskName) => {
                    const updateQuery = "UPDATE tickets SET status = 'CALLED_RECEPTION', reception_desk_id = ? WHERE id = ? AND status = 'WAITING_RECEPTION'";
                    const updateParams = [deskId, ticketId];

                    db.run(updateQuery, updateParams, function (err) {
                        if (err) return queries.handleDbError(res, err);

                        // Optimistic lock check
                        if (this.changes === 0) {
                            return res.status(409).json({
                                error: 'already_in_progress',
                                message: 'Esta senha acabou de ser atendida por outra recepcionista'
                            });
                        }

                        // Log status change
                        logStatusChange(ticketId, 'CALLED_RECEPTION', { deskId, notes: `Chamado na ${deskName}` });

                        io.emit('call_ticket', {
                            ticketId,
                            displayCode: row.display_code,
                            customerName: row.temp_customer_name || 'Cliente',
                            roomName: deskName
                        });
                        io.emit('ticket_updated'); // Update lists
                        res.json({ success: true });
                    });
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

                // Log status change
                logStatusChange(ticketId, 'IN_RECEPTION', { deskId: row.reception_desk_id, notes: 'Atendimento iniciado na recepção' });

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

            // Log status change
            logStatusChange(ticketId, 'WAITING_PROFESSIONAL', { notes: 'Atendimento na recepção finalizado, aguardando profissional' });

            io.emit('ticket_updated', { ticketId });
            res.json({ success: true, message: 'Cliente liberado para filas de serviço' });
        });
    });

    // Get all tickets that have been CALLED (for TV rotation) - PROTECTED
    router.get('/called-tickets', requireEstablishmentScope, (req, res) => {
        // Use establishment from session, not query param (security)
        const { query, params } = queries.calledTicketQueries.list(req.establishmentId);
        db.all(query, params, (err, rows) => {
            if (err) return queries.handleDbError(res, err);
            res.json(rows || []);
        });
    });

    // Professional - Call a ticket service - PROTECTED
    router.post('/call', requireEstablishmentScope, (req, res) => {
        const { ticketServiceId, roomId } = req.body;
        const { query, params } = queries.ticketServiceQueries.getCallInfo(ticketServiceId, roomId, req.establishmentId);

        // 1. [SECURITY CHECK] Verify if room already has an active patient
        // We check if there is any ticket_service for this room that is CALLED or IN_PROGRESS
        const checkRoomBusyQuery = `
            SELECT ts.id, t.display_code, ts.status
            FROM ticket_services ts
            JOIN tickets t ON ts.ticket_id = t.id
            WHERE ts.room_id = ?
            AND ts.status IN('CALLED', 'IN_PROGRESS')
            AND date(ts.updated_at, 'localtime') = date('now', 'localtime')-- Optimization: only check today's tickets
            ${req.establishmentId ? 'AND t.establishment_id = ?' : ''}
        `;
        const checkParams = req.establishmentId ? [roomId, req.establishmentId] : [roomId];

        db.get(checkRoomBusyQuery, checkParams, (err, busyRow) => {
            if (err) return queries.handleDbError(res, err);

            if (busyRow) {
                // If it's the SAME ticket service, we allow re-calling (idempotency/re-announce)
                if (busyRow.id != ticketServiceId) {
                    const action = busyRow.status === 'CALLED' ? 'chamando' : 'atendendo';
                    return res.status(409).json({
                        error: 'room_busy',
                        message: `Sua sala já está ${action} a senha ${busyRow.display_code}. Finalize o atendimento atual.`
                    });
                }
            }

            db.get(query, params, (err, row) => {
                if (err || !row) return queries.handleNotFound(res);

                const logger = require('../utils/logger');
                logger.info(`[Call Service] Calling ticket ${row.display_code} (Service ID: ${ticketServiceId}).Previous Status: ${row.status} `);

                db.run("UPDATE ticket_services SET status = 'CALLED', room_id = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?", [roomId, ticketServiceId], (err) => {
                    if (err) {
                        logger.error(`[Call Service] DB Error updating status to CALLED`, err);
                        return queries.handleDbError(res, err);
                    }

                    // Log status change (using ticket_id from row)
                    logStatusChange(row.ticket_id, 'CALLED', { roomId, notes: `Chamado para ${row.room_name}` });

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
    });

    // Uncall a ticket - resets CALLED status back to PENDING - PROTECTED
    router.post('/uncall', requireEstablishmentScope, (req, res) => {
        const { ticketServiceId } = req.body;
        const logger = require('../utils/logger');

        if (!ticketServiceId) {
            return res.status(400).json({ error: 'ticketServiceId is required' });
        }

        // Verify ownership and that ticket is in CALLED status
        const verifyQuery = `
            SELECT ts.id, ts.status, t.display_code
            FROM ticket_services ts
            JOIN tickets t ON ts.ticket_id = t.id
            WHERE ts.id = ?
            ${req.establishmentId ? 'AND t.establishment_id = ?' : ''}
        `;
        const verifyParams = req.establishmentId ? [ticketServiceId, req.establishmentId] : [ticketServiceId];

        db.get(verifyQuery, verifyParams, (err, row) => {
            if (err) return queries.handleDbError(res, err);
            if (!row) return res.status(404).json({ error: 'Ticket service not found' });

            // Only allow uncalling if status is CALLED (not IN_PROGRESS)
            if (row.status !== 'CALLED') {
                return res.status(400).json({
                    error: 'invalid_status',
                    message: `Só é possível cancelar chamada de tickets com status CALLED. Status atual: ${row.status}`
                });
            }

            logger.info(`[Uncall] Uncalling ticket ${row.display_code} (Service ID: ${ticketServiceId})`);

            // Reset to PENDING and clear room_id
            db.run(
                "UPDATE ticket_services SET status = 'PENDING', room_id = NULL, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
                [ticketServiceId],
                function (err) {
                    if (err) return queries.handleDbError(res, err);

                    io.emit('ticket_updated', { ticketServiceId });
                    res.json({ success: true, message: 'Chamada cancelada' });
                }
            );
        });
    });

    // Start service - marks ticket as IN_PROGRESS - PROTECTED
    router.post('/start-service', requireEstablishmentScope, (req, res) => {
        const { ticketServiceId } = req.body;
        const logger = require('../utils/logger'); // Import logger

        const { query, params } = queries.ticketServiceQueries.verifyOwnership(ticketServiceId, req.establishmentId);

        db.get(query, params, (err, row) => {
            if (err || !row) return queries.handleNotFound(res);

            logger.info(`[Start Service] Attempting to start.Current Status: ${row.status}, ID: ${ticketServiceId} `);

            // [SECURITY CHECK] Strict status transition
            if (row.status !== 'CALLED') {
                logger.warn(`[Start Service]Failed.Expected CALLED, got ${row.status} `);
                return res.status(400).json({ error: "O paciente precisa ser chamado antes de iniciar o atendimento." });
            }

            db.run("UPDATE ticket_services SET status = 'IN_PROGRESS', updated_at = CURRENT_TIMESTAMP WHERE id = ?", [ticketServiceId], function (err) {
                if (err) return queries.handleDbError(res, err);

                // Log status change
                logStatusChange(row.ticket_id, 'IN_PROGRESS', { roomId: row.room_id, notes: 'Atendimento iniciado pelo profissional' });

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

            // [SECURITY CHECK] Strict status transition
            if (row.status !== 'IN_PROGRESS') {
                return res.status(400).json({ error: "O atendimento precisa ser iniciado antes de finalizar." });
            }

            const ticketId = row.ticket_id;
            db.run("UPDATE ticket_services SET status = 'COMPLETED', updated_at = CURRENT_TIMESTAMP WHERE id = ?", [ticketServiceId], function (err) {
                if (err) return queries.handleDbError(res, err);

                // Log status change
                logStatusChange(ticketId, 'SERVICE_COMPLETED', { roomId: row.room_id, notes: 'Serviço concluído' });

                db.get("SELECT count(*) as count FROM ticket_services WHERE ticket_id = ? AND status = 'PENDING'", [ticketId], (err, countRow) => {
                    if (countRow.count === 0) {
                        db.run("UPDATE tickets SET status = 'DONE' WHERE id = ?", [ticketId]);
                        // Log final DONE status
                        logStatusChange(ticketId, 'DONE', { notes: 'Todos os serviços concluídos' });
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
            AND NOT EXISTS(
            SELECT 1 FROM ticket_services ts_prev 
                WHERE ts_prev.ticket_id = ts.ticket_id 
                AND ts_prev.order_sequence < ts.order_sequence 
                AND ts_prev.status != 'COMPLETED'
        )
        `;
        const params = [roomId];

        if (establishmentId) {
            query += ` AND t.establishment_id = ? `;
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
            verifyQuery += ` AND t.establishment_id = ? `;
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
            AND NOT EXISTS(
            SELECT 1 FROM ticket_services ts_prev 
                WHERE ts_prev.ticket_id = t.id 
                AND ts_prev.status = 'PENDING'
                AND ts_prev.order_sequence < ts_current.order_sequence
        )
            AND ts_target.id != ts_current.id
        `;
        const params = [targetRoomId];

        if (establishmentId) {
            query += ` AND t.establishment_id = ? `;
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

    // Get active ticket for a room (CALLED or IN_PROGRESS) - PROTECTED
    router.get('/active-ticket/:roomId', requireEstablishmentScope, (req, res) => {
        const { roomId } = req.params;

        // Find any ticket for this room that is active
        const query = `
            SELECT ts.*, s.name as service_name, s.prefix, t.display_code, t.temp_customer_name
            FROM ticket_services ts
            JOIN services s ON ts.service_id = s.id
            JOIN tickets t ON ts.ticket_id = t.id
            WHERE ts.room_id = ? 
            AND ts.status IN ('CALLED', 'IN_PROGRESS')
            AND t.establishment_id = ?
            ORDER BY ts.updated_at DESC
            LIMIT 1
        `;

        db.get(query, [roomId, req.establishmentId], (err, row) => {
            if (err) return queries.handleDbError(res, err);
            if (!row) return res.status(404).json({ message: "No active ticket" });

            res.json(row);
        });
    });

    return router;
};
