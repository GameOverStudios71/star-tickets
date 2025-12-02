// Authentication helper - Include this in pages that require auth
async function checkAuth() {
    try {
        const res = await fetch('/api/auth/me');
        if (!res.ok) {
            window.location.href = '/login.html';
            return null;
        }
        const data = await res.json();
        return data.user;
    } catch (err) {
        window.location.href = '/login.html';
        return null;
    }
}

async function logout() {
    await fetch('/api/auth/logout', { method: 'POST' });
    window.location.href = '/login.html';
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
