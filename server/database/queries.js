/**
 * Módulo de Queries Centralizadas
 * Centraliza consultas SQL repetidas para facilitar manutenção
 */

// ============== HELPERS ==============

/**
 * Adiciona filtro de establishment_id a uma query
 * @param {string} column - Coluna para filtrar (ex: 't.establishment_id')
 * @param {number|null} establishmentId - ID do estabelecimento
 * @returns {{ clause: string, params: any[] }}
 */
function addEstablishmentFilter(column, establishmentId) {
    if (!establishmentId) {
        return { clause: '', params: [] };
    }
    return {
        clause: ` AND ${column} = ?`,
        params: [establishmentId]
    };
}

/**
 * Handler padrão de erro para respostas
 */
function handleDbError(res, err) {
    return res.status(500).json({ error: err.message });
}

/**
 * Handler padrão para item não encontrado ou sem permissão
 */
function handleNotFound(res, message = 'Não encontrado ou sem permissão') {
    return res.status(403).json({ error: message });
}

// ============== TICKET QUERIES ==============

const ticketQueries = {
    /**
     * Query para listar tickets do dia
     */
    listTodayTickets(establishmentId, options = {}) {
        const { excludeStatus = ['DONE', 'CANCELED'] } = options;

        let query = `
            SELECT t.*, c.name as customer_name, 
            rd.name as attending_desk_name,
            (SELECT group_concat(s.name, ', ') FROM ticket_services ts JOIN services s ON ts.service_id = s.id WHERE ts.ticket_id = t.id) as services_list
            FROM tickets t
            LEFT JOIN customers c ON t.customer_id = c.id
            LEFT JOIN reception_desks rd ON t.reception_desk_id = rd.id
            WHERE ${excludeStatus.map(() => 't.status != ?').join(' AND ')}
            AND date(t.created_at, 'localtime') = date('now', 'localtime')
        `;
        const params = [...excludeStatus];

        if (establishmentId) {
            query += ` AND t.establishment_id = ?`;
            params.push(establishmentId);
        }
        query += ` ORDER BY t.created_at DESC`;

        return { query, params };
    },

    /**
     * Query para buscar ticket por ID com verificação de ownership
     */
    getTicketById(ticketId, establishmentId) {
        let query = `SELECT * FROM tickets WHERE id = ?`;
        const params = [ticketId];

        if (establishmentId) {
            query += ` AND establishment_id = ?`;
            params.push(establishmentId);
        }

        return { query, params };
    },

    /**
     * Query para verificar ownership de ticket
     */
    verifyTicketOwnership(ticketId, establishmentId) {
        let query = `SELECT id FROM tickets WHERE id = ?`;
        const params = [ticketId];

        if (establishmentId) {
            query += ` AND establishment_id = ?`;
            params.push(establishmentId);
        }

        return { query, params };
    },

    /**
     * Query para atualizar ticket com verificação de ownership
     */
    updateTicket(ticketId, field, value, establishmentId) {
        let query = `UPDATE tickets SET ${field} = ? WHERE id = ?`;
        const params = [value, ticketId];

        if (establishmentId) {
            query += ` AND establishment_id = ?`;
            params.push(establishmentId);
        }

        return { query, params };
    },

    /**
     * Query para buscar ticket com display_code e status
     */
    getTicketWithStatus(ticketId, establishmentId) {
        let query = `
            SELECT t.display_code, t.temp_customer_name, t.status
            FROM tickets t
            WHERE t.id = ?
        `;
        const params = [ticketId];

        if (establishmentId) {
            query += ` AND t.establishment_id = ?`;
            params.push(establishmentId);
        }

        return { query, params };
    }
};

// ============== TICKET SERVICE QUERIES ==============

