// Tab Navigation
document.querySelectorAll('.nav-link').forEach(link => {
    link.addEventListener('click', (e) => {
        e.preventDefault();
        const tab = link.dataset.tab;

        // Update active states
        document.querySelectorAll('.nav-link').forEach(l => l.classList.remove('active'));
        document.querySelectorAll('.tabs').forEach(t => t.classList.remove('active'));

        link.classList.add('active');
        document.getElementById(tab).classList.add('active');

        // Load data for the tab
        loadTabData(tab);
    });
});

function loadTabData(tab) {
    switch (tab) {
        case 'dashboard':
            loadDashboard();
            break;
        case 'services':
            loadServices();
            break;
        case 'rooms':
            loadRooms();
            break;
        case 'menus':
            loadMenus();
            break;
        case 'users':
            loadUsers();
            break;
        case 'reports':
            loadReports();
            break;
    }
}

// ==================== DASHBOARD ====================
async function loadDashboard() {
    // Load stats
    const services = await fetch('/api/admin/services').then(r => r.json());
    const rooms = await fetch('/api/admin/rooms').then(r => r.json());
    const users = await fetch('/api/admin/users').then(r => r.json());
    const tickets = await fetch('/api/tickets').then(r => r.json());

    document.getElementById('stat-services').innerText = services.length;
    document.getElementById('stat-rooms').innerText = rooms.filter(r => r.is_active).length;
    document.getElementById('stat-users').innerText = users.length;
    document.getElementById('stat-tickets-today').innerText = tickets.length;
}

// ==================== SERVICES ====================
async function loadServices() {
    const services = await fetch('/api/admin/services').then(r => r.json());
    const tbody = document.querySelector('#services-table tbody');
    tbody.innerHTML = '';

    services.forEach(s => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>${s.id}</td>
            <td>${s.name}</td>
            <td>${s.prefix}</td>
            <td>${s.average_time_minutes}</td>
            <td>
                <button class="btn action-btn" onclick="editService(${s.id})">Editar</button>
                <button class="btn btn-accent action-btn" onclick="deleteService(${s.id})">Excluir</button>
            </td>
        `;
        tbody.appendChild(tr);
    });
}

function openServiceModal(id = null) {
    document.getElementById('service-modal').classList.add('active');
    document.getElementById('service-form').reset();
    document.getElementById('service-id').value = '';
    document.getElementById('service-modal-title').innerText = 'Novo Serviço';

    if (id) {
        fetch(`/api/admin/services`).then(r => r.json()).then(services => {
            const service = services.find(s => s.id === id);
            if (service) {
                document.getElementById('service-id').value = service.id;
                document.getElementById('service-name').value = service.name;
                document.getElementById('service-prefix').value = service.prefix;
                document.getElementById('service-time').value = service.average_time_minutes;
                document.getElementById('service-description').value = service.description || '';
                document.getElementById('service-modal-title').innerText = 'Editar Serviço';
            }
        });
    }
}

function editService(id) {
    openServiceModal(id);
}

async function deleteService(id) {
    if (!confirm('Tem certeza que deseja excluir este serviço?')) return;

    try {
        const res = await fetch(`/api/admin/services/${id}`, { method: 'DELETE' });
        const data = await res.json();
        if (data.error) {
            alert(data.error);
        } else {
            loadServices();
        }
    } catch (e) {
        alert('Erro ao excluir serviço');
    }
}

document.getElementById('service-form').addEventListener('submit', async (e) => {
    e.preventDefault();

    const id = document.getElementById('service-id').value;
    const data = {
        name: document.getElementById('service-name').value,
        prefix: document.getElementById('service-prefix').value,
        average_time_minutes: parseInt(document.getElementById('service-time').value),
        description: document.getElementById('service-description').value
    };

    const url = id ? `/api/admin/services/${id}` : '/api/admin/services';
    const method = id ? 'PUT' : 'POST';

    await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    });

    closeModal('service-modal');
    loadServices();
});

// ==================== ROOMS ====================
async function loadRooms() {
    const rooms = await fetch('/api/admin/rooms').then(r => r.json());
    const tbody = document.querySelector('#rooms-table tbody');
    tbody.innerHTML = '';

    rooms.forEach(r => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>${r.id}</td>
            <td>${r.name}</td>
            <td>${r.type || '-'}</td>
            <td>${r.is_active ? 'Ativa' : 'Inativa'}</td>
            <td>
                <button class="btn action-btn" onclick="editRoom(${r.id})">Editar</button>
                <button class="btn btn-accent action-btn" onclick="deleteRoom(${r.id})">Excluir</button>
            </td>
        `;
        tbody.appendChild(tr);
    });
}

