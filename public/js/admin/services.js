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
                <button class="btn action-btn edit-service-btn" data-id="${s.id}">Editar</button>
                <button class="btn btn-accent action-btn delete-service-btn" data-id="${s.id}">Excluir</button>
            </td>
        `;
        tbody.appendChild(tr);
    });

    // Add event listeners
    document.querySelectorAll('.edit-service-btn').forEach(btn => {
        btn.addEventListener('click', () => editService(parseInt(btn.dataset.id)));
    });
    document.querySelectorAll('.delete-service-btn').forEach(btn => {
        btn.addEventListener('click', () => deleteService(parseInt(btn.dataset.id)));
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
    console.log('deleteService called with id:', id);

    // Show warning toast
    showToast('Excluindo serviço...', 'warning');

    console.log('Sending DELETE request...');
    try {
        const res = await fetch(`/api/admin/services/${id}`, { method: 'DELETE' });
        console.log('Response status:', res.status);
        const data = await res.json();
        console.log('Response data:', data);

        if (data.error) {
            showToast(data.error, 'error');
        } else {
            showToast('Serviço excluído com sucesso!', 'success');
            loadServices();
        }
    } catch (e) {
        console.error('Error deleting service:', e);
        showToast('Erro ao excluir serviço', 'error');
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
