const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.resolve(__dirname, 'star-tickets.db');
const db = new sqlite3.Database(dbPath);

console.log('🔄 Initializing Database with SaaS Multi-Tenancy Schema...');

db.serialize(() => {
    // Drop existing tables (including webcheckin tables)
    db.run("DROP TABLE IF EXISTS optimization_logs");
    db.run("DROP TABLE IF EXISTS manager_notifications");
    db.run("DROP TABLE IF EXISTS webcheckin_files");
    db.run("DROP TABLE IF EXISTS webcheckin_responses");
    db.run("DROP TABLE IF EXISTS webcheckin_fields");
    db.run("DROP TABLE IF EXISTS webcheckin_forms");
    db.run("DROP TABLE IF EXISTS ticket_status_logs");
    db.run("DROP TABLE IF EXISTS attendance_logs");
    db.run("DROP TABLE IF EXISTS ticket_services");
    db.run("DROP TABLE IF EXISTS tickets");
    db.run("DROP TABLE IF EXISTS customers");
    db.run("DROP TABLE IF EXISTS room_services");
    db.run("DROP TABLE IF EXISTS service_menus");
    db.run("DROP TABLE IF EXISTS services");
    db.run("DROP TABLE IF EXISTS rooms");
    db.run("DROP TABLE IF EXISTS reception_desks");
    db.run("DROP TABLE IF EXISTS users");
    db.run("DROP TABLE IF EXISTS establishments");
    db.run("DROP TABLE IF EXISTS clients");

    // Create clients table (SaaS Root)
    db.run(`
        CREATE TABLE clients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            slug TEXT UNIQUE NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    `);

    // Create establishments table
    db.run(`
        CREATE TABLE establishments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            code TEXT NOT NULL,
            address TEXT,
            phone TEXT,
            email TEXT,
            is_active INTEGER DEFAULT 1,
            webcheckin_token_expiry_minutes INTEGER DEFAULT 30,
            webcheckin_max_file_size_mb INTEGER DEFAULT 5,
            optimization_enabled INTEGER DEFAULT 0,
            optimization_mode TEXT DEFAULT 'MANUAL',
            optimization_strategy TEXT DEFAULT 'BALANCED',
            optimization_custom_rules TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (client_id) REFERENCES clients(id),
            UNIQUE(client_id, code)
        )
    `);

    // Create services table
    db.run(`
        CREATE TABLE services (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            prefix TEXT NOT NULL,
            average_time_minutes INTEGER DEFAULT 15,
            description TEXT,
            webcheckin_enabled INTEGER DEFAULT 0,
            establishment_id INTEGER,
            FOREIGN KEY (client_id) REFERENCES clients(id),
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
            capacity INTEGER DEFAULT 1,
            priority_score INTEGER DEFAULT 0,
            FOREIGN KEY (establishment_id) REFERENCES establishments(id)
        )
    `);

    // Create reception desks table
    db.run(`
        CREATE TABLE reception_desks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            establishment_id INTEGER NOT NULL,
            is_active INTEGER DEFAULT 1,
            FOREIGN KEY (establishment_id) REFERENCES establishments(id)
        )
    `);

    // Create customers table
    db.run(`
        CREATE TABLE customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            phone TEXT,
            email TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (client_id) REFERENCES clients(id)
        )
    `);

    // Create tickets table
    db.run(`
        CREATE TABLE tickets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_id INTEGER NOT NULL,
            display_code TEXT NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            status TEXT DEFAULT 'WAITING_RECEPTION',
            customer_id INTEGER,
            temp_customer_name TEXT,
            health_insurance_name TEXT,
            is_priority INTEGER DEFAULT 0,
            establishment_id INTEGER NOT NULL,
            reception_desk_id INTEGER,
            webcheckin_status TEXT DEFAULT NULL,
            webcheckin_token TEXT,
            webcheckin_started_at DATETIME,
            webcheckin_completed_at DATETIME,
            webcheckin_token_expires_at DATETIME,
            FOREIGN KEY (client_id) REFERENCES clients(id),
            FOREIGN KEY (customer_id) REFERENCES customers(id),
            FOREIGN KEY (establishment_id) REFERENCES establishments(id),
            FOREIGN KEY (reception_desk_id) REFERENCES reception_desks(id)
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
            updated_at DATETIME,
            room_id INTEGER,
            FOREIGN KEY (ticket_id) REFERENCES tickets(id),
            FOREIGN KEY (service_id) REFERENCES services(id),
            FOREIGN KEY (room_id) REFERENCES rooms(id)
        )
    `);

    // Create users table
    db.run(`
        CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_id INTEGER, -- NULL for SuperAdmin
            name TEXT NOT NULL,
            username TEXT UNIQUE NOT NULL, -- Global Uniqueness for simpler login? Or scoped? 
                                            -- Plan says: 'client.username' logic. 
                                            -- To make it easy, we keep username unique. 
                                            -- Real SaaS might allow dupes across clients, but simpler unique is better for now.
            password TEXT NOT NULL,
            role TEXT DEFAULT 'professional',
            establishment_id INTEGER, -- Optional (e.g. for Multi-Est Managers or ClientAdmins)
            FOREIGN KEY (client_id) REFERENCES clients(id),
            FOREIGN KEY (establishment_id) REFERENCES establishments(id)
        )
    `);

    // Create service_menus table
    db.run(`
        CREATE TABLE service_menus (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            label TEXT NOT NULL,
            description TEXT,
            parent_id INTEGER,
            service_id INTEGER,
            order_index INTEGER DEFAULT 0,
            icon TEXT,
            establishment_id INTEGER,
            client_id INTEGER NOT NULL, -- Menus are usually part of the client config
            FOREIGN KEY (parent_id) REFERENCES service_menus(id),
            FOREIGN KEY (service_id) REFERENCES services(id),
            FOREIGN KEY (establishment_id) REFERENCES establishments(id),
            FOREIGN KEY (client_id) REFERENCES clients(id)
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

    // Create ticket_status_logs table (for timeline tracking)
    db.run(`
        CREATE TABLE ticket_status_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ticket_id INTEGER NOT NULL,
            status TEXT NOT NULL,
            changed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            user_id INTEGER,
            room_id INTEGER,
            desk_id INTEGER,
            notes TEXT,
            FOREIGN KEY (ticket_id) REFERENCES tickets(id),
            FOREIGN KEY (user_id) REFERENCES users(id),
            FOREIGN KEY (room_id) REFERENCES rooms(id),
            FOREIGN KEY (desk_id) REFERENCES reception_desks(id)
        )
    `);

    // =========================================================================
    // WebCheckin Tables
    // =========================================================================

    // Create webcheckin_forms table (dynamic forms per establishment+service)
    db.run(`
        CREATE TABLE webcheckin_forms (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            establishment_id INTEGER NOT NULL,
            service_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            description TEXT,
            is_active INTEGER DEFAULT 1,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME,
            FOREIGN KEY (establishment_id) REFERENCES establishments(id),
            UNIQUE(establishment_id, service_id)
        )
    `);

    // =========================================================================
    // Smart Queue Tables
    // =========================================================================

    // Create manager_notifications table
    db.run(`
        CREATE TABLE manager_notifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            establishment_id INTEGER NOT NULL,
            type TEXT NOT NULL, -- 'INFO', 'WARNING', 'ACTION_REQUIRED'
            title TEXT NOT NULL,
            message TEXT NOT NULL,
            data TEXT, -- JSON details
            status TEXT DEFAULT 'UNREAD', -- 'UNREAD', 'READ', 'APPROVED', 'REJECTED'
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (establishment_id) REFERENCES establishments(id)
        )
    `);

    // Create optimization_logs table
    db.run(`
        CREATE TABLE optimization_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            establishment_id INTEGER NOT NULL,
            action_taken TEXT NOT NULL,
            details TEXT,
            estimated_time_saved_min INTEGER DEFAULT 0,
            triggered_by TEXT DEFAULT 'SYSTEM',
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    `);

    // Create webcheckin_fields table (form fields)
    db.run(`
        CREATE TABLE webcheckin_fields (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            form_id INTEGER NOT NULL,
            field_type TEXT NOT NULL CHECK(field_type IN ('text', 'number', 'date', 'select', 'checkbox', 'file', 'photo', 'textarea', 'email', 'phone')),
            label TEXT NOT NULL,
            placeholder TEXT,
            is_required INTEGER DEFAULT 0,
            options TEXT,
            order_index INTEGER DEFAULT 0,
            validation_rules TEXT,
            FOREIGN KEY (form_id) REFERENCES webcheckin_forms(id) ON DELETE CASCADE
        )
    `);

    // Create webcheckin_responses table (client responses)
    db.run(`
        CREATE TABLE webcheckin_responses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ticket_id INTEGER NOT NULL,
            field_id INTEGER NOT NULL,
            value TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME,
            updated_by_user_id INTEGER,
            FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE,
            FOREIGN KEY (field_id) REFERENCES webcheckin_fields(id),
            FOREIGN KEY (updated_by_user_id) REFERENCES users(id)
        )
    `);

    // Create webcheckin_files table (uploaded files/photos)
    db.run(`
        CREATE TABLE webcheckin_files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ticket_id INTEGER NOT NULL,
            field_id INTEGER NOT NULL,
            filename TEXT NOT NULL,
            original_name TEXT NOT NULL,
            mime_type TEXT NOT NULL,
            size_bytes INTEGER NOT NULL,
            storage_path TEXT NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE,
            FOREIGN KEY (field_id) REFERENCES webcheckin_fields(id)
        )
    `);

    // =========================================================================
    // Indexes for performance
    // =========================================================================
    db.run(`CREATE INDEX IF NOT EXISTS idx_tickets_webcheckin_token ON tickets(webcheckin_token)`);
    db.run(`CREATE INDEX IF NOT EXISTS idx_tickets_establishment_status ON tickets(establishment_id, status)`);
    db.run(`CREATE INDEX IF NOT EXISTS idx_ticket_services_ticket ON ticket_services(ticket_id)`);
    db.run(`CREATE INDEX IF NOT EXISTS idx_webcheckin_responses_ticket ON webcheckin_responses(ticket_id)`);

    console.log('✅ Tables created (including WebCheckin and indexes).');

    // SEEDING

    // 0. Client
    const clients = [
        { id: 1, name: 'Pro Ocupacional', slug: 'proocupacional' }
    ];
    const clientStmt = db.prepare("INSERT INTO clients (id, name, slug) VALUES (?, ?, ?)");
    clients.forEach(c => clientStmt.run(c.id, c.name, c.slug));
    clientStmt.finalize();

    // 1. Insert Establishments
    const establishments = [
        { id: 1, name: 'Freguesia', code: 'FREGUESIA', client_id: 1 },
        { id: 2, name: 'Santana', code: 'SANTANA', client_id: 1 },
        { id: 3, name: 'Guarulhos Centro', code: 'GUARULHOS', client_id: 1 },
        { id: 4, name: 'Guarulhos Taboão', code: 'TABOAO', client_id: 1 },
        { id: 5, name: 'Tatuapé', code: 'TATUAPE', client_id: 1 },
        { id: 6, name: 'Bela Cintra', code: 'BELACINTRA', client_id: 1 },
    ];

    const estStmt = db.prepare("INSERT INTO establishments (id, name, code, client_id) VALUES (?, ?, ?, ?)");
    establishments.forEach(e => estStmt.run(e.id, e.name, e.code, e.client_id));
    estStmt.finalize();

    // 2. Insert Services (Client Global)
    const services = [
        // { id: 1, name: 'Análises Clínicas', prefix: 'ANA' }, // Converted to Category
        { id: 2, name: 'Ultrassom', prefix: 'ULT' },

        { id: 3, name: 'Mamo / Dens / Raio - X', prefix: 'MDR' },
        { id: 4, name: 'Endoscopia / Colono', prefix: 'ENC' },
        { id: 5, name: 'Tomografia', prefix: 'TOM' },
        { id: 6, name: 'Exames Cardiológicos', prefix: 'EXC' },
        { id: 7, name: 'Retirada de Exames', prefix: 'RET' },
        { id: 8, name: 'Triagem Completa', prefix: 'TRC' },
        { id: 9, name: 'Endoscopia(Gastros)', prefix: 'ENG' },
        { id: 10, name: 'Cardiológicos', prefix: 'CAR' },
        { id: 11, name: 'Ecocardiograma / Eco Fetal', prefix: 'ECO' },
        { id: 12, name: 'Recepção', prefix: 'REC' },
        { id: 13, name: 'Ecodopplercardiograma', prefix: 'ECC' },
        { id: 14, name: 'Endoscopia / Colonoscopia', prefix: 'SCO' },
        { id: 15, name: 'Teste Ergométrico', prefix: 'TES' },
        { id: 16, name: 'Eletroneuro', prefix: 'ELE' },
        { id: 17, name: 'Colonoscopia / Vulvoscopia', prefix: 'COV' },
        { id: 18, name: 'Raio X', prefix: 'RAI' },
        { id: 19, name: 'Mamografia', prefix: 'MAM' },
        { id: 20, name: 'Exames de Imagem', prefix: 'EXI' },
        { id: 21, name: 'Cedusp / Cadi', prefix: 'CED' },
        { id: 22, name: 'Resultado de Exames', prefix: 'RES' },
        { id: 23, name: 'Exames de Sangue', prefix: 'EXS' },
        { id: 24, name: 'Colpo / Vulvo', prefix: 'CPV' },
        { id: 25, name: 'Mamografia / Raio - X', prefix: 'MRX' },
        { id: 26, name: 'Eletroneuro / Doppler', prefix: 'ELD' },
        { id: 27, name: 'Ecodoppler / Teste Ergométrico', prefix: 'EDT' },
        { id: 28, name: 'Mamo / Densi / Raio - X', prefix: 'MDX' },
        { id: 29, name: 'Demissional', prefix: 'DEM' },
        { id: 30, name: 'Admissional', prefix: 'ADM' },
        { id: 31, name: 'Retorno ao Trabalho', prefix: 'RAT' },
        { id: 32, name: 'Mudanças de Função', prefix: 'MUF' },
        { id: 33, name: 'Periódico', prefix: 'PER' }
    ];

    const svcStmt = db.prepare("INSERT INTO services (id, name, prefix, establishment_id, client_id) VALUES (?, ?, ?, NULL, 1)");
    services.forEach(s => svcStmt.run(s.id, s.name, s.prefix));
    svcStmt.finalize();

    // 3. Insert Menus
    let menuIdCounter = 1;
    const menus = [];

    const createMenusForEst = (estId, serviceNames) => {
        // Level 1: Análises Clínicas (Root)
        const rootId = menuIdCounter++;
        menus.push({ id: rootId, label: '🔬 Análises Clínicas', parent: null, service: null, est: estId, order: 1 });

        // Level 2: Convênio (Child of Análises Clínicas)
        const convenioId = menuIdCounter++;
        menus.push({ id: convenioId, label: '💳 Convênio', parent: rootId, service: null, est: estId, order: 1 });

        // Level 2: Particular (Child of Análises Clínicas)
        const particularId = menuIdCounter++;
        menus.push({ id: particularId, label: '💵 Particular', parent: rootId, service: null, est: estId, order: 2 });

        // Level 2: Clínica Parceira (Child of Análises Clínicas)
        const clinicaParceiraId = menuIdCounter++;
        menus.push({ id: clinicaParceiraId, label: '🏥 Clínica Parceira', parent: rootId, service: null, est: estId, order: 3 });

        // Level 3: Services (Children of Convênio/Particular/Clínica Parceira)
        serviceNames.forEach((name, index) => {
            const svc = services.find(s => s.name === name);
            if (svc) {
                // Add to Convênio
                menus.push({ id: menuIdCounter++, label: name, parent: convenioId, service: svc.id, est: estId, order: index + 1 });
                // Add to Particular
                menus.push({ id: menuIdCounter++, label: name, parent: particularId, service: svc.id, est: estId, order: index + 1 });
                // Add to Clínica Parceira
                menus.push({ id: menuIdCounter++, label: name, parent: clinicaParceiraId, service: svc.id, est: estId, order: index + 1 });
            }
        });

        // Level 1: Medicina do Trabalho (Root)
        const medTrabId = menuIdCounter++;
        menus.push({ id: medTrabId, label: '💼 Medicina do Trabalho', parent: null, service: null, est: estId, order: 2 });

        // Level 2: Medicina do Trabalho Services
        const medTrabServices = ['Demissional', 'Admissional', 'Retorno ao Trabalho', 'Mudanças de Função', 'Periódico'];
        medTrabServices.forEach((name, index) => {
            const svc = services.find(s => s.name === name);
            if (svc) {
                menus.push({ id: menuIdCounter++, label: name, parent: medTrabId, service: svc.id, est: estId, order: index + 1 });
            }
        });
    };

    // Re-use logic for each establishment 
    createMenusForEst(1, ['Exames de Sangue', 'Ultrassom', 'Mamo / Dens / Raio - X', 'Endoscopia / Colono', 'Tomografia', 'Exames Cardiológicos']);
    createMenusForEst(2, ['Retirada de Exames', 'Triagem Completa', 'Endoscopia(Gastros)', 'Ultrassom', 'Mamo / Densi / Raio - X', 'Cardiológicos', 'Ecocardiograma / Eco Fetal']);
    createMenusForEst(3, ['Recepção', 'Retirada de Exames', 'Ecodopplercardiograma', 'Endoscopia / Colonoscopia', 'Teste Ergométrico', 'Eletroneuro', 'Ultrassom', 'Exames de Sangue', 'Colonoscopia / Vulvoscopia']);
    createMenusForEst(4, ['Exames de Sangue', 'Raio X', 'Mamografia', 'Ultrassom']);
    createMenusForEst(5, ['Exames de Imagem', 'Cedusp / Cadi', 'Resultado de Exames', 'Ultrassom', 'Exames de Sangue', 'Colpo / Vulvo', 'Exames de Sangue', 'Mamografia / Raio - X', 'Endoscopia / Colonoscopia', 'Eletroneuro', 'Eletroneuro / Doppler', 'Ecodoppler / Teste Ergométrico']);
    createMenusForEst(6, ['Ultrassom']);

    const menuStmt = db.prepare("INSERT INTO service_menus (id, label, parent_id, service_id, establishment_id, order_index, client_id) VALUES (?, ?, ?, ?, ?, ?, 1)");
    menus.forEach(m => menuStmt.run(m.id, m.label, m.parent, m.service, m.est, m.order));
    menuStmt.finalize();

    // 4. Insert Use Rooms
    const rooms = [
        { id: 1, name: 'Sala 1', type: 'Geral', est: 1 },
        { id: 2, name: 'Sala 2', type: 'Geral', est: 1 },
        { id: 3, name: 'Sala 1', type: 'Geral', est: 2 },
        { id: 4, name: 'Sala 1', type: 'Geral', est: 3 },
        { id: 5, name: 'Sala 1', type: 'Geral', est: 4 },
        { id: 6, name: 'Sala 1', type: 'Geral', est: 5 },
        { id: 7, name: 'Sala 1', type: 'Geral', est: 6 },
    ];
    const roomStmt = db.prepare("INSERT INTO rooms (id, name, type, establishment_id) VALUES (?, ?, ?, ?)");
    rooms.forEach(r => roomStmt.run(r.id, r.name, r.type, r.est));
    roomStmt.finalize();

    // 4.1 Room Services
    const specificServices = services; // services.filter(s => s.id !== 1);
    const roomServices = [];
    rooms.forEach(room => {
        specificServices.forEach(service => {
            roomServices.push({ room: room.id, service: service.id });
        });
    });
    const rsStmt = db.prepare("INSERT INTO room_services (room_id, service_id) VALUES (?, ?)");
    roomServices.forEach(rs => rsStmt.run(rs.room, rs.service));
    rsStmt.finalize();

    // 4.2 Reception Desks
    const receptionDesks = [];
    establishments.forEach(est => {
        for (let i = 1; i <= 4; i++) {
            receptionDesks.push({ name: `Mesa ${i}`, est: est.id });
        }
    });
    const deskStmt = db.prepare("INSERT INTO reception_desks (name, establishment_id) VALUES (?, ?)");
    receptionDesks.forEach(d => deskStmt.run(d.name, d.est));
    deskStmt.finalize();

    // 5. Users
    const users = [
        // SuperAdmin (Global) - No client_id? Or Client_id=NULL? Schema allows NULL.
        { name: 'Administrador', username: 'admin', password: 'admin', role: 'admin', est: null, client_id: null },
    ];

    // Helper map for Est Codes
    const estCodes = {
        1: 'FREGUESIA',
        2: 'SANTANA',
        3: 'GUARULHOS',
        4: 'TABOAO',
        5: 'TATUAPE',
        6: 'BELACINTRA'
    };

    // Generate users for all establishments (ProOcupacional.CODE.Role)
    const roles = ['manager', 'receptionist', 'professional', 'tv', 'totem'];
    const roleMap = {
        'manager': 'Gerente',
        'receptionist': 'Recepção',
        'professional': 'Profissional',
        'tv': 'TV',
        'totem': 'Totem'
    };

    // Helper to normalize strings (remove accents, lowercase)
    const normalize = (str) => {
        return str.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
    };

    for (let i = 1; i <= 6; i++) {
        const estCode = estCodes[i];
        roles.forEach(role => {
            // Format: proocupacional.freguesia.gerente (all lowercase/normalized)
            const rawRole = roleMap[role];
            const normalizedRole = normalize(rawRole);
            const normalizedEst = normalize(estCode);

            const username = `proocupacional.${normalizedEst}.${normalizedRole}`;

            users.push({
                name: `${roleMap[role]} ${estCode}`,
                username: username,
                password: '123',
                role: role,
                est: i,
                client_id: 1
            });
        });
    }

    const userStmt = db.prepare("INSERT INTO users (name, username, password, role, establishment_id, client_id) VALUES (?, ?, ?, ?, ?, ?)");
    users.forEach(u => userStmt.run(u.name, u.username, u.password, u.role, u.est, u.client_id));
    userStmt.finalize(() => {
        console.log('✅ Database successfully recreated with SaaS Multi-Tenancy support!');
        db.close();
    });
});
