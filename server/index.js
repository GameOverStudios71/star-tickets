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

// Mount Routes
app.use('/api/auth', authRoutes(db));
app.use('/api/dashboard', dashboardRoutes(db));
app.use('/api', ticketRoutes(db, io)); // Tickets, Call, Finish, Track
app.use('/api', establishmentRoutes(db)); // Config, Rooms, Establishments
app.use('/api', qrcodeRoutes()); // QR Code
app.use('/api/admin', adminRoutes(db));

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
