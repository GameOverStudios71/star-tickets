// Authentication middleware
function requireAuth(req, res, next) {
    if (!req.session || !req.session.user) {
        return res.status(401).json({
            error: 'Não autenticado',
            redirectTo: '/login.html'
        });
    }

    // Inject user data into request
    req.user = req.session.user;
    req.establishmentId = req.session.user.establishment_id;
    req.isAdmin = req.session.user.role === 'admin';

    next();
}

// Optional auth - doesn't block if not authenticated
function optionalAuth(req, res, next) {
    if (req.session && req.session.user) {
        req.user = req.session.user;
        req.establishmentId = req.session.user.establishment_id;
        req.isAdmin = req.session.user.role === 'admin';
    }
    next();
}

// Admin-only middleware
function requireAdmin(req, res, next) {
    if (!req.session || !req.session.user) {
        return res.status(401).json({ error: 'Não autenticado' });
    }

    if (req.session.user.role !== 'admin') {
        return res.status(403).json({ error: 'Acesso negado - Admin apenas' });
    }

    req.user = req.session.user;
    req.isAdmin = true;

    next();
}

module.exports = {
    requireAuth,
    optionalAuth,
    requireAdmin
};
