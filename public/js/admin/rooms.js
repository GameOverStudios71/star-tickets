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
