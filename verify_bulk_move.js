// const fetch = require('node-fetch'); // Native fetch in Node 18+

async function run() {
    const baseUrl = 'http://localhost:3000/api';

    console.log('1. Creating ticket with services [2, 3] (Room 1 -> Room 2)...');
    const res1 = await fetch(`${baseUrl}/tickets`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ serviceIds: [2, 3] })
    });
    const ticket = await res1.json();
    console.log('Ticket created:', ticket);
    const ticketId = ticket.ticketId;

    // Simulate Reception Flow to get ticket to WAITING_PROFESSIONAL
    console.log('1.5. Processing through Reception...');
    await fetch(`${baseUrl}/reception/call`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ticketId })
    });
    await fetch(`${baseUrl}/reception/announce`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ticketId })
    });
    await fetch(`${baseUrl}/reception/finish`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ticketId })
    });

    // Wait a bit for DB
    await new Promise(r => setTimeout(r, 500));

    console.log('2. Checking candidates for Room 2...');
    const res2 = await fetch(`${baseUrl}/manager/candidates/2`);
    const candidates = await res2.json();
    const isCandidate = candidates.some(c => c.ticket_id === ticketId);
    console.log('Is ticket a candidate?', isCandidate);

    if (!isCandidate) {
        console.error('❌ Ticket should be a candidate for Room 2');
        process.exit(1);
    }

    console.log('3. Executing Bulk Move to Room 2...');
    const res3 = await fetch(`${baseUrl}/manager/bulk-prioritize`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ticketIds: [ticketId], targetRoomId: 2 })
    });
    const moveResult = await res3.json();
    console.log('Move result:', moveResult);

    // Wait a bit
    await new Promise(r => setTimeout(r, 500));

    console.log('4. Checking candidates for Room 2 (should be gone)...');
    const res4 = await fetch(`${baseUrl}/manager/candidates/2`);
    const candidatesAfter = await res4.json();
    const isCandidateAfter = candidatesAfter.some(c => c.ticket_id === ticketId);
    console.log('Is ticket still a candidate?', isCandidateAfter);

    if (isCandidateAfter) {
        console.error('❌ Ticket should NO LONGER be a candidate for Room 2');
        process.exit(1);
    }

    console.log('5. Checking queue for Room 2 (should be present)...');
    const res5 = await fetch(`${baseUrl}/manager/room/2/queue`);
    const queue = await res5.json();
    const inQueue = queue.some(t => t.ticket_id === ticketId);
    console.log('Is ticket in Room 2 queue?', inQueue);

    if (!inQueue) {
        console.error('❌ Ticket SHOULD be in Room 2 queue');
        process.exit(1);
    }

    console.log('✅ Verification Successful!');
}

run().catch(console.error);