function openRoomModal(id = null) {
    document.getElementById('room-modal').classList.add('active');
    document.getElementById('room-form').reset();
    document.getElementById('room-id').value = '';
    document.getElementById('room-modal-title').innerText = 'Nova Sala';

    if (id) {
        fetch(`/api/admin/rooms`).then(r => r.json()).then(rooms => {
            const room = rooms.find(r => r.id === id);
            if (room) {
                document.getElementById('room-id').value = room.id;
                document.getElementById('room-name').value = room.name;
                document.getElementById('room-type').value = room.type || '';
                document.getElementById('room-active').checked = room.is_active;
                document.getElementById('room-modal-title').innerText = 'Editar Sala';
            }
        });
    }
}

function editRoom(id) {
    openRoomModal(id);
}

async function deleteRoom(id) {
    if (!confirm('Tem certeza que deseja excluir esta sala?')) return;
    await fetch(`/api/admin/rooms/${id}`, { method: 'DELETE' });
    loadRooms();
}

document.getElementById('room-form').addEventListener('submit', async (e) => {
    e.preventDefault();

    const id = document.getElementById('room-id').value;
    const data = {
        name: document.getElementById('room-name').value,
        type: document.getElementById('room-type').value,
        is_active: document.getElementById('room-active').checked ? 1 : 0
    };

    const url = id ? `/api/admin/rooms/${id}` : '/api/admin/rooms';
    const method = id ? 'PUT' : 'POST';

    await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    });

    closeModal('room-modal');
    loadRooms();
});

// ==================== MENUS ====================
async function loadMenus() {
    const menus = await fetch('/api/admin/menus').then(r => r.json());
    const tbody = document.querySelector('#menus-table tbody');
    tbody.innerHTML = '';

    // Also populate service dropdown
    const services = await fetch('/api/admin/services').then(r => r.json());
    const select = document.getElementById('menu-service');
    select.innerHTML = '<option value="">-- Container --</option>';
    services.forEach(s => {
        const opt = document.createElement('option');
        opt.value = s.id;
        opt.innerText = s.name;
        select.appendChild(opt);
    });

    menus.forEach(m => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>${m.id}</td>
            <td>${m.label}</td>
            <td>${m.parent_id || '-'}</td>
            <td>${m.service_name || 'Container'}</td>
            <td>${m.order_index}</td>
            <td>
                <button class="btn action-btn" onclick="editMenu(${m.id})">Editar</button>
                <button class="btn btn-accent action-btn" onclick="deleteMenu(${m.id})">Excluir</button>
            </td>
        `;
        tbody.appendChild(tr);
    });
}

function openMenuModal(id = null) {
    document.getElementById('menu-modal').classList.add('active');
    document.getElementById('menu-form').reset();
    document.getElementById('menu-id').value = '';
    document.getElementById('menu-modal-title').innerText = 'Novo Item de Menu';

    if (id) {
        fetch(`/api/admin/menus`).then(r => r.json()).then(menus => {
            const menu = menus.find(m => m.id === id);
            if (menu) {
                document.getElementById('menu-id').value = menu.id;
                document.getElementById('menu-label').value = menu.label;
                document.getElementById('menu-parent').value = menu.parent_id || '';
                document.getElementById('menu-service').value = menu.service_id || '';
                document.getElementById('menu-order').value = menu.order_index;
                document.getElementById('menu-icon').value = menu.icon || '';
                document.getElementById('menu-modal-title').innerText = 'Editar Item de Menu';
            }
        });
    }
}

function editMenu(id) {
    openMenuModal(id);
}

async function deleteMenu(id) {
    if (!confirm('Tem certeza? Isso também excluirá itens filhos.')) return;
    await fetch(`/api/admin/menus/${id}`, { method: 'DELETE' });
    loadMenus();
}

document.getElementById('menu-form').addEventListener('submit', async (e) => {
    e.preventDefault();

    const id = document.getElementById('menu-id').value;
    const data = {
        label: document.getElementById('menu-label').value,
        parent_id: document.getElementById('menu-parent').value || null,
        service_id: document.getElementById('menu-service').value || null,
        order_index: parseInt(document.getElementById('menu-order').value),
        icon: document.getElementById('menu-icon').value
    };

    const url = id ? `/api/admin/menus/${id}` : '/api/admin/menus';
    const method = id ? 'PUT' : 'POST';

    await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    });

    closeModal('menu-modal');
    loadMenus();
});

// ==================== USERS ====================
async function loadUsers() {
    const users = await fetch('/api/admin/users').then(r => r.json());
    const tbody = document.querySelector('#users-table tbody');
    tbody.innerHTML = '';

    users.forEach(u => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>${u.id}</td>
            <td>${u.name}</td>
            <td>${u.username}</td>
            <td>${u.role}</td>
            <td>
                <button class="btn action-btn" onclick="editUser(${u.id})">Editar</button>
                <button class="btn btn-accent action-btn" onclick="deleteUser(${u.id})">Excluir</button>
            </td>
        `;
        tbody.appendChild(tr);
    });
}

