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
            status TEXT DEFAULT 'WAITING_RECEPTION',
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
        { name: 'Freguesia', code: 'FREGUESIA', address: 'Rua X', phone: '(11) 0000-0000', email: 'clinica@gmail.com' },
        { name: 'Santana', code: 'SANTANA', address: 'Rua X', phone: '(11) 0000-0000', email: 'clinica@gmail.com' },
        { name: 'Guarulhos Centro', code: 'GUARULHOS', address: 'Rua X', phone: '(11) 0000-0000', email: 'clinica@gmail.com' },
        { name: 'Guarulhos Tabõao', code: 'TABOAO', address: 'Rua X', phone: '(11) 0000-0000', email: 'clinica@gmail.com' },
        { name: 'Tatuapé', code: 'TATUAPE', address: 'Rua X', phone: '(11) 0000-0000', email: 'clinica@gmail.com' },
        { name: 'Bela Cintra', code: 'BELACINTRA', address: 'Rua X', phone: '(11) 0000-0000', email: 'clinica@gmail.com' },
    ];

    const estStmt = db.prepare("INSERT INTO establishments (name, code, address, phone, email) VALUES (?, ?, ?, ?, ?)");
    establishments.forEach(e => estStmt.run(e.name, e.code, e.address, e.phone, e.email));
    estStmt.finalize();

    // Insert sample services for each establishment
    const services = [
        { name: 'Admissional/Demissional', prefix: 'ADM', time: 15, est: 1 },
        { name: 'Analises Clinicas', prefix: 'ANA', time: 15, est: 1 },
        { name: 'Atendimento Preferencial', prefix: 'ATP', time: 15, est: 1 },
        { name: 'Cardiológicos', prefix: 'CAR', time: 15, est: 1 },
        { name: 'Cedusp Preferencial', prefix: 'CEP', time: 15, est: 1 },
        { name: 'Cedusp/Cadi', prefix: 'CED', time: 15, est: 1 },
        { name: 'Colpo/ Vulvo', prefix: 'CPV', time: 15, est: 1 },
        { name: 'Colposcopia/ Vulvoscopia', prefix: 'COL', time: 15, est: 1 },
        { name: 'Dr. Edvaldo Preferencial', prefix: 'DRE', time: 15, est: 1 },
        { name: 'Dr Francisco Preferencial', prefix: 'DRF', time: 15, est: 1 },
        { name: 'Ecocardiograma / Eco Fetal', prefix: 'ECO', time: 15, est: 1 },
        { name: 'Ecodoppler/ Teste Erg', prefix: 'EDT', time: 15, est: 1 },
        { name: 'Ecodopplercardiograma', prefix: 'ECC', time: 15, est: 1 },
        { name: 'Eletroneuro', prefix: 'ELE', time: 15, est: 1 },
        { name: 'Eletroneuro / Doppler', prefix: 'ELD', time: 15, est: 1 },
        { name: 'Endoscopia(Gastros)', prefix: 'ENG', time: 15, est: 1 },
        { name: 'Endoscopia/Colono', prefix: 'ENC', time: 15, est: 1 },
        { name: 'Endoscopia/Colonoscopia', prefix: 'SCO', time: 15, est: 1 },
        { name: 'Exames Cardiológicos', prefix: 'EXC', time: 15, est: 1 },
        { name: 'Exames de Imagem', prefix: 'EXI', time: 15, est: 1 },
        { name: 'Exames de Sangue', prefix: 'EXS', time: 15, est: 1 },
        { name: 'Mamo/Dens/Raio-X', prefix: 'MDR', time: 15, est: 1 },
        { name: 'Mamo/Densi/Raio-X', prefix: 'MDX', time: 15, est: 1 },
        { name: 'Mamografia', prefix: 'MAM', time: 15, est: 1 },
        { name: 'Mamografia/ Raio X', prefix: 'MRX', time: 15, est: 1 },
        { name: 'Medicina do Trabalho', prefix: 'MED', time: 15, est: 1 },
        { name: 'Medicina do Trabalho Pref.', prefix: 'MTP', time: 15, est: 1 },
        { name: 'Ocupacional', prefix: 'OCU', time: 15, est: 1 },
        { name: 'Particular', prefix: 'PAR', time: 15, est: 1 },
        { name: 'Preferencial', prefix: 'PRE', time: 15, est: 1 },
        { name: 'Preferencial Recepção', prefix: 'PRR', time: 15, est: 1 },
        { name: 'Raio X', prefix: 'RAI', time: 15, est: 1 },
        { name: 'Recepcao', prefix: 'REC', time: 15, est: 1 },
        { name: 'Resultado de Exame', prefix: 'RES', time: 15, est: 1 },
        { name: 'Retirada de Exames', prefix: 'RET', time: 15, est: 1 },
        { name: 'Retorno ao Trabalho', prefix: 'RAT', time: 15, est: 1 },
        { name: 'Teste Ergométrico', prefix: 'TES', time: 15, est: 1 },
        { name: 'Tomografia', prefix: 'TOM', time: 15, est: 1 },
        { name: 'Triagem Coleta', prefix: 'TRC', time: 15, est: 1 },
        { name: 'Triagem Preferencial 1', prefix: 'TP1', time: 15, est: 1 },
        { name: 'Triagem Preferencial 2', prefix: 'TP2', time: 15, est: 1 },
        { name: 'Ultrassom', prefix: 'ULT', time: 15, est: 1 },
        { name: 'Ultrassom 1', prefix: 'UL1', time: 15, est: 1 },
        { name: 'Ultrassom Preferencial', prefix: 'ULP', time: 15, est: 1 }
    ];

    const svcStmt = db.prepare("INSERT INTO services (name, prefix, average_time_minutes, establishment_id) VALUES (?, ?, ?, ?)");
    services.forEach(s => svcStmt.run(s.name, s.prefix, s.time, s.est));
    svcStmt.finalize();

    // Insert sample rooms for each establishment
    const rooms = [
        { name: 'Sala 1', type: 'Consulta', est: 1 },
        { name: 'Sala 2', type: 'Exames', est: 1 },
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
    ];

    const menuStmt = db.prepare("INSERT INTO service_menus (label, parent_id, service_id, order_index, establishment_id) VALUES (?, ?, ?, ?, ?)");
    menus.forEach(m => menuStmt.run(m.label, m.parent, m.service, m.order, m.est));
    menuStmt.finalize();

    // Insert room-service mappings
    db.run("INSERT INTO room_services (room_id, service_id) VALUES (1, 2), (2, 3), (2, 4)");

    // Insert sample users
    const users = [
        { name: 'Freguesia', username: 'freguesia', password: '123', role: 'professional', est: 1 },
        { name: 'Santana', username: 'santana', password: '123', role: 'professional', est: 2 },
        { name: 'Guarulhos Centro', username: 'guarulhos', password: '123', role: 'professional', est: 3 },
        { name: 'Guarulhos Tabõao', username: 'taboao', password: '123', role: 'professional', est: 4 },
        { name: 'Tatuapé', username: 'tatuape', password: '123', role: 'professional', est: 5 },
        { name: 'Bela Cintra', username: 'bela', password: '123', role: 'professional', est: 6 },
        { name: 'Administrador', username: 'admin', password: 'admin', role: 'admin', est: null }
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
