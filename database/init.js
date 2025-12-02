const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs');

const dbPath = path.resolve(__dirname, 'star-tickets.db');
const db = new sqlite3.Database(dbPath);

const schema = `
-- Configuração e Catálogo
CREATE TABLE IF NOT EXISTS services (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    prefix TEXT NOT NULL,
    average_time_minutes INTEGER DEFAULT 15,
    description TEXT
);

CREATE TABLE IF NOT EXISTS service_menus (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    parent_id INTEGER,
    label TEXT NOT NULL,
    service_id INTEGER,
    order_index INTEGER DEFAULT 0,
    icon TEXT,
    FOREIGN KEY (parent_id) REFERENCES service_menus(id),
    FOREIGN KEY (service_id) REFERENCES services(id)
);

CREATE TABLE IF NOT EXISTS rooms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    type TEXT,
    is_active BOOLEAN DEFAULT 1
);

CREATE TABLE IF NOT EXISTS room_services (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    room_id INTEGER NOT NULL,
    service_id INTEGER NOT NULL,
    FOREIGN KEY (room_id) REFERENCES rooms(id),
    FOREIGN KEY (service_id) REFERENCES services(id)
);

-- Fluxo de Atendimento
CREATE TABLE IF NOT EXISTS customers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    document_id TEXT,
    phone TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tickets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    display_code TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    status TEXT DEFAULT 'WAITING', -- WAITING, IN_PROGRESS, DONE, CANCELED
    customer_id INTEGER,
    temp_customer_name TEXT,
    FOREIGN KEY (customer_id) REFERENCES customers(id)
);

CREATE TABLE IF NOT EXISTS ticket_services (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ticket_id INTEGER NOT NULL,
    service_id INTEGER NOT NULL,
    status TEXT DEFAULT 'PENDING', -- PENDING, CALLED, IN_PROGRESS, COMPLETED, SKIPPED
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    order_sequence INTEGER DEFAULT 0,
    FOREIGN KEY (ticket_id) REFERENCES tickets(id),
    FOREIGN KEY (service_id) REFERENCES services(id)
);

-- Operação e Histórico
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT DEFAULT 'PROFESSIONAL' -- ADMIN, RECEPTIONIST, PROFESSIONAL
);

CREATE TABLE IF NOT EXISTS attendance_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ticket_service_id INTEGER NOT NULL,
    user_id INTEGER,
    room_id INTEGER,
    start_time DATETIME,
    end_time DATETIME,
    notes TEXT,
    FOREIGN KEY (ticket_service_id) REFERENCES ticket_services(id),
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (room_id) REFERENCES rooms(id)
);
`;

const seedData = async () => {
    // Check if services exist to avoid re-seeding
    db.get("SELECT count(*) as count FROM services", (err, row) => {
        if (err) console.error(err);
        if (row.count === 0) {
            console.log("Seeding database...");

            // Services
            db.run(`INSERT INTO services (name, prefix, average_time_minutes) VALUES 
                ('Triagem', 'TRI', 5),
                ('Consulta Geral', 'CON', 20),
                ('Exame de Sangue', 'LAB', 10),
                ('Raio-X', 'IMG', 15)
            `);

            // Menus
            // 1. Exames (Container)
            // 2. Consultas (Container)
            db.run(`INSERT INTO service_menus (label, order_index, icon) VALUES ('Exames', 1, 'flask'), ('Consultas', 2, 'user-md')`, function (err) {
                if (!err) {
                    const examesId = 1; // Assuming ID 1
                    const consultasId = 2; // Assuming ID 2

                    // Submenus
                    db.run(`INSERT INTO service_menus (parent_id, label, service_id, order_index) VALUES 
                        (${examesId}, 'Sangue', 3, 1),
                        (${examesId}, 'Raio-X', 4, 2),
                        (${consultasId}, 'Clínico Geral', 2, 1),
                        (${consultasId}, 'Triagem Rápida', 1, 2)
                    `);
                }
            });

            // Rooms
            db.run(`INSERT INTO rooms (name, type) VALUES 
                ('Recepção 1', 'RECEPTION'),
                ('Consultório 1', 'OFFICE'),
                ('Consultório 2', 'OFFICE'),
                ('Sala de Coleta', 'LAB'),
                ('Sala de Raio-X', 'IMG')
            `);

            // Room Services Mapping
            // Recepção -> Triagem
            // Consultório 1 -> Consulta Geral
            // Consultório 2 -> Consulta Geral
            // Sala de Coleta -> Exame de Sangue
            // Sala de Raio-X -> Raio-X
            setTimeout(() => {
                db.run(`INSERT INTO room_services (room_id, service_id) VALUES 
                    (1, 1), 
                    (2, 2), 
                    (3, 2), 
                    (4, 3), 
                    (5, 4)
                `);
            }, 1000);

            console.log("Seed data inserted.");
        } else {
            console.log("Database already seeded.");
        }
    });
};

db.serialize(() => {
    db.exec(schema, (err) => {
        if (err) {
            console.error("Error creating schema:", err);
        } else {
            console.log("Schema created successfully.");
            seedData();
        }
    });
});

module.exports = db;
