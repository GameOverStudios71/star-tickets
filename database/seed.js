/**
 * Script de Seed - Gera dados de teste para o Star Tickets
 * Cria tickets em diferentes status do fluxo completo
 * 
 * Uso: node database/seed.js
 */

const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.resolve(__dirname, 'star-tickets.db');
const db = new sqlite3.Database(dbPath);

// Nomes brasileiros aleatórios para clientes
const firstNames = [
    'João', 'Maria', 'José', 'Ana', 'Pedro', 'Paula', 'Carlos', 'Carla',
    'Lucas', 'Juliana', 'Rafael', 'Fernanda', 'Marcelo', 'Patricia', 'Bruno',
    'Camila', 'Diego', 'Amanda', 'Felipe', 'Bruna', 'Thiago', 'Letícia',
    'Rodrigo', 'Gabriela', 'André', 'Larissa', 'Eduardo', 'Natália', 'Gustavo',
    'Mariana', 'Ricardo', 'Carolina', 'Fernando', 'Raquel', 'Daniel', 'Vanessa'
];

const lastNames = [
    'Silva', 'Santos', 'Oliveira', 'Souza', 'Rodrigues', 'Ferreira', 'Alves',
    'Pereira', 'Lima', 'Gomes', 'Costa', 'Ribeiro', 'Martins', 'Carvalho',
    'Almeida', 'Lopes', 'Soares', 'Fernandes', 'Vieira', 'Barbosa', 'Rocha'
];

const healthInsurances = [
    null, null, null,
    'Bradesco Saúde', 'SulAmérica', 'Unimed', 'Amil', 'NotreDame Intermédica'
];

// Status possíveis no fluxo
const TICKET_STATUSES = {
    WAITING_RECEPTION: 'WAITING_RECEPTION',
    CALLED_RECEPTION: 'CALLED_RECEPTION',
    IN_RECEPTION: 'IN_RECEPTION',
    WAITING_PROFESSIONAL: 'WAITING_PROFESSIONAL',
    DONE: 'DONE',
    CANCELED: 'CANCELED'
};

const SERVICE_STATUSES = {
    PENDING: 'PENDING',
    CALLED: 'CALLED',
    IN_PROGRESS: 'IN_PROGRESS',
    COMPLETED: 'COMPLETED'
};

// Helpers
function randomItem(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
}

