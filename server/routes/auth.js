const express = require('express');
const router = express.Router();

module.exports = (db) => {

    router.post('/login', (req, res) => {
        const { username, password } = req.body;

        if (!username || !password) {
            return res.status(400).json({ error: 'Username e password são obrigatórios' });
        }

        db.get("SELECT * FROM users WHERE username = ? AND password = ?", [username, password], (err, user) => {
            if (err) return res.status(500).json({ error: err.message });
            if (!user) return res.status(401).json({ error: 'Credenciais inválidas' });

            // Get establishment name if user has one
            if (user.establishment_id) {
                db.get("SELECT name FROM establishments WHERE id = ?", [user.establishment_id], (err, est) => {
                    req.session.user = {
                        id: user.id,
                        name: user.name,
                        username: user.username,
                        role: user.role,
                        establishment_id: user.establishment_id,
                        establishment_name: est ? est.name : null
                    };

                    res.json({
                        success: true,
                        user: req.session.user
                    });
                });
            } else {
                // Admin user without establishment
                req.session.user = {
                    id: user.id,
                    name: user.name,
                    username: user.username,
                    role: user.role,
                    establishment_id: null,
                    establishment_name: null
                };

                res.json({
                    success: true,
                    user: req.session.user
                });
            }
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
            res.json({
                authenticated: true,
                user: req.session.user
            });
        } else {
            res.status(401).json({
                authenticated: false,
                error: 'Não autenticado'
            });
        }
    });

    router.get('/check', (req, res) => {
        res.json({
            authenticated: !!(req.session && req.session.user)
        });
    });

    return router;
};
