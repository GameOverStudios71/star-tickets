class TraceSystem {
    constructor() {
        this.logs = [];
        this.maxLogs = 100;
        this.isVisible = false;
        this.overlay = null;
        this.logContainer = null;

        this.initGlobalHandlers();
        this.createOverlay();
        this.interceptFetch();
        this.interceptConsole();

        console.log('🚀 Trace System Initialized');
    }

    initGlobalHandlers() {
        window.onerror = (msg, url, line, col, error) => {
            this.error('Uncaught Exception', { msg, url, line, col, error });
            this.showErrorModal('System Error', msg);
            return false;
        };

        window.onunhandledrejection = (event) => {
            this.error('Unhandled Rejection', event.reason);
            this.showErrorModal('Unhandled Promise Rejection', event.reason);
        };
    }

    createOverlay() {
        // Create container
        this.overlay = document.createElement('div');
        this.overlay.id = 'trace-overlay';
        this.overlay.style.cssText = `
            position: fixed;
            bottom: 20px;
            left: 20px;
            width: 600px;
            height: 300px;
            background: rgba(0, 0, 0, 0.9);
            color: #0f0;
            font-family: monospace;
            font-size: 12px;
            z-index: 99999;
            border-radius: 8px;
            display: none;
            flex-direction: column;
            box-shadow: 0 0 20px rgba(0, 255, 0, 0.2);
            border: 1px solid #333;
        `;

        // Header
        const header = document.createElement('div');
        header.style.cssText = `
            padding: 10px;
            background: #111;
            border-bottom: 1px solid #333;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-radius: 8px 8px 0 0;
            cursor: move;
        `;
        header.innerHTML = '<strong>🔍 System Trace</strong> <button id="trace-close" style="background:none;border:none;color:#fff;cursor:pointer">×</button>';

        // Log container
        this.logContainer = document.createElement('div');
        this.logContainer.style.cssText = `
            flex: 1;
            overflow-y: auto;
            padding: 10px;
        `;

        this.overlay.appendChild(header);
        this.overlay.appendChild(this.logContainer);
        document.body.appendChild(this.overlay);

        // Toggle button
        const toggleBtn = document.createElement('button');
        toggleBtn.innerText = '🐞';
        toggleBtn.style.cssText = `
            position: fixed;
            bottom: 20px;
            left: 20px;
            z-index: 99998;
            width: 40px;
            height: 40px;
            border-radius: 50%;
            background: #333;
            color: #fff;
            border: 1px solid #555;
            cursor: pointer;
            font-size: 20px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.3);
        `;
        toggleBtn.onclick = () => this.toggle();
        document.body.appendChild(toggleBtn);

        document.getElementById('trace-close').onclick = () => this.toggle();
    }

    toggle() {
        this.isVisible = !this.isVisible;
        this.overlay.style.display = this.isVisible ? 'flex' : 'none';
    }

    addLog(type, message, data = null) {
        const timestamp = new Date().toLocaleTimeString();
        const logEntry = { timestamp, type, message, data };
        this.logs.push(logEntry);
        if (this.logs.length > this.maxLogs) this.logs.shift();

        this.renderLog(logEntry);
    }

    renderLog(entry) {
        const div = document.createElement('div');
        div.style.marginBottom = '5px';
        div.style.borderBottom = '1px solid #222';
        div.style.paddingBottom = '2px';

        let color = '#ccc';
        if (entry.type === 'error') color = '#ff4444';
        if (entry.type === 'warn') color = '#ffbb33';
        if (entry.type === 'success') color = '#00C851';
        if (entry.type === 'network') color = '#33b5e5';

        div.style.color = color;

        let dataStr = '';
        if (entry.data) {
            try {
                dataStr = typeof entry.data === 'object' ? JSON.stringify(entry.data) : entry.data;
            } catch (e) { dataStr = '[Circular]'; }
        }

        div.innerHTML = `
            <span style="color:#666">[${entry.timestamp}]</span>
            <strong style="margin-right:5px">[${entry.type.toUpperCase()}]</strong>
            <span>${entry.message}</span>
            ${dataStr ? `<div style="color:#666;font-size:10px;margin-left:10px;white-space:pre-wrap">${dataStr}</div>` : ''}
        `;

        this.logContainer.appendChild(div);
        this.logContainer.scrollTop = this.logContainer.scrollHeight;
    }

    log(message, data) { this.addLog('info', message, data); }
    warn(message, data) { this.addLog('warn', message, data); }
    error(message, data) {
        this.addLog('error', message, data);
        // Optional: Flash screen red
        this.flashScreen('rgba(255, 0, 0, 0.1)');
    }
    success(message, data) { this.addLog('success', message, data); }
    network(message, data) { this.addLog('network', message, data); }

    flashScreen(color) {
        const flash = document.createElement('div');
        flash.style.cssText = `
            position: fixed;
            top: 0; left: 0; width: 100%; height: 100%;
            background: ${color};
            pointer-events: none;
            z-index: 100000;
            transition: opacity 0.5s;
        `;
        document.body.appendChild(flash);
        setTimeout(() => {
            flash.style.opacity = '0';
            setTimeout(() => flash.remove(), 500);
        }, 100);
    }

    showErrorModal(title, details) {
        // Only show if not already showing
        if (document.getElementById('trace-error-modal')) return;

        const modal = document.createElement('div');
        modal.id = 'trace-error-modal';
        modal.style.cssText = `
            position: fixed;
            top: 0; left: 0; width: 100%; height: 100%;
            background: rgba(0,0,0,0.8);
            z-index: 100001;
            display: flex;
            justify-content: center;
            align-items: center;
            animation: fadeIn 0.3s;
        `;

        const content = document.createElement('div');
        content.style.cssText = `
            background: #fff;
            padding: 30px;
            border-radius: 10px;
            max-width: 600px;
            width: 90%;
            border-left: 10px solid #ff4444;
            box-shadow: 0 0 50px rgba(255, 0, 0, 0.3);
            animation: pulse 2s infinite;
        `;

        let detailsStr = details;
        if (typeof details === 'object') {
            try { detailsStr = JSON.stringify(details, null, 2); } catch (e) { }
        }

        content.innerHTML = `
            <h2 style="color:#cc0000;margin-top:0">💥 ${title}</h2>
            <p>Um erro inesperado ocorreu no sistema.</p>
            <pre style="background:#f0f0f0;padding:15px;border-radius:5px;overflow:auto;max-height:200px;font-size:12px">${detailsStr}</pre>
            <div style="text-align:right;margin-top:20px">
                <button onclick="document.getElementById('trace-error-modal').remove()" style="padding:10px 20px;background:#333;color:white;border:none;border-radius:5px;cursor:pointer">Fechar</button>
                <button onclick="location.reload()" style="padding:10px 20px;background:#cc0000;color:white;border:none;border-radius:5px;cursor:pointer;margin-left:10px">Recarregar Página</button>
            </div>
            <style>
                @keyframes pulse {
                    0% { box-shadow: 0 0 0 0 rgba(255, 68, 68, 0.4); }
                    70% { box-shadow: 0 0 0 20px rgba(255, 68, 68, 0); }
                    100% { box-shadow: 0 0 0 0 rgba(255, 68, 68, 0); }
                }
            </style>
        `;

        modal.appendChild(content);
        document.body.appendChild(modal);
    }

    interceptFetch() {
        const originalFetch = window.fetch;
        window.fetch = async (...args) => {
            const [resource, config] = args;
            const method = config?.method || 'GET';
            this.network(`📡 Request: ${method} ${resource}`, config?.body);

            try {
                const response = await originalFetch(...args);

                // Clone response to read body without consuming it
                const clone = response.clone();
                try {
                    const data = await clone.json();
                    if (!response.ok) {
                        this.error(`❌ Response Error: ${response.status}`, data);
                        // Automatically show toast for API errors
                        if (window.showToast && data.error) {
                            window.showToast(data.error, 'error');
                        }
                    } else {
                        this.success(`✅ Response: ${response.status}`, data);
                    }
                } catch (e) {
                    this.network(`Response: ${response.status} (Non-JSON)`);
                }

                return response;
            } catch (error) {
                this.error(`❌ Network Error`, error);
                throw error;
            }
        };
    }

    interceptConsole() {
        const methods = ['log', 'warn', 'error', 'info'];
        methods.forEach(method => {
            const original = console[method];
            console[method] = (...args) => {
                original.apply(console, args);
                // Don't log our own logs to avoid infinite loops if we used console.log inside addLog
                // But here we are safe as long as addLog doesn't call console[method]
                // this.addLog(method === 'log' ? 'info' : method, args.map(a => String(a)).join(' '));
            };
        });
    }
}

// Initialize globally
window.Trace = new TraceSystem();
