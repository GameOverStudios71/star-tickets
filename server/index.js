const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const session = require('express-session');
const fs = require('fs');
const { execSync } = require('child_process');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

// Track active desks: deskId -> { socketId, userName, userId }
const activeDesks = new Map();

io.on('connection', (socket) => {
    // Send current active desks to new client
    socket.emit('active_desks_update', Array.from(activeDesks.entries()));

    socket.on('join_desk', (data) => {
        const { deskId, userName, userId } = data;
        const currentOccupant = activeDesks.get(parseInt(deskId));

        // Check if occupied by someone else
        if (currentOccupant && currentOccupant.socketId !== socket.id) {
            socket.emit('desk_join_error', {
                message: `Esta mesa já está sendo usada por ${currentOccupant.userName}`
            });
            return;
        }

        // Occupy desk
        // First, leave any previously occupied desk by this socket
        for (const [dId, occupant] of activeDesks.entries()) {
            if (occupant.socketId === socket.id) {
                activeDesks.delete(dId);
            }
        }

        activeDesks.set(parseInt(deskId), { socketId: socket.id, userName, userId });
        io.emit('active_desks_update', Array.from(activeDesks.entries()));
        socket.emit('desk_join_success', { deskId });

        console.log(`Desk ${deskId} occupied by ${userName}`);
    });

    socket.on('leave_desk', () => {
        for (const [dId, occupant] of activeDesks.entries()) {
            if (occupant.socketId === socket.id) {
                activeDesks.delete(dId);
                io.emit('active_desks_update', Array.from(activeDesks.entries()));
                console.log(`Desk ${dId} left by ${occupant.userName}`);
            }
        }
    });

    socket.on('disconnect', () => {
        for (const [dId, occupant] of activeDesks.entries()) {
            if (occupant.socketId === socket.id) {
                activeDesks.delete(dId);
                io.emit('active_desks_update', Array.from(activeDesks.entries()));
                console.log(`Desk ${dId} freed (disconnect)`);
            }
        }
    });
});

const dbPath = path.resolve(__dirname, '../database/star-tickets.db');

// Check if database exists, if not, initialize it
if (!fs.existsSync(dbPath)) {
    console.log('⚠️  Database not found. Initializing...');
    try {
        const initPath = path.resolve(__dirname, '../database/init.js');
        execSync(`node ${initPath}`, { stdio: 'inherit' });
        console.log('✅ Database initialized successfully!');
    } catch (error) {
        console.error('❌ Error initializing database:', error);
        process.exit(1);
    }
}

const db = new sqlite3.Database(dbPath);

app.use(cors());
app.use(express.json());

// Livereload for development (auto-refresh browser on file changes)
if (process.env.NODE_ENV !== 'production') {
    try {
        const livereload = require('livereload');
        const connectLivereload = require('connect-livereload');

        const liveReloadServer = livereload.createServer({
            exts: ['html', 'css', 'js', 'png', 'jpg', 'gif'],
            delay: 100
        });
        liveReloadServer.watch(path.join(__dirname, '../public'));

        app.use(connectLivereload());
        console.log('🔥 LiveReload enabled - browser will auto-refresh on file changes');
    } catch (e) {
        // Livereload not installed, skip
    }
}

app.use(express.static(path.join(__dirname, '../public')));

// Session configuration
app.use(session({
    secret: 'star-tickets-secret-key',
    resave: false,
    saveUninitialized: false,
    cookie: { maxAge: 24 * 60 * 60 * 1000 } // 24 hours
}));

// Middleware to inject establishment_id from session
app.use((req, res, next) => {
    if (req.session && req.session.user) {
        req.establishmentId = req.session.user.establishment_id;
        req.user = req.session.user;
    }
    next();
});

// --- Modular Routes ---
const authRoutes = require('./routes/auth');
const dashboardRoutes = require('./routes/dashboard');
const ticketRoutes = require('./routes/tickets');
const establishmentRoutes = require('./routes/establishments');
const qrcodeRoutes = require('./routes/qrcode');
const adminRoutes = require('./routes/admin');

const { requireAuth, requireEstablishmentScope } = require('./middleware/auth');

// Mount Routes
// Public routes (no auth required)
app.use('/api/auth', authRoutes(db));
app.use('/api', qrcodeRoutes()); // QR Code generation is public

// Semi-public routes (totem/tv need these without login)
// Establishments routes include /config, /rooms, /establishments - all public for totem
app.use('/api', establishmentRoutes(db));

// Protected routes (require authentication and establishment scope)
app.use('/api/dashboard', requireEstablishmentScope, dashboardRoutes(db));
app.use('/api/admin', requireEstablishmentScope, adminRoutes(db));

// Ticket routes - some need auth, some are public (totem creates tickets)
app.use('/api', ticketRoutes(db, io)); // Will handle auth internally per-route

// WebSocket handlers
io.on('connection', (socket) => {
    // Handle TV sound preset change
    socket.on('change_tv_sound', (data) => {
        // Broadcast to all connected clients (TVs)
        io.emit('tv_sound_changed', data);
    });

    // Handle TV TTS toggle
    socket.on('change_tv_tts', (data) => {
        // Broadcast to all connected clients (TVs)
        io.emit('tv_tts_changed', data);
    });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
