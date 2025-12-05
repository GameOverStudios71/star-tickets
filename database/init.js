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
            health_insurance_name TEXT,
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
            updated_at DATETIME,
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

    // Insert comprehensive menu structure for all services
    // Service IDs will be:
    // 1=Admissional/Demissional, 2=Analises Clinicas, 3=Atendimento Preferencial, 4=Cardiológicos,
    // 5=Cedusp Preferencial, 6=Cedusp/Cadi, 7=Colpo/Vulvo, 8=Colposcopia/Vulvoscopia,
    // 9=Dr. Edvaldo Pref, 10=Dr Francisco Pref, 11=Ecocardiograma/Eco Fetal, 12=Ecodoppler/Teste Erg,
    // 13=Ecodopplercardiograma, 14=Eletroneuro, 15=Eletroneuro/Doppler, 16=Endoscopia(Gastros),
    // 17=Endoscopia/Colono, 18=Endoscopia/Colonoscopia, 19=Exames Cardiológicos, 20=Exames de Imagem,
    // 21=Exames de Sangue, 22=Mamo/Dens/Raio-X, 23=Mamo/Densi/Raio-X, 24=Mamografia,
    // 25=Mamografia/Raio X, 26=Medicina do Trabalho, 27=Medicina do Trabalho Pref, 28=Ocupacional,
    // 29=Particular, 30=Preferencial, 31=Preferencial Recepção, 32=Raio X, 33=Recepcao,
    // 34=Resultado de Exame, 35=Retirada de Exames, 36=Retorno ao Trabalho, 37=Teste Ergométrico,
    // 38=Tomografia, 39=Triagem Coleta, 40=Triagem Preferencial 1, 41=Triagem Preferencial 2,
    // 42=Ultrassom, 43=Ultrassom 1, 44=Ultrassom Preferencial

    const menus = [
        // === NÍVEL 1: TIPO DE SERVIÇO ===
        { id: 1, label: '🔬 Análises Clínicas', desc: 'Exames de laboratório, imagem e procedimentos médicos', parent: null, service: null, order: 1, est: 1 },
        { id: 2, label: '💼 Medicina do Trabalho', desc: 'Admissional, demissional, ocupacional e retorno', parent: null, service: null, order: 2, est: 1 },

        // === ANÁLISES CLÍNICAS - NÍVEL 2: CONVÊNIO OU PARTICULAR ===
        { id: 10, label: '💳 Convênio', desc: 'Atendimento por plano de saúde', parent: 1, service: null, order: 1, est: 1 },
        { id: 11, label: '💵 Particular', desc: 'Pagamento direto', parent: 1, service: null, order: 2, est: 1 },

        // === CONVÊNIO - NÍVEL 3: NOME DO CONVÊNIO (placeholder, será input no frontend) ===
        // Após inserir o nome, vai para as categorias id:100+

        // === PARTICULAR E CONVÊNIO - NÍVEL 3/4: CATEGORIAS DE EXAMES ===
        { id: 100, label: '🩺 Exames Cardiológicos', desc: 'Ecocardiograma, teste ergométrico e exames do coração', parent: 10, service: null, order: 1, est: 1 },
        { id: 101, label: '🔬 Exames de Laboratório', desc: 'Análises clínicas, exames de sangue e coletas', parent: 10, service: null, order: 2, est: 1 },
        { id: 102, label: '📸 Exames de Imagem', desc: 'Raio-X, ultrassom, mamografia e tomografia', parent: 10, service: null, order: 3, est: 1 },
        { id: 103, label: '🏥 Procedimentos Especiais', desc: 'Endoscopia, colonoscopia, colposcopia e eletroneuro', parent: 10, service: null, order: 4, est: 1 },
        { id: 104, label: '📋 Recepção e Resultados', desc: 'Retirada de exames e atendimento em recepção', parent: 10, service: null, order: 5, est: 1 },
        { id: 105, label: '👨‍⚕️ Consultas Especializadas', desc: 'Consultas particulares e especializadas', parent: 10, service: null, order: 6, est: 1 },

        // Mesmas categorias para PARTICULAR (parent: 11)
        { id: 110, label: '🩺 Exames Cardiológicos', desc: 'Ecocardiograma, teste ergométrico e exames do coração', parent: 11, service: null, order: 1, est: 1 },
        { id: 111, label: '🔬 Exames de Laboratório', desc: 'Análises clínicas, exames de sangue e coletas', parent: 11, service: null, order: 2, est: 1 },
        { id: 112, label: '📸 Exames de Imagem', desc: 'Raio-X, ultrassom, mamografia e tomografia', parent: 11, service: null, order: 3, est: 1 },
        { id: 113, label: '🏥 Procedimentos Especiais', desc: 'Endoscopia, colonoscopia, colposcopia e eletroneuro', parent: 11, service: null, order: 4, est: 1 },
        { id: 114, label: '📋 Recepção e Resultados', desc: 'Retirada de exames e atendimento em recepção', parent: 11, service: null, order: 5, est: 1 },
        { id: 115, label: '👨‍⚕️ Consultas Especializadas', desc: 'Consultas particulares e especializadas', parent: 11, service: null, order: 6, est: 1 },

        // === CONVÊNIO - EXAMES CARDIOLÓGICOS ===
        { id: 1000, label: 'Cardiológicos', desc: null, parent: 100, service: 4, order: 1, est: 1 },
        { id: 1001, label: 'Ecocardiograma / Eco Fetal', desc: null, parent: 100, service: 11, order: 2, est: 1 },
        { id: 1002, label: 'Ecodoppler / Teste Ergométrico', desc: null, parent: 100, service: 12, order: 3, est: 1 },
        { id: 1003, label: 'Ecodopplercardiograma', desc: null, parent: 100, service: 13, order: 4, est: 1 },
        { id: 1004, label: 'Exames Cardiológicos Gerais', desc: null, parent: 100, service: 19, order: 5, est: 1 },
        { id: 1005, label: 'Teste Ergométrico', desc: null, parent: 100, service: 37, order: 6, est: 1 },

        // === CONVÊNIO - EXAMES DE LABORATÓRIO ===
        { id: 1010, label: 'Análises Clínicas', desc: null, parent: 101, service: 2, order: 1, est: 1 },
        { id: 1011, label: 'Exames de Sangue', desc: null, parent: 101, service: 21, order: 2, est: 1 },
        { id: 1012, label: 'Triagem Coleta', desc: null, parent: 101, service: 39, order: 3, est: 1 },

        // === CONVÊNIO - EXAMES DE IMAGEM ===
        { id: 1020, label: 'Raio X', desc: null, parent: 102, service: 32, order: 1, est: 1 },
        { id: 1021, label: 'Mamografia', desc: null, parent: 102, service: 24, order: 2, est: 1 },
        { id: 1022, label: 'Mamografia / Raio X', desc: null, parent: 102, service: 25, order: 3, est: 1 },
        { id: 1023, label: 'Mamo/Dens/Raio-X', desc: null, parent: 102, service: 22, order: 4, est: 1 },
        { id: 1024, label: 'Mamo/Densi/Raio-X', desc: null, parent: 102, service: 23, order: 5, est: 1 },
        { id: 1025, label: 'Ultrassom', desc: null, parent: 102, service: 42, order: 6, est: 1 },
        { id: 1026, label: 'Ultrassom 1', desc: null, parent: 102, service: 43, order: 7, est: 1 },
        { id: 1027, label: 'Tomografia', desc: null, parent: 102, service: 38, order: 8, est: 1 },
        { id: 1028, label: 'Exames de Imagem Gerais', desc: null, parent: 102, service: 20, order: 9, est: 1 },

        // === CONVÊNIO - PROCEDIMENTOS ESPECIAIS ===
        { id: 1030, label: 'Eletroneuro', desc: null, parent: 103, service: 14, order: 1, est: 1 },
        { id: 1031, label: 'Eletroneuro / Doppler', desc: null, parent: 103, service: 15, order: 2, est: 1 },
        { id: 1032, label: 'Endoscopia (Gastros)', desc: null, parent: 103, service: 16, order: 3, est: 1 },
        { id: 1033, label: 'Endoscopia/Colono', desc: null, parent: 103, service: 17, order: 4, est: 1 },
        { id: 1034, label: 'Endoscopia/Colonoscopia', desc: null, parent: 103, service: 18, order: 5, est: 1 },
        { id: 1035, label: 'Colpo/Vulvo', desc: null, parent: 103, service: 7, order: 6, est: 1 },
        { id: 1036, label: 'Colposcopia/Vulvoscopia', desc: null, parent: 103, service: 8, order: 7, est: 1 },

        // === CONVÊNIO - RECEPÇÃO E RESULTADOS ===
        { id: 1040, label: 'Recepção', desc: null, parent: 104, service: 33, order: 1, est: 1 },
        { id: 1041, label: 'Resultado de Exame', desc: null, parent: 104, service: 34, order: 2, est: 1 },
        { id: 1042, label: 'Retirada de Exames', desc: null, parent: 104, service: 35, order: 3, est: 1 },

        // === CONVÊNIO - CONSULTAS ESPECIALIZADAS ===
        { id: 1050, label: 'Cedusp/Cadi', desc: null, parent: 105, service: 6, order: 1, est: 1 },
        { id: 1051, label: 'Particular', desc: null, parent: 105, service: 29, order: 2, est: 1 },

        // === PARTICULAR - EXAMES CARDIOLÓGICOS ===
        { id: 1100, label: 'Cardiológicos', desc: null, parent: 110, service: 4, order: 1, est: 1 },
        { id: 1101, label: 'Ecocardiograma / Eco Fetal', desc: null, parent: 110, service: 11, order: 2, est: 1 },
        { id: 1102, label: 'Ecodoppler / Teste Ergométrico', desc: null, parent: 110, service: 12, order: 3, est: 1 },
        { id: 1103, label: 'Ecodopplercardiograma', desc: null, parent: 110, service: 13, order: 4, est: 1 },
        { id: 1104, label: 'Exames Cardiológicos Gerais', desc: null, parent: 110, service: 19, order: 5, est: 1 },
        { id: 1105, label: 'Teste Ergométrico', desc: null, parent: 110, service: 37, order: 6, est: 1 },

        // === PARTICULAR - EXAMES DE LABORATÓRIO ===
        { id: 1110, label: 'Análises Clínicas', desc: null, parent: 111, service: 2, order: 1, est: 1 },
        { id: 1111, label: 'Exames de Sangue', desc: null, parent: 111, service: 21, order: 2, est: 1 },
        { id: 1112, label: 'Triagem Coleta', desc: null, parent: 111, service: 39, order: 3, est: 1 },

        // === PARTICULAR - EXAMES DE IMAGEM ===
        { id: 1120, label: 'Raio X', desc: null, parent: 112, service: 32, order: 1, est: 1 },
        { id: 1121, label: 'Mamografia', desc: null, parent: 112, service: 24, order: 2, est: 1 },
        { id: 1122, label: 'Mamografia / Raio X', desc: null, parent: 112, service: 25, order: 3, est: 1 },
        { id: 1123, label: 'Mamo/Dens/Raio-X', desc: null, parent: 112, service: 22, order: 4, est: 1 },
        { id: 1124, label: 'Mamo/Densi/Raio-X', desc: null, parent: 112, service: 23, order: 5, est: 1 },
        { id: 1125, label: 'Ultrassom', desc: null, parent: 112, service: 42, order: 6, est: 1 },
        { id: 1126, label: 'Ultrassom 1', desc: null, parent: 112, service: 43, order: 7, est: 1 },
        { id: 1127, label: 'Tomografia', desc: null, parent: 112, service: 38, order: 8, est: 1 },
        { id: 1128, label: 'Exames de Imagem Gerais', desc: null, parent: 112, service: 20, order: 9, est: 1 },

        // === PARTICULAR - PROCEDIMENTOS ESPECIAIS ===
        { id: 1130, label: 'Eletroneuro', desc: null, parent: 113, service: 14, order: 1, est: 1 },
        { id: 1131, label: 'Eletroneuro / Doppler', desc: null, parent: 113, service: 15, order: 2, est: 1 },
        { id: 1132, label: 'Endoscopia (Gastros)', desc: null, parent: 113, service: 16, order: 3, est: 1 },
        { id: 1133, label: 'Endoscopia/Colono', desc: null, parent: 113, service: 17, order: 4, est: 1 },
        { id: 1134, label: 'Endoscopia/Colonoscopia', desc: null, parent: 113, service: 18, order: 5, est: 1 },
        { id: 1135, label: 'Colpo/Vulvo', desc: null, parent: 113, service: 7, order: 6, est: 1 },
        { id: 1136, label: 'Colposcopia/Vulvoscopia', desc: null, parent: 113, service: 8, order: 7, est: 1 },

        // === PARTICULAR - RECEPÇÃO E RESULTADOS ===
        { id: 1140, label: 'Recepção', desc: null, parent: 114, service: 33, order: 1, est: 1 },
        { id: 1141, label: 'Resultado de Exame', desc: null, parent: 114, service: 34, order: 2, est: 1 },
        { id: 1142, label: 'Retirada de Exames', desc: null, parent: 114, service: 35, order: 3, est: 1 },

        // === PARTICULAR - CONSULTAS ESPECIALIZADAS ===
        { id: 1150, label: 'Cedusp/Cadi', desc: null, parent: 115, service: 6, order: 1, est: 1 },
        { id: 1151, label: 'Particular', desc: null, parent: 115, service: 29, order: 2, est: 1 },

        // === MEDICINA DO TRABALHO - CATEGORIAS ===
        { id: 200, label: 'Admissional/Demissional', desc: null, parent: 2, service: 1, order: 1, est: 1 },
        { id: 201, label: 'Medicina do Trabalho', desc: null, parent: 2, service: 26, order: 2, est: 1 },
        { id: 202, label: 'Medicina do Trabalho Preferencial', desc: null, parent: 2, service: 27, order: 3, est: 1 },
        { id: 203, label: 'Ocupacional', desc: null, parent: 2, service: 28, order: 4, est: 1 },
        { id: 204, label: 'Retorno ao Trabalho', desc: null, parent: 2, service: 36, order: 5, est: 1 },
    ];

    const menuStmt = db.prepare("INSERT INTO service_menus (id, label, description, parent_id, service_id, order_index, establishment_id) VALUES (?, ?, ?, ?, ?, ?, ?)");
    menus.forEach(m => menuStmt.run(m.id, m.label, m.desc, m.parent, m.service, m.order, m.est));
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