const ticketServiceQueries = {
    /**
     * Verifica ownership de um ticket_service
     */
    verifyOwnership(ticketServiceId, establishmentId) {
        let query = `
            SELECT ts.id, ts.ticket_id, ts.status
            FROM ticket_services ts
            JOIN tickets t ON ts.ticket_id = t.id
            WHERE ts.id = ?
        `;
        const params = [ticketServiceId];

        if (establishmentId) {
            query += ` AND t.establishment_id = ?`;
            params.push(establishmentId);
        }

        return { query, params };
    },

    /**
     * Lista serviços de um ticket
     */
    getByTicket(ticketId) {
        const query = `
            SELECT ts.id, ts.status, ts.order_sequence, s.name as service_name, s.id as service_id
            FROM ticket_services ts
            JOIN services s ON ts.service_id = s.id
            WHERE ts.ticket_id = ?
            ORDER BY ts.order_sequence
        `;
        return { query, params: [ticketId] };
    },

    /**
     * Query para buscar info de chamada de ticket
     */
    getCallInfo(ticketServiceId, roomId, establishmentId) {
        let query = `
            SELECT t.display_code, t.temp_customer_name, t.establishment_id, r.name as room_name 
            FROM ticket_services ts
            JOIN tickets t ON ts.ticket_id = t.id
            JOIN room_services rs ON rs.service_id = ts.service_id
            JOIN rooms r ON rs.room_id = r.id
            WHERE ts.id = ? AND r.id = ?
        `;
        const params = [ticketServiceId, roomId];

        if (establishmentId) {
            query += ` AND t.establishment_id = ?`;
            params.push(establishmentId);
        }

        return { query, params };
    }
};

// ============== ROOM QUERIES ==============

const roomQueries = {
    /**
     * Lista rooms com filtro de establishment
     */
    list(establishmentId) {
        let query = `SELECT * FROM rooms WHERE 1=1`;
        const params = [];

        if (establishmentId) {
            query += ` AND establishment_id = ?`;
            params.push(establishmentId);
        }
        query += ` ORDER BY name`;

        return { query, params };
    },

    /**
     * Verifica ownership de room
     */
    verifyOwnership(roomId, establishmentId) {
        let query = `SELECT id FROM rooms WHERE id = ?`;
        const params = [roomId];

        if (establishmentId) {
            query += ` AND establishment_id = ?`;
            params.push(establishmentId);
        }

        return { query, params };
    },

    /**
     * Query para fila de espera de uma sala
     */
    getQueue(roomId, establishmentId) {
        let query = `
            SELECT ts.id as ticket_service_id, t.id as ticket_id, t.display_code, 
                   t.temp_customer_name, t.is_priority, s.name as service_name
            FROM ticket_services ts
            JOIN tickets t ON ts.ticket_id = t.id
            JOIN services s ON ts.service_id = s.id
            JOIN room_services rs ON rs.service_id = s.id
            WHERE rs.room_id = ?
            AND ts.status = 'PENDING'
            AND t.status = 'WAITING_PROFESSIONAL'
            AND t.temp_customer_name IS NOT NULL
            AND t.temp_customer_name != ''
            AND date(t.created_at, 'localtime') = date('now', 'localtime')
            AND NOT EXISTS (
                SELECT 1 FROM ticket_services ts_prev 
                WHERE ts_prev.ticket_id = ts.ticket_id 
                AND ts_prev.order_sequence < ts.order_sequence 
                AND ts_prev.status != 'COMPLETED'
            )
        `;
        const params = [roomId];

        if (establishmentId) {
            query += ` AND t.establishment_id = ?`;
            params.push(establishmentId);
        }
        query += ` ORDER BY t.is_priority DESC, ts.created_at ASC`;

        return { query, params };
    },

    /**
     * Overview de salas com contagem de espera (para manager)
     */
    getOverview(establishmentId) {
        let query = `
            SELECT r.id, r.name, r.establishment_id, COUNT(t.id) as waiting_count
            FROM rooms r
            LEFT JOIN room_services rs ON r.id = rs.room_id
            LEFT JOIN ticket_services ts ON rs.service_id = ts.service_id AND ts.status = 'PENDING'
            LEFT JOIN tickets t ON ts.ticket_id = t.id 
                AND t.status = 'WAITING_PROFESSIONAL' 
                AND date(t.created_at, 'localtime') = date('now', 'localtime')
                AND NOT EXISTS (
                    SELECT 1 FROM ticket_services ts_prev 
                    WHERE ts_prev.ticket_id = ts.ticket_id 
                    AND ts_prev.order_sequence < ts.order_sequence 
                    AND ts_prev.status != 'COMPLETED'
                )
            WHERE 1=1
        `;
        const params = [];

        if (establishmentId) {
            query += ` AND r.establishment_id = ?`;
            params.push(establishmentId);
        }
        query += ` GROUP BY r.id`;

        return { query, params };
    }
};

