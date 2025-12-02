// ==================== MENUS ====================
async function loadMenus() {
    const menus = await fetch('/api/admin/menus').then(r => r.json());
    const tbody = document.querySelector('#menus-table tbody');
    tbody.innerHTML = '';

    // Populate service dropdown
    const services = await fetch('/api/admin/services').then(r => r.json());
    const select = document.getElementById('menu-service');
    select.innerHTML = '<option value="">-- Container --</option>';
    services.forEach(s => {
        const opt = document.createElement('option');
        opt.value = s.id;
        opt.innerText = s.name;
        select.appendChild(opt);
    });

    // Populate parent menu dropdown
    const parentSelect = document.getElementById('menu-parent');
    parentSelect.innerHTML = '<option value="">-- Raiz (nenhum) --</option>';
    menus.forEach(m => {
        const opt = document.createElement('option');
        opt.value = m.id;
        opt.innerText = m.label;
        parentSelect.appendChild(opt);
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
                <button class="btn action-btn edit-menu-btn" data-id="${m.id}">Editar</button>
                <button class="btn btn-accent action-btn delete-menu-btn" data-id="${m.id}">Excluir</button>
            </td>
        `;
        tbody.appendChild(tr);
    });

    document.querySelectorAll('.edit-menu-btn').forEach(btn => {
        btn.addEventListener('click', () => editMenu(parseInt(btn.dataset.id)));
    });
    document.querySelectorAll('.delete-menu-btn').forEach(btn => {
        btn.addEventListener('click', () => deleteMenu(parseInt(btn.dataset.id)));
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
    showToast('Excluindo item de menu...', 'warning');

    try {
        const res = await fetch(`/api/admin/menus/${id}`, { method: 'DELETE' });
        const data = await res.json();

        if (data.error) {
            showToast(data.error, 'error');
        } else {
            showToast('Item de menu excluído com sucesso!', 'success');
            loadMenus();
        }
    } catch (e) {
        showToast('Erro ao excluir item de menu', 'error');
    }
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
