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

// Middleware to enforce establishment scope in queries
// Admin can optionally specify establishment_id via query param
// Non-admin MUST use their own establishment_id
function requireEstablishmentScope(req, res, next) {
    if (!req.session || !req.session.user) {
        return res.status(401).json({ error: 'Não autenticado' });
    }

    req.user = req.session.user;
    req.isAdmin = req.session.user.role === 'admin';

    if (req.isAdmin) {
        // Admin can optionally filter by establishment_id
        req.establishmentId = req.query.establishment_id ? parseInt(req.query.establishment_id) : null;
    } else {
        // Non-admin MUST use their own establishment_id
        req.establishmentId = req.session.user.establishment_id;
        if (!req.establishmentId) {
            return res.status(403).json({ error: 'Usuário sem estabelecimento associado' });
        }
    }
    next();
}

// Helper function to build establishment filter for SQL queries
function buildEstablishmentFilter(column, establishmentId, isAdmin) {
    if (!establishmentId) {
        return { clause: '', params: [] };
    }
    return {
        clause: ` AND ${column} = ?`,
        params: [establishmentId]
    };
}

// Role-based access control middleware
// Usage: requireRole('admin', 'manager', 'receptionist')
function requireRole(...allowedRoles) {
    return (req, res, next) => {
        if (!req.session || !req.session.user) {
            return res.status(401).json({ error: 'Não autenticado' });
        }

        const userRole = req.session.user.role;

        // Admin always has access
        if (userRole === 'admin') {
            req.user = req.session.user;
            req.establishmentId = req.query.establishment_id ? parseInt(req.query.establishment_id) : null;
            req.isAdmin = true;
            return next();
        }

        if (!allowedRoles.includes(userRole)) {
            return res.status(403).json({ error: 'Acesso negado para este perfil' });
        }

        req.user = req.session.user;
        req.establishmentId = req.session.user.establishment_id;
        req.isAdmin = false;
        next();
    };
}

module.exports = {
    requireAuth,
    optionalAuth,
    requireAdmin,
    requireEstablishmentScope,
    buildEstablishmentFilter,
    requireRole
};
