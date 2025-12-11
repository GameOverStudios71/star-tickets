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
        <div class="header-left">
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

// Auto-init if enabled
// document.addEventListener('DOMContentLoaded', () => renderAppHeader());