function openUserModal(id = null) {
    document.getElementById('user-modal').classList.add('active');
    document.getElementById('user-form').reset();
    document.getElementById('user-id').value = '';
    document.getElementById('user-modal-title').innerText = 'Novo Usuário';

    if (id) {
        fetch(`/api/admin/users`).then(r => r.json()).then(users => {
            const user = users.find(u => u.id === id);
            if (user) {
                document.getElementById('user-id').value = user.id;
                document.getElementById('user-name').value = user.name;
                document.getElementById('user-username').value = user.username;
                document.getElementById('user-role').value = user.role;
                document.getElementById('user-password').value = '';
                document.getElementById('user-modal-title').innerText = 'Editar Usuário';
            }
        });
    }
}

function editUser(id) {
    openUserModal(id);
}

async function deleteUser(id) {
    if (!confirm('Tem certeza que deseja excluir este usuário?')) return;
    await fetch(`/api/admin/users/${id}`, { method: 'DELETE' });
    loadUsers();
}

document.getElementById('user-form').addEventListener('submit', async (e) => {
    e.preventDefault();

    const id = document.getElementById('user-id').value;
    const data = {
        name: document.getElementById('user-name').value,
        username: document.getElementById('user-username').value,
        role: document.getElementById('user-role').value
    };

    const password = document.getElementById('user-password').value;
    if (password) {
        data.password = password;
    }

    const url = id ? `/api/admin/users/${id}` : '/api/admin/users';
    const method = id ? 'PUT' : 'POST';

    await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    });

    closeModal('user-modal');
    loadUsers();
});

// ==================== REPORTS ====================
async function loadReports() {
    const ticketsData = await fetch('/api/admin/reports/tickets').then(r => r.json());
    const attendanceData = await fetch('/api/admin/reports/attendance').then(r => r.json());

    // Tickets Report
    const ticketsDiv = document.getElementById('tickets-report');
    ticketsDiv.innerHTML = '<table><thead><tr><th>Data</th><th>Total Senhas</th><th>Clientes Únicos</th></tr></thead><tbody></tbody></table>';
    const ticketsTbody = ticketsDiv.querySelector('tbody');
    ticketsData.forEach(t => {
        const tr = document.createElement('tr');
        tr.innerHTML = `<td>${t.date}</td><td>${t.total_tickets}</td><td>${t.unique_customers || 0}</td>`;
        ticketsTbody.appendChild(tr);
    });

    // Attendance Report
    const attendanceDiv = document.getElementById('attendance-report');
    attendanceDiv.innerHTML = '<table><thead><tr><th>Serviço</th><th>Total Atendimentos</th><th>Tempo Médio (min)</th></tr></thead><tbody></tbody></table>';
    const attendanceTbody = attendanceDiv.querySelector('tbody');
    attendanceData.forEach(a => {
        const tr = document.createElement('tr');
        tr.innerHTML = `<td>${a.service_name}</td><td>${a.total_attendances}</td><td>${a.avg_duration_minutes ? a.avg_duration_minutes.toFixed(1) : '-'}</td>`;
        attendanceTbody.appendChild(tr);
    });
}

// ==================== MODAL HELPERS ====================
function closeModal(modalId) {
    document.getElementById(modalId).classList.remove('active');
}

// Load dashboard on init
loadDashboard();
