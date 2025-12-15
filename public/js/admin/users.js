// ==================== USERS ====================
let allEstablishments = [];

async function loadEstablishments() {
    try {
        const res = await fetch('/api/admin/establishments');
        allEstablishments = await res.json();
    } catch (e) {
        console.error('Error loading establishments:', e);
        allEstablishments = [];
    }
}

function populateEstablishmentDropdown(selectedId = null) {
    const select = document.getElementById('user-establishment');
    if (!select) return;

    select.innerHTML = '<option value="">Selecione...</option>';
    allEstablishments.forEach(e => {
        const option = document.createElement('option');
        option.value = e.id;
        option.textContent = e.name;
        if (selectedId && e.id === selectedId) {
            option.selected = true;
        }
        select.appendChild(option);
    });
}

async function loadUsers() {
    // Ensure establishments are loaded first
    if (allEstablishments.length === 0) {
        await loadEstablishments();
    }

    const users = await fetch('/api/admin/users').then(r => r.json());
    const tbody = document.querySelector('#users-table tbody');
    tbody.innerHTML = '';

    users.forEach(u => {
        const establishment = allEstablishments.find(e => e.id === u.establishment_id);
        const estName = establishment ? establishment.name : '-';

        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>${u.id}</td>
            <td>${u.name}</td>
            <td>${u.username}</td>
            <td>${u.role}</td>
            <td>${estName}</td>
            <td>
                <button class="btn action-btn edit-user-btn" data-id="${u.id}">Editar</button>
                <button class="btn btn-accent action-btn delete-user-btn" data-id="${u.id}">Excluir</button>
            </td>
        `;
        tbody.appendChild(tr);
    });

    document.querySelectorAll('.edit-user-btn').forEach(btn => {
        btn.addEventListener('click', () => editUser(parseInt(btn.dataset.id)));
    });
    document.querySelectorAll('.delete-user-btn').forEach(btn => {
        btn.addEventListener('click', () => deleteUser(parseInt(btn.dataset.id)));
    });
}

async function openUserModal(id = null) {
    document.getElementById('user-modal').classList.add('active');
    document.getElementById('user-form').reset();
    document.getElementById('user-id').value = '';
    document.getElementById('user-modal-title').innerText = 'Novo Usuário';

    // Populate establishments dropdown
    populateEstablishmentDropdown();

    if (id) {
        const users = await fetch(`/api/admin/users`).then(r => r.json());
        const user = users.find(u => u.id === id);
        if (user) {
            document.getElementById('user-id').value = user.id;
            document.getElementById('user-name').value = user.name;
            document.getElementById('user-username').value = user.username;
            document.getElementById('user-role').value = user.role;
            document.getElementById('user-password').value = '';
            document.getElementById('user-modal-title').innerText = 'Editar Usuário';

            // Set establishment
            populateEstablishmentDropdown(user.establishment_id);
        }
    }
}

function editUser(id) {
    openUserModal(id);
}

async function deleteUser(id) {
    showToast('Excluindo usuário...', 'warning');

    try {
        const res = await fetch(`/api/admin/users/${id}`, { method: 'DELETE' });
        const data = await res.json();

        if (data.error) {
            showToast(data.error, 'error');
        } else {
            showToast('Usuário excluído com sucesso!', 'success');
            loadUsers();
        }
    } catch (e) {
        showToast('Erro ao excluir usuário', 'error');
    }
}

document.getElementById('user-form').addEventListener('submit', async (e) => {
    e.preventDefault();

    const id = document.getElementById('user-id').value;
    const data = {
        name: document.getElementById('user-name').value,
        username: document.getElementById('user-username').value,
        role: document.getElementById('user-role').value,
        establishment_id: document.getElementById('user-establishment').value || null
    };

    const password = document.getElementById('user-password').value;
    if (password) {
        data.password = password;
    }

    const url = id ? `/api/admin/users/${id}` : '/api/admin/users';
    const method = id ? 'PUT' : 'POST';

    const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    });

    if (res.ok) {
        showToast('Usuário salvo com sucesso!', 'success');
    } else {
        const err = await res.json();
        showToast(err.error || 'Erro ao salvar usuário', 'error');
    }

    closeModal('user-modal');
    loadUsers();
});
