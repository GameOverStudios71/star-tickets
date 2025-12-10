/**
 * Script de Seed - Gera dados de teste para o Star Tickets
 * Cria 500 tickets em diferentes status do fluxo completo
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
    'Almeida', 'Lopes', 'Soares', 'Fernandes', 'Vieira', 'Barbosa', 'Rocha',
    'Dias', 'Nascimento', 'Andrade', 'Moreira', 'Nunes', 'Marques', 'Machado'
];

const healthInsurances = [
    null, null, null, // Particular (mais comum)
    'Bradesco Saúde', 'SulAmérica', 'Unimed', 'Amil', 'NotreDame Intermédica',
    'Porto Seguro Saúde', 'Golden Cross', 'Hapvida', 'Prevent Senior'
];

// Status possíveis no fluxo
const TICKET_STATUSES = {
    WAITING_RECEPTION: 'WAITING_RECEPTION',      // Aguardando na recepção
    CALLED_RECEPTION: 'CALLED_RECEPTION',        // Chamado para recepção
    IN_RECEPTION: 'IN_RECEPTION',                // Em atendimento na recepção
    WAITING_PROFESSIONAL: 'WAITING_PROFESSIONAL', // Aguardando profissional
    DONE: 'DONE',                                 // Finalizado
    CANCELED: 'CANCELED'                          // Cancelado
};

const SERVICE_STATUSES = {
    PENDING: 'PENDING',
    CALLED: 'CALLED',
    IN_PROGRESS: 'IN_PROGRESS',
    COMPLETED: 'COMPLETED'
};

// Distribuição de status (peso para cada status)
const statusDistribution = [
    { status: TICKET_STATUSES.WAITING_RECEPTION, weight: 25 },
    { status: TICKET_STATUSES.CALLED_RECEPTION, weight: 10 },
    { status: TICKET_STATUSES.IN_RECEPTION, weight: 10 },
    { status: TICKET_STATUSES.WAITING_PROFESSIONAL, weight: 35 },
    { status: TICKET_STATUSES.DONE, weight: 15 },
    { status: TICKET_STATUSES.CANCELED, weight: 5 }
];

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

function weightedRandomStatus() {
    const totalWeight = statusDistribution.reduce((sum, s) => sum + s.weight, 0);
    let random = Math.random() * totalWeight;

    for (const item of statusDistribution) {
        random -= item.weight;
        if (random <= 0) return item.status;
    }
    return TICKET_STATUSES.WAITING_RECEPTION;
}

function randomDateTime(hoursAgo = 8) {
    const now = new Date();
    const msAgo = randomInt(0, hoursAgo * 60 * 60 * 1000);
    return new Date(now.getTime() - msAgo).toISOString().replace('T', ' ').substring(0, 19);
}

// Main seed function
async function seed() {
    console.log('🌱 Iniciando seed de dados de teste...\n');

    // Buscar dados existentes
    const establishments = await query('SELECT * FROM establishments');
    const services = await query('SELECT * FROM services');
    const receptionDesks = await query('SELECT * FROM reception_desks');

    console.log(`📊 Estabelecimentos: ${establishments.length}`);
    console.log(`📊 Serviços: ${services.length}`);
    console.log(`📊 Mesas de Recepção: ${receptionDesks.length}`);
    console.log('');

    const TOTAL_TICKETS = 500;
    const prefixCounters = {}; // Para gerar códigos únicos

    console.log(`📝 Gerando ${TOTAL_TICKETS} tickets...\n`);

    for (let i = 0; i < TOTAL_TICKETS; i++) {
        const establishment = randomItem(establishments);
        const status = weightedRandomStatus();
        const isPriority = Math.random() < 0.15 ? 1 : 0; // 15% prioritário
        const healthInsurance = randomItem(healthInsurances);
        const createdAt = randomDateTime(10); // Últimas 10 horas

        // Selecionar 1-3 serviços aleatórios
        const numServices = randomInt(1, 3);
        const selectedServices = [];
        for (let j = 0; j < numServices; j++) {
            const service = randomItem(services);
            if (!selectedServices.find(s => s.id === service.id)) {
                selectedServices.push(service);
            }
        }

        if (selectedServices.length === 0) {
            selectedServices.push(randomItem(services));
        }

        // Gerar display_code
        const prefix = selectedServices[0].prefix;
        prefixCounters[prefix] = (prefixCounters[prefix] || 0) + 1;
        const displayCode = `${prefix}${String(prefixCounters[prefix]).padStart(3, '0')}`;

        // Nome do cliente (exceto para WAITING_RECEPTION sem atendimento)
        let customerName = null;
        if (status !== TICKET_STATUSES.WAITING_RECEPTION || Math.random() < 0.3) {
            customerName = randomName();
        }

        // Mesa de recepção (se já passou pela recepção)
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

        // Inserir serviços do ticket
        for (let j = 0; j < selectedServices.length; j++) {
            const service = selectedServices[j];
            let serviceStatus = SERVICE_STATUSES.PENDING;

            // Definir status do serviço baseado no status do ticket
            if (status === TICKET_STATUSES.DONE) {
                serviceStatus = SERVICE_STATUSES.COMPLETED;
            } else if (status === TICKET_STATUSES.WAITING_PROFESSIONAL) {
                if (j === 0) {
                    // Primeiro serviço pode estar pending, called ou in_progress
                    const r = Math.random();
                    if (r < 0.6) serviceStatus = SERVICE_STATUSES.PENDING;
                    else if (r < 0.8) serviceStatus = SERVICE_STATUSES.CALLED;
                    else serviceStatus = SERVICE_STATUSES.IN_PROGRESS;
                } else {
                    // Serviços posteriores
                    if (Math.random() < 0.3) {
                        serviceStatus = SERVICE_STATUSES.COMPLETED; // Alguns já finalizados
                    }
                }
            }

            await insert(
                `INSERT INTO ticket_services (ticket_id, service_id, order_sequence, status, created_at)
                 VALUES (?, ?, ?, ?, ?)`,
                [ticketId, service.id, j + 1, serviceStatus, createdAt]
            );
        }

        // Progresso
        if ((i + 1) % 50 === 0) {
            console.log(`  ✓ ${i + 1}/${TOTAL_TICKETS} tickets criados...`);
        }
    }

    // Estatísticas finais
    console.log('\n📊 Estatísticas geradas:');

    const stats = await query(`
        SELECT status, COUNT(*) as count 
        FROM tickets 
        WHERE date(created_at, 'localtime') = date('now', 'localtime')
        GROUP BY status
    `);

    stats.forEach(s => {
        console.log(`   ${s.status}: ${s.count} tickets`);
    });

    const totalServices = await query(`SELECT COUNT(*) as count FROM ticket_services`);
    console.log(`\n   Total de serviços vinculados: ${totalServices[0].count}`);

    console.log('\n✅ Seed concluído com sucesso!');
    db.close();
}

// Database helpers (promisified)
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

// Run
seed().catch(err => {
    console.error('❌ Erro no seed:', err);
    db.close();
    process.exit(1);
});
