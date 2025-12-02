const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const QRCode = require('qrcode');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

const dbPath = path.resolve(__dirname, '../database/star-tickets.db');
const db = new sqlite3.Database(dbPath);

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, '../public')));

// Admin Routes
const adminRoutes = require('./admin-routes');
app.use('/api/admin', adminRoutes(db));


// --- API Routes ---

// 1. Config (Menus & Services)
app.get('/api/config', (req, res) => {
    const query = `
        SELECT sm.*, s.name as service_name, s.prefix, s.average_time_minutes, s.id as service_id
        FROM service_menus sm 
        LEFT JOIN services s ON sm.service_id = s.id 
        ORDER BY sm.order_index
    `;
    db.all(query, [], (err, rows) => {
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

app.get('/api/rooms', (req, res) => {
    db.all("SELECT * FROM rooms WHERE is_active = 1", [], (err, rows) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(rows);
    });
});

// Establishments API
app.get('/api/establishments', (req, res) => {
    db.all("SELECT * FROM establishments WHERE is_active = 1 ORDER BY name", [], (err, rows) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(rows);
    });
});

app.get('/api/establishments/:id', (req, res) => {
    db.get("SELECT * FROM establishments WHERE id = ?", [req.params.id], (err, row) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(row);
    });
});

// Dashboard API - General Stats
app.get('/api/dashboard/stats', (req, res) => {
    const establishmentId = req.query.establishment_id;

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
    const stats = {};

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

// Dashboard API - Active Tickets
app.get('/api/dashboard/tickets', (req, res) => {
    const establishmentId = req.query.establishment_id;

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

// Dashboard API - Tickets by Hour (for charts)
app.get('/api/dashboard/tickets-by-hour', (req, res) => {
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

// 2. Create Ticket (Totem)
app.post('/api/tickets', (req, res) => {
    const { serviceIds, establishmentId = 1 } = req.body; // Array of service IDs + establishment
    if (!serviceIds || serviceIds.length === 0) return res.status(400).json({ error: "No services selected" });

    // Generate Display Code (Simplified logic: Get prefix of first service + sequence)
    // In a real app, we'd have a sequence table per prefix.
    db.get("SELECT prefix FROM services WHERE id = ?", [serviceIds[0]], (err, row) => {
        if (err) return res.status(500).json({ error: err.message });

        const prefix = row ? row.prefix : 'GEN';

        // Get today's count for this prefix to generate number
        db.get("SELECT count(*) as count FROM tickets WHERE display_code LIKE ? AND date(created_at) = date('now')", [`${prefix}%`], (err, countRow) => {
            const number = (countRow.count + 1).toString().padStart(3, '0');
            const displayCode = `${prefix}${number}`;

            db.run("INSERT INTO tickets (display_code, status, establishment_id) VALUES (?, 'WAITING', ?)", [displayCode, establishmentId], function (err) {
                if (err) return res.status(500).json({ error: err.message });
                const ticketId = this.lastID;

                // Insert Ticket Services
                const stmt = db.prepare("INSERT INTO ticket_services (ticket_id, service_id, order_sequence, status) VALUES (?, ?, ?, ?)");
                serviceIds.forEach((serviceId, index) => {
                    // First service is PENDING, others are BLOCKED (conceptually) but we use PENDING + order_sequence logic
                    stmt.run(ticketId, serviceId, index + 1, 'PENDING');
                });
                stmt.finalize();

                io.emit('new_ticket', { ticketId, displayCode });
                res.json({ ticketId, displayCode });
            });
        });
    });
});

// 3. Reception - List Tickets
app.get('/api/tickets', (req, res) => {
    const query = `
        SELECT t.*, c.name as customer_name, 
        (SELECT group_concat(s.name, ', ') FROM ticket_services ts JOIN services s ON ts.service_id = s.id WHERE ts.ticket_id = t.id) as services_list
        FROM tickets t
        LEFT JOIN customers c ON t.customer_id = c.id
        WHERE t.status != 'DONE' AND t.status != 'CANCELED'
        ORDER BY t.created_at DESC
    `;
    db.all(query, [], (err, rows) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(rows);
    });
});

// Get services for a specific ticket (MUST come before /api/tickets/:id/link)
app.get('/api/tickets/:id/services', (req, res) => {
    const query = `
        SELECT ts.id, ts.status, ts.order_sequence, s.name as service_name, s.id as service_id
        FROM ticket_services ts
        JOIN services s ON ts.service_id = s.id
        WHERE ts.ticket_id = ?
        ORDER BY ts.order_sequence
    `;
    db.all(query, [req.params.id], (err, rows) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(rows);
    });
});

// Link Customer to Ticket
app.put('/api/tickets/:id/link', (req, res) => {
    const { customerName } = req.body;
    const ticketId = req.params.id;

    // Simplified: Just updating temp_customer_name or creating a customer record on the fly
    // For prototype, let's just update temp_customer_name on the ticket
    db.run("UPDATE tickets SET temp_customer_name = ? WHERE id = ?", [customerName, ticketId], function (err) {
        if (err) return res.status(500).json({ error: err.message });
        io.emit('ticket_updated', { ticketId, customerName });
        res.json({ success: true });
    });
});

// Remove a service from a ticket
app.delete('/api/tickets/services/:id', (req, res) => {
    const ticketServiceId = req.params.id;

    // Get ticket_id before deleting
    db.get("SELECT ticket_id FROM ticket_services WHERE id = ?", [ticketServiceId], (err, row) => {
        if (err || !row) return res.status(500).json({ error: "Service not found" });

        const ticketId = row.ticket_id;

        db.run("DELETE FROM ticket_services WHERE id = ?", [ticketServiceId], function (err) {
            if (err) return res.status(500).json({ error: err.message });

            // Check if ticket has any remaining services
            db.get("SELECT count(*) as count FROM ticket_services WHERE ticket_id = ?", [ticketId], (err, countRow) => {
                if (countRow.count === 0) {
                    // If no services left, cancel the ticket
                    db.run("UPDATE tickets SET status = 'CANCELED' WHERE id = ?", [ticketId]);
                }
                io.emit('ticket_updated', { ticketId });
                res.json({ success: true });
            });
        });
    });
});

// Add a service to a ticket
app.post('/api/tickets/:id/services', (req, res) => {
    const ticketId = req.params.id;
    const { serviceId } = req.body;

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

// Move a service up or down in the order
app.put('/api/tickets/services/:id/move', (req, res) => {
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
app.get('/api/track/:ticketId', (req, res) => {
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

// Generate QR Code for ticket
app.get('/api/qrcode/:ticketId', async (req, res) => {
    const ticketId = req.params.ticketId;
    const trackingUrl = `${req.protocol}://${req.get('host')}/track.html?ticket=${ticketId}`;

    try {
        const qrCodeDataUrl = await QRCode.toDataURL(trackingUrl, {
            width: 300,
            margin: 2,
            color: {
                dark: '#000000',
                light: '#FFFFFF'
            }
        });
        res.json({ qrCode: qrCodeDataUrl, url: trackingUrl });
    } catch (err) {
        res.status(500).json({ error: 'Erro ao gerar QR Code' });
    }
});


// 4. Professional - Queue & Actions
app.get('/api/queue/:roomId', (req, res) => {
    const roomId = req.params.roomId;

    // Logic: Get tickets where the NEXT pending service is one that this room can perform
    // AND the service order is correct (i.e., previous services are COMPLETED)

    const query = `
        SELECT ts.id as ticket_service_id, t.id as ticket_id, t.display_code, t.temp_customer_name, s.name as service_name
        FROM ticket_services ts
        JOIN tickets t ON ts.ticket_id = t.id
        JOIN services s ON ts.service_id = s.id
        JOIN room_services rs ON rs.service_id = s.id
        WHERE rs.room_id = ?
        AND ts.status = 'PENDING'
        AND t.status != 'CANCELED'
        -- Ensure previous services for this ticket are completed
        AND NOT EXISTS (
            SELECT 1 FROM ticket_services ts_prev 
            WHERE ts_prev.ticket_id = ts.ticket_id 
            AND ts_prev.order_sequence < ts.order_sequence 
            AND ts_prev.status != 'COMPLETED'
        )
        ORDER BY ts.created_at ASC
    `;

    db.all(query, [roomId], (err, rows) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(rows);
    });
});

app.post('/api/call', (req, res) => {
    const { ticketServiceId, roomId } = req.body;

    db.get(`
        SELECT t.display_code, t.temp_customer_name, r.name as room_name 
        FROM ticket_services ts
        JOIN tickets t ON ts.ticket_id = t.id
        JOIN room_services rs ON rs.service_id = ts.service_id
        JOIN rooms r ON rs.room_id = r.id
        WHERE ts.id = ? AND r.id = ?
    `, [ticketServiceId, roomId], (err, row) => {
        if (err || !row) return res.status(500).json({ error: "Error fetching ticket info" });

        // Update status to CALLED or IN_PROGRESS
        db.run("UPDATE ticket_services SET status = 'CALLED' WHERE id = ?", [ticketServiceId], (err) => {
            if (err) return res.status(500).json({ error: err.message });

            // Emit to TV
            io.emit('call_ticket', {
                displayCode: row.display_code,
                customerName: row.temp_customer_name,
                roomName: row.room_name
            });

            res.json({ success: true });
        });
    });
});

app.post('/api/finish', (req, res) => {
    const { ticketServiceId } = req.body;

    db.run("UPDATE ticket_services SET status = 'COMPLETED' WHERE id = ?", [ticketServiceId], function (err) {
        if (err) return res.status(500).json({ error: err.message });

        // Check if there are more services for this ticket
        db.get("SELECT ticket_id FROM ticket_services WHERE id = ?", [ticketServiceId], (err, row) => {
            const ticketId = row.ticket_id;

            db.get("SELECT count(*) as count FROM ticket_services WHERE ticket_id = ? AND status = 'PENDING'", [ticketId], (err, countRow) => {
                if (countRow.count === 0) {
                    db.run("UPDATE tickets SET status = 'DONE' WHERE id = ?", [ticketId]);
                }
                res.json({ success: true });
            });
        });
    });
});


const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
