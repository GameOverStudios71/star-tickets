const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.resolve(__dirname, '../database/star-tickets.db');
const db = new sqlite3.Database(dbPath);

console.log('🔧 Fixing menu mappings and creating test data...');

db.serialize(() => {
    // Fix incorrect service mappings in menus
    db.run("UPDATE service_menus SET service_id = NULL WHERE label IN ('Sangue', 'Raio-X')");

    // Create proper service menu items
    db.run("DELETE FROM service_menus WHERE id IN (4, 5)");
    db.run(`INSERT INTO service_menus (id, label, parent_id, service_id, order_index, establishment_id) VALUES 
        (4, 'Exames de Sangue', 2, 3, 1, 1),
        (5, 'Raio-X Torácico', 2, 21, 2, 1),
        (6, 'Cardiológicos', 2, 4, 3, 1)`);

    // Create test tickets with multiple services to demonstrate bulk move
    // Ticket 1: Will be in Room 1, needs Room 2
    db.run(`INSERT INTO tickets (display_code, status, temp_customer_name, is_priority, establishment_id) 
            VALUES ('TEST001', 'WAITING_PROFESSIONAL', 'João Silva', 0, 1)`, function () {
        const ticketId1 = this.lastID;
        db.run(`INSERT INTO ticket_services (ticket_id, service_id, order_sequence, status) VALUES 
            (?, 2, 1, 'PENDING'),
            (?, 3, 2, 'PENDING')`, [ticketId1, ticketId1]);
    });

    // Ticket 2: Will be in Room 1, needs Room 2
    db.run(`INSERT INTO tickets (display_code, status, temp_customer_name, is_priority, establishment_id) 
            VALUES ('TEST002', 'WAITING_PROFESSIONAL', 'Maria Santos', 0, 1)`, function () {
        const ticketId2 = this.lastID;
        db.run(`INSERT INTO ticket_services (ticket_id, service_id, order_sequence, status) VALUES 
            (?, 2, 1, 'PENDING'),
            (?, 4, 2, 'PENDING')`, [ticketId2, ticketId2]);
    });

    // Ticket 3: Will be in Room 2, needs Room 1  
    db.run(`INSERT INTO tickets (display_code, status, temp_customer_name, is_priority, establishment_id)
            VALUES ('TEST003', 'WAITING_PROFESSIONAL', 'Pedro Costa', 0, 1)`, function () {
        const ticketId3 = this.lastID;
        db.run(`INSERT INTO ticket_services (ticket_id, service_id, order_sequence, status) VALUES 
            (?, 3, 1, 'PENDING'),
            (?, 2, 2, 'PENDING')`, [ticketId3, ticketId3]);
    });

    console.log('✅ Menu mappings fixed!');
    console.log('✅ Test tickets created!');
    console.log('');
    console.log('Test data created:');
    console.log('  - TEST001 (João): Sala 1 (Análises) → Sala 2 (ATP)');
    console.log('  - TEST002 (Maria): Sala 1 (Análises) → Sala 2 (Cardiológicos)');
    console.log('  - TEST003 (Pedro): Sala 2 (ATP) → Sala 1 (Análises)');
    console.log('');
    console.log('Now select Sala 2 in manager to see João and Maria as candidates!');

    db.close();
});
