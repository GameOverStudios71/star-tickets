// ==================== ROOMS ====================
async function loadRooms() {
    try {
        const rooms = await fetch('/api/admin/rooms').then(r => r.json());
        const tbody = document.querySelector('#rooms-table tbody');
        tbody.innerHTML = '';

        if (rooms.error) {
            return showToast(rooms.error, 'error');
        }

        rooms.forEach(r => {
            // Visualize services as tags would be nice, but list is enough
            const tr = document.createElement('tr');
            tr.innerHTML = `
            <td>${r.id}</td>
            <td>${r.name}</td>
            <td>${r.type || '-'}</td>
            <td>${r.is_active ? 'Ativa' : 'Inativa'}</td>
            <td>
                <button class="btn action-btn edit-room-btn" data-id="${r.id}">Editar</button>
                <button class="btn btn-accent action-btn delete-room-btn" data-id="${r.id}">Excluir</button>
            </td>
        `;
            tbody.appendChild(tr);
        });

        document.querySelectorAll('.edit-room-btn').forEach(btn => {
            btn.addEventListener('click', () => editRoom(parseInt(btn.dataset.id)));
        });
        document.querySelectorAll('.delete-room-btn').forEach(btn => {
            btn.addEventListener('click', () => deleteRoom(parseInt(btn.dataset.id)));
        });
    } catch (e) {
        console.error(e);
        showToast('Erro ao carregar salas', 'error');
    }
}

async function openRoomModal(id = null) {
    document.getElementById('room-modal').classList.add('active');
    document.getElementById('room-form').reset();
    document.getElementById('room-id').value = '';
    document.getElementById('room-modal-title').innerText = 'Nova Sala';

    // Load available services for the checkbox list
    await loadRoomServicesChecklist(id);

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

async function loadRoomServicesChecklist(roomId) {
    const listContainer = document.getElementById('room-services-list');
    listContainer.innerHTML = 'Carregando...';

    try {
        // 1. Get all services
        const services = await fetch('/api/admin/services').then(r => r.json());
        if (services.error) throw new Error(services.error);

        // 2. If editing, get services linked to this room
        let linkedServiceIds = [];
        if (roomId) {
            const roomServices = await fetch(`/api/admin/room-services/${roomId}`).then(r => r.json());
            linkedServiceIds = roomServices.map(rs => rs.service_id);
        }

        // 3. Render
        listContainer.innerHTML = '';
        services.forEach(s => {
            const isChecked = linkedServiceIds.includes(s.id);
            const div = document.createElement('div');
            div.style.marginBottom = '5px';
            div.innerHTML = `
                <label style="font-weight: normal; cursor: pointer; display: flex; align-items: center;">
                    <input type="checkbox" class="room-service-checkbox" value="${s.id}" ${isChecked ? 'checked' : ''} style="width: auto; margin-right: 8px;">
                    ${s.name} <small style="color: #666; margin-left: 5px;">(${s.prefix})</small>
                </label>
            `;
            listContainer.appendChild(div);
        });

    } catch (e) {
        listContainer.innerHTML = '<div style="color: red">Erro ao carregar serviços</div>';
        console.error(e);
    }
}

function editRoom(id) {
    openRoomModal(id);
}

async function deleteRoom(id) {
    showToast('Excluindo sala...', 'warning');

    try {
        const res = await fetch(`/api/admin/rooms/${id}`, { method: 'DELETE' });
        const data = await res.json();

        if (data.error) {
            showToast(data.error, 'error');
        } else {
            showToast('Sala excluída com sucesso!', 'success');
            loadRooms();
        }
    } catch (e) {
        showToast('Erro ao excluir sala', 'error');
    }
}

document.getElementById('room-form').addEventListener('submit', async (e) => {
    e.preventDefault();

    const idStr = document.getElementById('room-id').value;
    const id = idStr ? parseInt(idStr) : null;

    // 1. Save Room Basic Info
    const data = {
        name: document.getElementById('room-name').value,
        type: document.getElementById('room-type').value,
        is_active: document.getElementById('room-active').checked ? 1 : 0
    };

    const url = id ? `/api/admin/rooms/${id}` : '/api/admin/rooms';
    const method = id ? 'PUT' : 'POST';

    try {
        const res = await fetch(url, {
            method,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        const result = await res.json();

        if (result.error) throw new Error(result.error);

        const finalRoomId = id || result.id;

        // 2. Handle Services (Sync)
        await syncRoomServices(finalRoomId);

        showToast('Sala salva com sucesso!', 'success');
        closeModal('room-modal');
        loadRooms();

    } catch (e) {
        showToast(e.message || 'Erro ao salvar sala', 'error');
    }
});

async function syncRoomServices(roomId) {
    // Get currently checked in UI
    const checkboxes = document.querySelectorAll('.room-service-checkbox');
    const selectedIds = Array.from(checkboxes).filter(cb => cb.checked).map(cb => parseInt(cb.value));

    // Get currently in DB
    const currentServices = await fetch(`/api/admin/room-services/${roomId}`).then(r => r.json());
    const currentIds = currentServices.map(rs => rs.service_id);

    // Find what to add
    const toAdd = selectedIds.filter(id => !currentIds.includes(id));

    // Find what to remove (we need the row ID from currentServices to delete)
    const toRemove = currentServices.filter(rs => !selectedIds.includes(rs.service_id));

    // Execute Adds
    for (const serviceId of toAdd) {
        await fetch('/api/admin/room-services', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ room_id: roomId, service_id: serviceId })
        });
    }

    // Execute Removes
    for (const rs of toRemove) {
        await fetch(`/api/admin/room-services/${rs.id}`, { method: 'DELETE' });
    }
}