// ============== SERVICE QUERIES ==============

const serviceQueries = {
    /**
     * Lista serviços com filtro de establishment
     */
    list(establishmentId) {
        let query = `SELECT * FROM services WHERE 1=1`;
        const params = [];

        if (establishmentId) {
            query += ` AND (establishment_id = ? OR establishment_id IS NULL)`;
            params.push(establishmentId);
        }
        query += ` ORDER BY name`;

        return { query, params };
    },

    /**
     * Verifica ownership de serviço (global ou do establishment)
     */
    verifyOwnership(serviceId, establishmentId, isAdmin) {
        let query = `SELECT id FROM services WHERE id = ?`;
        const params = [serviceId];

        if (establishmentId && !isAdmin) {
            query += ` AND (establishment_id = ? OR establishment_id IS NULL)`;
            params.push(establishmentId);
        }

        return { query, params };
    }
};

// ============== USER QUERIES ==============

const userQueries = {
    /**
     * Lista usuários com filtro de establishment
     */
    list(establishmentId, isAdmin) {
        let query = `SELECT id, name, username, role, establishment_id FROM users WHERE 1=1`;
        const params = [];

        if (establishmentId) {
            query += ` AND establishment_id = ?`;
            params.push(establishmentId);
        }
        query += ` ORDER BY name`;

        return { query, params };
    }
};

// ============== RECEPTION DESK QUERIES ==============

const receptionDeskQueries = {
    /**
     * Lista mesas de recepção ativas
     */
    listActive(establishmentId) {
        let query = `SELECT * FROM reception_desks WHERE is_active = 1`;
        const params = [];

        if (establishmentId) {
            query += ` AND establishment_id = ?`;
            params.push(establishmentId);
        }
        query += ` ORDER BY name`;

        return { query, params };
    }
};

// ============== CALLED TICKETS QUERIES ==============

const calledTicketQueries = {
    /**
     * Lista tickets chamados (para TV)
     */
    list(establishmentId) {
        let query = `
            SELECT DISTINCT
                t.display_code,
                t.temp_customer_name,
                CASE 
                    WHEN t.status = 'CALLED_RECEPTION' THEN COALESCE(rd.name, 'RECEPÇÃO')
                    ELSE r.name
                END as room_name,
                COALESCE(ts.created_at, t.created_at) as created_at
            FROM tickets t
            LEFT JOIN reception_desks rd ON t.reception_desk_id = rd.id
            LEFT JOIN ticket_services ts ON ts.ticket_id = t.id AND ts.status = 'CALLED'
            LEFT JOIN room_services rs ON rs.service_id = ts.service_id
            LEFT JOIN rooms r ON rs.room_id = r.id
            WHERE (t.status = 'CALLED_RECEPTION' OR ts.status = 'CALLED')
            AND date(t.created_at, 'localtime') = date('now', 'localtime')
        `;
        const params = [];

        if (establishmentId) {
            query += ` AND t.establishment_id = ?`;
            params.push(establishmentId);
        }
        query += ` ORDER BY created_at ASC`;

        return { query, params };
    }
};

// ============== EXPORTS ==============

module.exports = {
    // Helpers
    addEstablishmentFilter,
    handleDbError,
    handleNotFound,

    // Query builders
    ticketQueries,
    ticketServiceQueries,
    roomQueries,
    serviceQueries,
    userQueries,
    receptionDeskQueries,
    calledTicketQueries
};
