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

// ==================== MODAL HELPERS ====================
function closeModal(modalId) {
    document.getElementById(modalId).classList.remove('active');
}

// Load dashboard on init
loadDashboard();
