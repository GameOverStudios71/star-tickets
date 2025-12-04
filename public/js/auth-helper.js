// Auth Helper - Shared authentication utilities

async function checkAuth() {
    try {
        const res = await fetch('/api/auth/me');
        const data = await res.json();

        if (!data.authenticated) {
            // Not authenticated, redirect to login
            const currentPage = window.location.pathname;
            if (!currentPage.includes('login.html')) {
                window.location.href = `/login.html?redirect=${encodeURIComponent(currentPage)}`;
            }
            return null;
        }

        return data.user;
    } catch (e) {
        console.error('Auth check failed:', e);
        window.location.href = '/login.html';
        return null;
    }
}

async function logout() {
    try {
        await fetch('/api/auth/logout', { method: 'POST' });
        window.location.href = '/login.html';
    } catch (e) {
        console.error('Logout failed:', e);
        window.location.href = '/login.html';
    }
}

function getUser() {
    // This should be called after checkAuth()
    return fetch('/api/auth/me')
        .then(res => res.json())
        .then(data => data.user)
        .catch(() => null);
}

function showUserInfo(user) {
    if (!user) return '';

    const estInfo = user.establishment_name ? ` | ${user.establishment_name}` : '';
    return `
        <div style="display: flex; align-items: center; gap: 15px;">
            <span>👤 ${user.name}${estInfo}</span>
            <button onclick="logout()" class="btn" style="padding: 5px 15px; font-size: 0.9rem;">
                🚪 Sair
            </button>
        </div>
    `;
}
