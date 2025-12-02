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
