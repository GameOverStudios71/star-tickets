// Permissões de página por role
const pagePermissions = {
    'reception.html': ['admin', 'manager', 'receptionist'],
    'professional.html': ['admin', 'manager', 'professional'],
    'manager.html': ['admin', 'manager'],
    'dashboard.html': ['admin', 'manager'],
    'tv.html': ['admin', 'manager', 'tv'],
    'admin.html': ['admin'],
    'automation.html': ['admin', 'manager'],
    'index.html': ['admin', 'manager'] // Menu principal só para admin e manager
};

// Redirect por role (quando acesso negado)
const roleRedirects = {
    'admin': '/index.html',
    'manager': '/index.html',
    'receptionist': '/reception.html',
    'professional': '/professional.html',
    'tv': '/tv.html'
};

async function checkAuth() {
    try {
        const res = await fetch('/api/auth/me');
        if (!res.ok) {
            window.location.href = '/login.html';
            return null;
        }
        const data = await res.json();
        const user = data.user;

        // Verificar permissão para página atual
        const currentPage = window.location.pathname.split('/').pop() || 'index.html';
        const allowedRoles = pagePermissions[currentPage];

        if (allowedRoles && !allowedRoles.includes(user.role)) {
            // Usuário não tem permissão para esta página
            alert('Você não tem permissão para acessar esta página.');
            window.location.href = roleRedirects[user.role] || '/login.html';
            return null;
        }

        return user;
    } catch (err) {
        window.location.href = '/login.html';
        return null;
    }
}

async function logout() {
    await fetch('/api/auth/logout', { method: 'POST' });
    window.location.href = '/login.html';
}

// Wrapper for fetch that handles 401 errors automatically
async function fetchWithAuth(url, options = {}) {
    const res = await fetch(url, options);
    if (res.status === 401) {
        alert('Sessão expirada. Você será redirecionado para o login.');
        window.location.href = '/login.html';
        return null;
    }
    return res;
}

// Handle API response errors - call this after fetch
function handleApiError(res) {
    if (!res) return true; // Already handled by fetchWithAuth
    if (res.status === 401) {
        alert('Sessão expirada. Você será redirecionado para o login.');
        window.location.href = '/login.html';
        return true;
    }
    if (res.status === 403) {
        alert('Você não tem permissão para realizar esta ação.');
        return true;
    }
    return false;
}

function showUserInfo(user) {
    const userInfoHTML = `
        <div style="display: flex; align-items: center; gap: 15px;">
            <span style="color: white;">
                👤 ${user.name} 
                ${user.establishment_id ? `(${user.role})` : '(Admin)'}
            </span>
            <button onclick="logout()" class="btn" style="padding: 8px 15px;">Sair</button>
        </div>
    `;
    return userInfoHTML;
}

