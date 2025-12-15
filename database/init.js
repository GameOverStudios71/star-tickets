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
    db.run("DROP TABLE IF EXISTS reception_desks");
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
            health_insurance_name TEXT,
            is_priority INTEGER DEFAULT 0,
            establishment_id INTEGER NOT NULL,
            reception_desk_id INTEGER,
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
            description TEXT,
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

    // 1. Insert Establishments
    const establishments = [
        { id: 1, name: 'Freguesia', code: 'FREGUESIA' },
        { id: 2, name: 'Santana', code: 'SANTANA' },
        { id: 3, name: 'Guarulhos Centro', code: 'GUARULHOS' },
        { id: 4, name: 'Guarulhos Taboão', code: 'TABOAO' },
        { id: 5, name: 'Tatuapé', code: 'TATUAPE' },
        { id: 6, name: 'Bela Cintra', code: 'BELACINTRA' },
    ];

    const estStmt = db.prepare("INSERT INTO establishments (id, name, code) VALUES (?, ?, ?)");
    establishments.forEach(e => estStmt.run(e.id, e.name, e.code));
    estStmt.finalize();

    // 2. Insert Global Services (deduplicated)
    const services = [
        { id: 1, name: 'Análises Clínicas', prefix: 'ANA' },
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

    const svcStmt = db.prepare("INSERT INTO services (id, name, prefix, establishment_id) VALUES (?, ?, ?, NULL)");
    services.forEach(s => svcStmt.run(s.id, s.name, s.prefix));
    svcStmt.finalize();

    // 3. Insert Menus per Establishment
    // Structure: 
    // Root 1: Convênio (ID 10) -> Children (Services)
    // Root 2: Particular (ID 11) -> Children (Services)
    // Note: IDs 10 and 11 are reused conceptually but must be unique rows per establishment in DB if we want strict separation, 
    // OR we can share them if the schema allows. 
    // The schema has `establishment_id` on `service_menus`.
    // So we will create unique root rows for each establishment.

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

        // Level 3: Services (Children of Convênio/Particular)
        serviceNames.forEach((name, index) => {
            const svc = services.find(s => s.name === name);
            if (svc) {
                // Add to Convênio
                menus.push({ id: menuIdCounter++, label: name, parent: convenioId, service: svc.id, est: estId, order: index + 1 });
                // Add to Particular
                menus.push({ id: menuIdCounter++, label: name, parent: particularId, service: svc.id, est: estId, order: index + 1 });
            } else {
                console.warn(`Service not found: ${name}`);
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
            } else {
                console.warn(`Service not found: ${name}`);
            }
        });
    };

    // Freguesia (ID 1)
    createMenusForEst(1, [
        'Análises Clínicas', 'Ultrassom', 'Mamo / Dens / Raio - X',
        'Endoscopia / Colono', 'Tomografia', 'Exames Cardiológicos'
    ]);

    // Santana (ID 2)
    createMenusForEst(2, [
        'Retirada de Exames', 'Triagem Completa', 'Endoscopia(Gastros)',
        'Ultrassom', 'Mamo / Densi / Raio - X', 'Cardiológicos',
        'Ecocardiograma / Eco Fetal'
    ]);

    // Guarulhos Centro (ID 3)
    createMenusForEst(3, [
        'Recepção', 'Retirada de Exames', 'Ecodopplercardiograma',
        'Endoscopia / Colonoscopia', 'Teste Ergométrico', 'Eletroneuro',
        'Ultrassom', 'Análises Clínicas', 'Colonoscopia / Vulvoscopia'
    ]);

    // Guarulhos Taboão (ID 4)
    createMenusForEst(4, [
        'Análises Clínicas', 'Raio X', 'Mamografia', 'Ultrassom'
    ]);

    // Tatuapé (ID 5)
    createMenusForEst(5, [
        'Exames de Imagem', 'Cedusp / Cadi', 'Resultado de Exames',
        'Ultrassom', 'Exames de Sangue', 'Colpo / Vulvo',
        'Análises Clínicas', 'Mamografia / Raio - X', 'Endoscopia / Colonoscopia',
        'Eletroneuro', 'Eletroneuro / Doppler', 'Ecodoppler / Teste Ergométrico'
    ]);

    // Bela Cintra (ID 6)
    createMenusForEst(6, [
        'Ultrassom'
    ]);

    const menuStmt = db.prepare("INSERT INTO service_menus (id, label, parent_id, service_id, establishment_id, order_index) VALUES (?, ?, ?, ?, ?, ?)");
    menus.forEach(m => menuStmt.run(m.id, m.label, m.parent, m.service, m.est, m.order));
    menuStmt.finalize();

    // 4. Insert Sample Rooms (Generic)
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

    // 4.1. Insert Room Services (vincular serviços às salas)
    const roomServices = [
        // Freguesia - Sala 1 e 2 (serviços 1-6)
        { room: 1, service: 1 }, { room: 1, service: 2 }, { room: 1, service: 3 },
        { room: 2, service: 4 }, { room: 2, service: 5 }, { room: 2, service: 6 },
        // Santana - Sala 3 (serviços 7-11)
        { room: 3, service: 7 }, { room: 3, service: 8 }, { room: 3, service: 9 },
        { room: 3, service: 10 }, { room: 3, service: 11 },
        // Guarulhos Centro - Sala 4 (serviços 12-17)
        { room: 4, service: 12 }, { room: 4, service: 13 }, { room: 4, service: 14 },
        { room: 4, service: 15 }, { room: 4, service: 16 }, { room: 4, service: 17 },
        // Guarulhos Taboão - Sala 5 (serviços 1, 18, 19, 2)
        { room: 5, service: 1 }, { room: 5, service: 18 }, { room: 5, service: 19 }, { room: 5, service: 2 },
        // Tatuapé - Sala 6 (serviços 20-27)
        { room: 6, service: 20 }, { room: 6, service: 21 }, { room: 6, service: 22 },
        { room: 6, service: 23 }, { room: 6, service: 24 }, { room: 6, service: 25 },
        // Bela Cintra - Sala 7 (serviço 2)
        { room: 7, service: 2 },
    ];
    const rsStmt = db.prepare("INSERT INTO room_services (room_id, service_id) VALUES (?, ?)");
    roomServices.forEach(rs => rsStmt.run(rs.room, rs.service));
    rsStmt.finalize();

    // 4.2. Insert Reception Desks (4 per establishment)
    const receptionDesks = [];
    establishments.forEach(est => {
        for (let i = 1; i <= 4; i++) {
            receptionDesks.push({ name: `Mesa ${i}`, est: est.id });
        }
    });
    const deskStmt = db.prepare("INSERT INTO reception_desks (name, establishment_id) VALUES (?, ?)");
    receptionDesks.forEach(d => deskStmt.run(d.name, d.est));
    deskStmt.finalize();

    // 5. Insert Users (com roles: admin, manager, receptionist, professional, tv)
    const users = [
        // Admin geral
        { name: 'Administrador', username: 'admin', password: 'admin', role: 'admin', est: null },

        // Freguesia (est 1)
        { name: 'Gerente Freguesia', username: 'gerente1', password: '123', role: 'manager', est: 1 },
        { name: 'Recepção Freguesia', username: 'recepcao1', password: '123', role: 'receptionist', est: 1 },
        { name: 'Profissional Freguesia', username: 'profissional1', password: '123', role: 'professional', est: 1 },
        { name: 'TV Freguesia', username: 'tv1', password: '123', role: 'tv', est: 1 },

        // Santana (est 2)
        { name: 'Gerente Santana', username: 'gerente2', password: '123', role: 'manager', est: 2 },
        { name: 'Recepção Santana', username: 'recepcao2', password: '123', role: 'receptionist', est: 2 },
        { name: 'Profissional Santana', username: 'profissional2', password: '123', role: 'professional', est: 2 },
        { name: 'TV Santana', username: 'tv2', password: '123', role: 'tv', est: 2 },

        // Guarulhos Centro (est 3)
        { name: 'Gerente Guarulhos', username: 'gerente3', password: '123', role: 'manager', est: 3 },
        { name: 'Recepção Guarulhos', username: 'recepcao3', password: '123', role: 'receptionist', est: 3 },
        { name: 'Profissional Guarulhos', username: 'profissional3', password: '123', role: 'professional', est: 3 },
        { name: 'TV Guarulhos', username: 'tv3', password: '123', role: 'tv', est: 3 },

        // Taboão (est 4)
        { name: 'Gerente Taboão', username: 'gerente4', password: '123', role: 'manager', est: 4 },
        { name: 'Recepção Taboão', username: 'recepcao4', password: '123', role: 'receptionist', est: 4 },
        { name: 'Profissional Taboão', username: 'profissional4', password: '123', role: 'professional', est: 4 },
        { name: 'TV Taboão', username: 'tv4', password: '123', role: 'tv', est: 4 },

        // Tatuapé (est 5)
        { name: 'Gerente Tatuapé', username: 'gerente5', password: '123', role: 'manager', est: 5 },
        { name: 'Recepção Tatuapé', username: 'recepcao5', password: '123', role: 'receptionist', est: 5 },
        { name: 'Profissional Tatuapé', username: 'profissional5', password: '123', role: 'professional', est: 5 },
        { name: 'TV Tatuapé', username: 'tv5', password: '123', role: 'tv', est: 5 },

        // Bela Cintra (est 6)
        { name: 'Gerente Bela Cintra', username: 'gerente6', password: '123', role: 'manager', est: 6 },
        { name: 'Recepção Bela Cintra', username: 'recepcao6', password: '123', role: 'receptionist', est: 6 },
        { name: 'Profissional Bela Cintra', username: 'profissional6', password: '123', role: 'professional', est: 6 },
        { name: 'TV Bela Cintra', username: 'tv6', password: '123', role: 'tv', est: 6 },
    ];
    const userStmt = db.prepare("INSERT INTO users (name, username, password, role, establishment_id) VALUES (?, ?, ?, ?, ?)");
    users.forEach(u => userStmt.run(u.name, u.username, u.password, u.role, u.est));
    userStmt.finalize(() => {
        console.log('✅ Database recreated with reorganized menus per branch!');
        db.close();
    });
});
