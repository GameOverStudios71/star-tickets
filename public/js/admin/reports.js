// ==================== REPORTS ====================
async function loadReports() {
    const ticketsData = await fetch('/api/admin/reports/tickets').then(r => r.json());
    const attendanceData = await fetch('/api/admin/reports/attendance').then(r => r.json());

    // Tickets Report
    const ticketsDiv = document.getElementById('tickets-report');
    ticketsDiv.innerHTML = '<table><thead><tr><th>Data</th><th>Total Senhas</th><th>Clientes Únicos</th></tr></thead><tbody></tbody></table>';
    const ticketsTbody = ticketsDiv.querySelector('tbody');
    ticketsData.forEach(t => {
        const tr = document.createElement('tr');
        tr.innerHTML = `<td>${t.date}</td><td>${t.total_tickets}</td><td>${t.unique_customers || 0}</td>`;
        ticketsTbody.appendChild(tr);
    });

    // Attendance Report
    const attendanceDiv = document.getElementById('attendance-report');
    attendanceDiv.innerHTML = '<table><thead><tr><th>Serviço</th><th>Total Atendimentos</th><th>Tempo Médio (min)</th></tr></thead><tbody></tbody></table>';
    const attendanceTbody = attendanceDiv.querySelector('tbody');
    attendanceData.forEach(a => {
        const tr = document.createElement('tr');
        tr.innerHTML = `<td>${a.service_name}</td><td>${a.total_attendances}</td><td>${a.avg_duration_minutes ? a.avg_duration_minutes.toFixed(1) : '-'}</td>`;
        attendanceTbody.appendChild(tr);
    });
}
