// Add these routes to server/index.js after the app.post('/api/finish') route (around line 437)

// Mark ticket as NO_SHOW
app.put('/api/tickets/:id/no-show', (req, res) => {
    const ticketId = req.params.id;

    db.run("UPDATE tickets SET status = 'NO_SHOW' WHERE id = ?", [ticketId], function (err) {
        if (err) return res.status(500).json({ error: err.message });
        io.emit('ticket_updated', { ticketId });
        res.json({ success: true });
    });
});

// Reactivate ticket (back to WAITING)
app.put('/api/tickets/:id/reactivate', (req, res) => {
    const ticketId = req.params.id;

    db.run("UPDATE tickets SET status = 'WAITING' WHERE id = ?", [ticketId], function (err) {
        if (err) return res.status(500).json({ error: err.message });
        io.emit('ticket_updated', { ticketId });
        res.json({ success: true });
    });
});
