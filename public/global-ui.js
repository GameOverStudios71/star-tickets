/**
 * Global UI Components
 * Handles Header injection and common UI logic
 */

async function renderAppHeader(title = 'Star Tickets') {
    // Check auth to get user info
    let user = null;
    if (typeof checkAuth === 'function') {
        const authRes = await fetch('/api/auth/me'); // Call API directly to avoid redirect loops if checkAuth has strict logic
        if (authRes.ok) {
            const data = await authRes.json();
            user = data.user;
        }
    }

    const headerHtml = `
    <header class="app-header">
        <div class="header-left" style="display:flex; align-items:center; gap:15px;">
            <a href="index.html" class="home-btn" title="Voltar para Home" style="text-decoration:none; font-size:1.5rem; color:white; background:rgba(255,255,255,0.1); padding:5px 10px; border-radius:5px; transition:all 0.2s;">🏠</a>
            <h1>${title}</h1>
        </div>
        <div class="header-right">
            ${user ? `
            <div class="user-profile">
                <div class="user-avatar">
                    ${user.name.charAt(0).toUpperCase()}
                </div>
                <div class="user-info">
                    <span class="user-name">${user.name}</span>
                    <span class="user-role">${user.role}</span>
                </div>
                <button onclick="logout()" class="logout-btn" title="Sair do sistema">
                    🚪 Sair
                </button>
            </div>
            ` : ''}
        </div>
    </header>
    `;

    // Try to find existing header to replace, or insert at top of body
    const existingHeader = document.querySelector('header');
    if (existingHeader) {
        existingHeader.outerHTML = headerHtml;
    } else {
        document.body.insertAdjacentHTML('afterbegin', headerHtml);
    }
}

async function logout() {
    try {
        await fetch('/api/auth/logout', { method: 'POST' });
        window.location.href = '/login.html';
    } catch (error) {
        console.error('Logout failed:', error);
        window.location.href = '/login.html'; // Force redirect anyway
    }
}

// --- Global Monitoring & Offline Modal ---

const OFFLINE_MODAL_ID = 'offline-modal-overlay';
let isServerOffline = false;
let healthCheckInterval = null;

function injectOfflineStyle() {
    const style = document.createElement('style');
    style.textContent = `
        /* Logout Button Style */
        .logout-btn {
            background: rgba(255, 255, 255, 0.1);
            border: 1px solid rgba(255, 255, 255, 0.2);
            color: #fff;
            padding: 8px 15px;
            border-radius: 6px;
            cursor: pointer;
            font-size: 0.9rem;
            margin-left: 15px;
            transition: all 0.2s;
            display: flex;
            align-items: center;
            gap: 5px;
        }

        .logout-btn:hover {
            background: rgba(255, 255, 255, 0.2);
            transform: translateY(-1px);
        }

        .user-profile {
            display: flex;
            align-items: center;
        }

        #${OFFLINE_MODAL_ID} {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background-color: rgba(0, 0, 0, 0.85);
            z-index: 9999;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            color: #fff;
            font-family: 'Segoe UI', sans-serif;
            text-align: center;
        }
        #${OFFLINE_MODAL_ID} h2 {
            font-size: 2rem;
            margin-bottom: 1rem;
            color: #ff6b6b;
        }
        #${OFFLINE_MODAL_ID} p {
            font-size: 1.2rem;
            margin-bottom: 2rem;
            color: #ddd;
        }
        #${OFFLINE_MODAL_ID} .spinner {
            width: 50px;
            height: 50px;
            border: 5px solid rgba(255, 255, 255, 0.3);
            border-radius: 50%;
            border-top-color: #fff;
            animation: spin 1s ease-in-out infinite;
        }
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
        /* Disable interactions on body when offline */
        body.server-offline {
            pointer-events: none;
            overflow: hidden;
        }
        body.server-offline #${OFFLINE_MODAL_ID} {
            pointer-events: auto; /* Allow interactions inside modal if needed */
        }
    `;
    document.head.appendChild(style);
}

function showOfflineModal() {
    if (document.getElementById(OFFLINE_MODAL_ID)) return; // Already shown

    const modal = document.createElement('div');
    modal.id = OFFLINE_MODAL_ID;
    modal.innerHTML = `
        <div class="spinner"></div>
        <h2>Servidor Offline</h2>
        <p>A conexão com o servidor foi perdida.<br>Tentando reconectar...</p>
    `;
    document.body.appendChild(modal);
    document.body.classList.add('server-offline');
}

function hideOfflineModal() {
    const modal = document.getElementById(OFFLINE_MODAL_ID);
    if (modal) {
        modal.remove();
        document.body.classList.remove('server-offline');
        // Optional: Reload page to ensure fresh state after reconnection
        // window.location.reload(); 
    }
}

// Store original fetch
const originalFetch = window.fetch;

// Override fetch to intercept errors
// Override fetch to intercept errors
window.fetch = async function (...args) {
    try {
        const response = await originalFetch(...args);

        // Check for Auth Errors (401/403)
        if (response.status === 401 || response.status === 403) {
            // Avoid redirect loop if already on login page
            if (!window.location.pathname.includes('login.html')) {
                console.warn('Authentication failed (401/403). Redirecting to login...');
                window.location.href = '/login.html?reason=auth_failed';
                // We return a never-resolving promise or just the response to prevent further errors?
                // Returning response allows code to handle it if needed, but page will redirect.
            }
        }

        return response;
    } catch (error) {
        // If it's a network error (failed to fetch)
        console.warn('Interceptor caught error:', error);
        handleConnectionLost();
        throw error;
    }
};

function handleConnectionLost() {
    if (isServerOffline) return; // Already handling
    isServerOffline = true;
    showOfflineModal();
    startHealthCheckPolling();
}

function startHealthCheckPolling() {
    if (healthCheckInterval) return;
    console.log('Starting health check polling...');
    // Check immediately then interval
    checkServerHealth();
    healthCheckInterval = setInterval(checkServerHealth, 2000); // Check every 2s when offline
}

function stopHealthCheckPolling() {
    if (healthCheckInterval) {
        clearInterval(healthCheckInterval);
        healthCheckInterval = null;
    }
}

async function checkServerHealth() {
    try {
        // Use originalFetch to avoid triggering the interceptor recursively (though interceptor handles exception prop)
        const res = await originalFetch('/api/health', { method: 'GET', cache: 'no-cache' });
        if (res.ok) {
            console.log('Server reconnected!');
            isServerOffline = false;
            stopHealthCheckPolling();
            hideOfflineModal();
        }
    } catch (err) {
        // Still offline, keep polling
        console.warn('Server still unreachable...');
    }
}

async function checkSession() {
    // Only check session if server is ONLINE and we are NOT on the login page
    if (isServerOffline) return;
    if (window.location.pathname.includes('login.html')) return;

    try {
        const res = await originalFetch('/api/auth/check');
        if (res.status === 401) {
            // Check if we are already redirecting to avoid loops or redundant calls
            window.location.href = '/login.html?reason=session_expired';
        }
    } catch (err) {
        // Fetch interceptor will handle network errors
    }
}

// Initialize Monitoring
document.addEventListener('DOMContentLoaded', () => {
    injectOfflineStyle();

    // Remove active polling for health (now reactive)
    // Only Session Health needs periodic check
    setInterval(checkSession, 30000); // Every 30 seconds
});
