const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.resolve(__dirname, 'star-tickets.db');
const db = new sqlite3.Database(dbPath);

db.serialize(() => {
    // Drop existing tables
    db.run("DROP TABLE IF EXISTS attendance_logs");
    db.run("DROP TABLE IF EXISTS ticket_services");
    db.run("DROP TABLE IF EXISTS tickets");
    db.run("DROP TABLE IF EXISTS customers");
    db.run("DROP TABLE IF EXISTS room_services");
    db.run("DROP TABLE IF EXISTS service_menus");
    db.run("DROP TABLE IF EXISTS services");
    db.run("DROP TABLE IF EXISTS rooms");
    db.run("DROP TABLE IF EXISTS users");
    db.run("DROP TABLE IF EXISTS establishments");

    // Create establishments table
    db.run(`
        CREATE TABLE establishments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            code TEXT UNIQUE NOT NULL,
            address TEXT,
            phone TEXT,
            email TEXT,
            is_active INTEGER DEFAULT 1,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    `);

    // Create services table
    db.run(`
        CREATE TABLE services (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            prefix TEXT NOT NULL,
            average_time_minutes INTEGER DEFAULT 15,
            description TEXT,
            establishment_id INTEGER,
            FOREIGN KEY (establishment_id) REFERENCES establishments(id)
        )
    `);

    // Create rooms table
    db.run(`
        CREATE TABLE rooms (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT,
            is_active INTEGER DEFAULT 1,
            establishment_id INTEGER NOT NULL,
            FOREIGN KEY (establishment_id) REFERENCES establishments(id)
        )
    `);

    // Create customers table
    db.run(`
        CREATE TABLE customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT,
            email TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    `);

    // Create tickets table
    db.run(`
        CREATE TABLE tickets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            display_code TEXT NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            status TEXT DEFAULT 'WAITING',
            customer_id INTEGER,
            temp_customer_name TEXT,
            is_priority INTEGER DEFAULT 0,
            establishment_id INTEGER NOT NULL,
            FOREIGN KEY (customer_id) REFERENCES customers(id),
            FOREIGN KEY (establishment_id) REFERENCES establishments(id)
        )
    `);

    // Create ticket_services table
    db.run(`
        CREATE TABLE ticket_services (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ticket_id INTEGER NOT NULL,
            service_id INTEGER NOT NULL,
            order_sequence INTEGER NOT NULL,
            status TEXT DEFAULT 'PENDING',
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (ticket_id) REFERENCES tickets(id),
            FOREIGN KEY (service_id) REFERENCES services(id)
        )
    `);

    // Create users table
    db.run(`
        CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            role TEXT DEFAULT 'professional',
            establishment_id INTEGER,
            FOREIGN KEY (establishment_id) REFERENCES establishments(id)
        )
    `);

    // Create service_menus table
    db.run(`
        CREATE TABLE service_menus (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            label TEXT NOT NULL,
            parent_id INTEGER,
            service_id INTEGER,
            order_index INTEGER DEFAULT 0,
            icon TEXT,
            establishment_id INTEGER,
            FOREIGN KEY (parent_id) REFERENCES service_menus(id),
            FOREIGN KEY (service_id) REFERENCES services(id),
            FOREIGN KEY (establishment_id) REFERENCES establishments(id)
        )
    `);

    // Create room_services table
    db.run(`
        CREATE TABLE room_services (
            room_id INTEGER NOT NULL,
            service_id INTEGER NOT NULL,
            PRIMARY KEY (room_id, service_id),
            FOREIGN KEY (room_id) REFERENCES rooms(id),
            FOREIGN KEY (service_id) REFERENCES services(id)
        )
    `);

    // Create attendance_logs table
    db.run(`
        CREATE TABLE attendance_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            ticket_service_id INTEGER NOT NULL,
            started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            finished_at DATETIME,
            FOREIGN KEY (user_id) REFERENCES users(id),
            FOREIGN KEY (ticket_service_id) REFERENCES ticket_services(id)
        )
    `);

    // Insert sample establishments
    const establishments = [
        { name: 'Clínica Central', code: 'CENTRAL', address: 'Av. Principal, 100', phone: '(11) 1234-5678', email: 'central@clinica.com' },
        { name: 'Clínica Norte', code: 'NORTE', address: 'Rua Norte, 200', phone: '(11) 2345-6789', email: 'norte@clinica.com' },
        { name: 'Clínica Sul', code: 'SUL', address: 'Rua Sul, 300', phone: '(11) 3456-7890', email: 'sul@clinica.com' }
    ];

    const estStmt = db.prepare("INSERT INTO establishments (name, code, address, phone, email) VALUES (?, ?, ?, ?, ?)");
    establishments.forEach(e => estStmt.run(e.name, e.code, e.address, e.phone, e.email));
    estStmt.finalize();

    // Insert sample services for each establishment
    const services = [
        { name: 'Triagem', prefix: 'TRI', time: 10, est: 1 },
        { name: 'Consulta Geral', prefix: 'CON', time: 30, est: 1 },
        { name: 'Exame de Sangue', prefix: 'LAB', time: 20, est: 1 },
        { name: 'Raio-X', prefix: 'RAD', time: 15, est: 1 },
        { name: 'Triagem', prefix: 'TRI', time: 10, est: 2 },
        { name: 'Consulta Geral', prefix: 'CON', time: 30, est: 2 },
        { name: 'Exame de Sangue', prefix: 'LAB', time: 20, est: 2 },
        { name: 'Triagem', prefix: 'TRI', time: 10, est: 3 },
        { name: 'Consulta Geral', prefix: 'CON', time: 30, est: 3 }
    ];

    const svcStmt = db.prepare("INSERT INTO services (name, prefix, average_time_minutes, establishment_id) VALUES (?, ?, ?, ?)");
    services.forEach(s => svcStmt.run(s.name, s.prefix, s.time, s.est));
    svcStmt.finalize();

    // Insert sample rooms for each establishment
    const rooms = [
        { name: 'Sala 1', type: 'Consulta', est: 1 },
        { name: 'Sala 2', type: 'Exames', est: 1 },
        { name: 'Sala 1', type: 'Consulta', est: 2 },
        { name: 'Sala 2', type: 'Exames', est: 2 },
        { name: 'Sala 1', type: 'Consulta', est: 3 }
    ];

    const roomStmt = db.prepare("INSERT INTO rooms (name, type, establishment_id) VALUES (?, ?, ?)");
    rooms.forEach(r => roomStmt.run(r.name, r.type, r.est));
    roomStmt.finalize();

    // Insert sample menus for all establishments
    const menus = [
        // Estabelecimento 1 (Central) - Menu completo
        { label: 'Consultas', parent: null, service: null, order: 1, est: 1 },
        { label: 'Exames', parent: null, service: null, order: 2, est: 1 },
        { label: 'Geral', parent: 1, service: 2, order: 1, est: 1 },
        { label: 'Sangue', parent: 2, service: 3, order: 1, est: 1 },
        { label: 'Raio-X', parent: 2, service: 4, order: 2, est: 1 },

        // Estabelecimento 2 (Norte) - Apenas consultas e exame de sangue
        { label: 'Atendimento', parent: null, service: null, order: 1, est: 2 },
        { label: 'Triagem', parent: 6, service: 5, order: 1, est: 2 },
        { label: 'Consulta', parent: 6, service: 6, order: 2, est: 2 },
        { label: 'Exame de Sangue', parent: null, service: 7, order: 2, est: 2 },

        // Estabelecimento 3 (Sul) - Apenas consultas (sem exames)
        { label: 'Triagem', parent: null, service: 8, order: 1, est: 3 },
        { label: 'Consulta Geral', parent: null, service: 9, order: 2, est: 3 }
    ];

    const menuStmt = db.prepare("INSERT INTO service_menus (label, parent_id, service_id, order_index, establishment_id) VALUES (?, ?, ?, ?, ?)");
    menus.forEach(m => menuStmt.run(m.label, m.parent, m.service, m.order, m.est));
    menuStmt.finalize();

    // Insert room-service mappings
    db.run("INSERT INTO room_services (room_id, service_id) VALUES (1, 2), (2, 3), (2, 4)");

    // Insert sample users
    const users = [
        { name: 'Dr. João', username: 'joao', password: '123', role: 'professional', est: 1 },
        { name: 'Dra. Maria', username: 'maria', password: '123', role: 'professional', est: 2 },
        { name: 'Admin', username: 'admin', password: 'admin', role: 'admin', est: null }
    ];

    const userStmt = db.prepare("INSERT INTO users (name, username, password, role, establishment_id) VALUES (?, ?, ?, ?, ?)");
    users.forEach(u => userStmt.run(u.name, u.username, u.password, u.role, u.est));
    userStmt.finalize(() => {
        console.log('✅ Database recreated with establishments support!');
        console.log('📍 3 establishments created: Central, Norte, Sul');
        console.log('🏥 Services and rooms distributed across establishments');
        db.close();
    });
});
