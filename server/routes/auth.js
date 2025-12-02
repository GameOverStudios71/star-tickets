const express = require('express');
const router = express.Router();

module.exports = (db) => {

    router.post('/login', (req, res) => {
        const { username, password } = req.body;

        db.get("SELECT * FROM users WHERE username = ? AND password = ?", [username, password], (err, user) => {
            if (err) return res.status(500).json({ error: err.message });
            if (!user) return res.status(401).json({ error: 'Credenciais inválidas' });

            req.session.user = {
                id: user.id,
                name: user.name,
                username: user.username,
                role: user.role,
                establishment_id: user.establishment_id
            };

            res.json({
                success: true,
                user: req.session.user
            });
        });
    });

    router.post('/logout', (req, res) => {
        req.session.destroy((err) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json({ success: true });
        });
    });

    router.get('/me', (req, res) => {
        if (req.session && req.session.user) {
            res.json({ user: req.session.user });
        } else {
            res.status(401).json({ error: 'Não autenticado' });
        }
    });

    return router;
};