function randomInt(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomName() {
    return `${randomItem(firstNames)} ${randomItem(lastNames)}`;
}

function randomDateTime(hoursAgo = 8) {
    const now = new Date();
    const msAgo = randomInt(0, hoursAgo * 60 * 60 * 1000);
    return new Date(now.getTime() - msAgo).toISOString().replace('T', ' ').substring(0, 19);
}

// Main seed function
async function seed() {
    console.log('🌱 Iniciando seed de dados de teste...\n');

    // Limpar tickets existentes de hoje
    await run(`DELETE FROM ticket_services WHERE ticket_id IN (SELECT id FROM tickets WHERE date(created_at, 'localtime') = date('now', 'localtime'))`);
    await run(`DELETE FROM tickets WHERE date(created_at, 'localtime') = date('now', 'localtime')`);
    console.log('🗑️ Tickets de hoje limpos\n');

    // Buscar dados existentes
    const establishments = await query('SELECT * FROM establishments');
    const receptionDesks = await query('SELECT * FROM reception_desks');

    // Buscar serviços que estão vinculados a salas (importante!)
    const servicesWithRooms = await query(`
        SELECT DISTINCT s.*, rs.room_id
        FROM services s
        JOIN room_services rs ON s.id = rs.service_id
        JOIN rooms r ON rs.room_id = r.id
        WHERE r.is_active = 1
    `);

    console.log(`📊 Estabelecimentos: ${establishments.length}`);
    console.log(`📊 Serviços com salas: ${servicesWithRooms.length}`);
    console.log(`📊 Mesas de Recepção: ${receptionDesks.length}\n`);

    if (servicesWithRooms.length === 0) {
        console.log('❌ Nenhum serviço vinculado a salas! Configure room_services primeiro.');
        db.close();
        return;
    }

    const TOTAL_TICKETS = 60;
    const prefixCounters = {};

    // Distribuição fixa de status para testes
    const statusList = [
        // Aguardando recepção (10)
        ...Array(10).fill(TICKET_STATUSES.WAITING_RECEPTION),
        // Chamado recepção (5)
        ...Array(5).fill(TICKET_STATUSES.CALLED_RECEPTION),
        // Em atendimento recepção (5)
        ...Array(5).fill(TICKET_STATUSES.IN_RECEPTION),
        // Aguardando profissional (25) - MAIORIA para testar fila
        ...Array(25).fill(TICKET_STATUSES.WAITING_PROFESSIONAL),
        // Finalizados (12)
        ...Array(12).fill(TICKET_STATUSES.DONE),
        // Cancelados (3)
        ...Array(3).fill(TICKET_STATUSES.CANCELED)
    ];

    console.log(`📝 Gerando ${TOTAL_TICKETS} tickets...\n`);

    for (let i = 0; i < TOTAL_TICKETS; i++) {
        const establishment = establishments[i % establishments.length]; // Distribui entre estabelecimentos
        const status = statusList[i] || TICKET_STATUSES.WAITING_PROFESSIONAL;
        const isPriority = Math.random() < 0.2 ? 1 : 0;
        const healthInsurance = randomItem(healthInsurances);
        const createdAt = randomDateTime(6);

        // Buscar salas do estabelecimento
        const estRooms = await query(`SELECT r.id FROM rooms r WHERE r.establishment_id = ? AND r.is_active = 1`, [establishment.id]);
        if (estRooms.length === 0) continue;

        // Buscar serviços vinculados às salas deste estabelecimento
        const estServices = servicesWithRooms.filter(s =>
            estRooms.some(r => r.id === s.room_id)
        );

        if (estServices.length === 0) continue;

        const service = randomItem(estServices);

        // Gerar display_code
        const prefix = service.prefix;
        prefixCounters[prefix] = (prefixCounters[prefix] || 0) + 1;
        const displayCode = `${prefix}${String(prefixCounters[prefix]).padStart(3, '0')}`;

        // Nome do cliente (SEMPRE preenchido para aparecer na fila)
        const customerName = randomName();

        // Mesa de recepção
        let deskId = null;
        if (status !== TICKET_STATUSES.WAITING_RECEPTION) {
            const estDesks = receptionDesks.filter(d => d.establishment_id === establishment.id);
            if (estDesks.length > 0) {
                deskId = randomItem(estDesks).id;
            }
        }

        // Inserir ticket
        const ticketId = await insert(
            `INSERT INTO tickets (display_code, created_at, status, temp_customer_name, health_insurance_name, is_priority, establishment_id, reception_desk_id)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
            [displayCode, createdAt, status, customerName, healthInsurance, isPriority, establishment.id, deskId]
        );

        // Inserir serviço do ticket
        let serviceStatus = SERVICE_STATUSES.PENDING;
        if (status === TICKET_STATUSES.DONE) {
            serviceStatus = SERVICE_STATUSES.COMPLETED;
        } else if (status === TICKET_STATUSES.WAITING_PROFESSIONAL) {
            // Variação para testar diferentes estados na fila
            const r = Math.random();
            if (r < 0.7) serviceStatus = SERVICE_STATUSES.PENDING;
            else if (r < 0.85) serviceStatus = SERVICE_STATUSES.CALLED;
            else serviceStatus = SERVICE_STATUSES.IN_PROGRESS;
        }

        await insert(
            `INSERT INTO ticket_services (ticket_id, service_id, order_sequence, status, created_at)
             VALUES (?, ?, ?, ?, ?)`,
            [ticketId, service.id, 1, serviceStatus, createdAt]
        );
    }

    // Estatísticas finais
    console.log('📊 Estatísticas geradas:');

    const stats = await query(`
        SELECT status, COUNT(*) as count 
        FROM tickets 
        WHERE date(created_at, 'localtime') = date('now', 'localtime')
        GROUP BY status
        ORDER BY status
    `);

    stats.forEach(s => {
        console.log(`   ${s.status}: ${s.count} tickets`);
    });

    // Verificar fila do profissional
    const queueCount = await query(`
        SELECT COUNT(*) as count
        FROM ticket_services ts
        JOIN tickets t ON ts.ticket_id = t.id
        WHERE ts.status = 'PENDING'
        AND t.status = 'WAITING_PROFESSIONAL'
        AND t.temp_customer_name IS NOT NULL
        AND date(t.created_at, 'localtime') = date('now', 'localtime')
    `);

    console.log(`\n   📋 Tickets na fila do profissional: ${queueCount[0].count}`);

    console.log('\n✅ Seed concluído com sucesso!');
    db.close();
}

// Database helpers
function query(sql, params = []) {
    return new Promise((resolve, reject) => {
        db.all(sql, params, (err, rows) => {
            if (err) reject(err);
            else resolve(rows);
        });
    });
}

function insert(sql, params = []) {
    return new Promise((resolve, reject) => {
        db.run(sql, params, function (err) {
            if (err) reject(err);
            else resolve(this.lastID);
        });
    });
}

function run(sql, params = []) {
    return new Promise((resolve, reject) => {
        db.run(sql, params, function (err) {
            if (err) reject(err);
            else resolve(this.changes);
        });
    });
}

// Run
seed().catch(err => {
    console.error('❌ Erro no seed:', err);
    db.close();
    process.exit(1);
});
