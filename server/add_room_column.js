const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.resolve(__dirname, '../database/star-tickets.db');
const db = new sqlite3.Database(dbPath);

console.log('🔌 Connecting to database...');

db.serialize(() => {
    // Check if column exists
    db.all("PRAGMA table_info(ticket_services)", (err, columns) => {
        if (err) {
            console.error('❌ Error checking schema:', err);
            return db.close();
        }

        const hasRoomId = columns.some(c => c.name === 'room_id');
        if (hasRoomId) {
            console.log('⚠️  Column room_id already exists in ticket_services.');
            db.close();
            return;
        }

        console.log('🚧 Adding column room_id to ticket_services...');
        db.run("ALTER TABLE ticket_services ADD COLUMN room_id INTEGER REFERENCES rooms(id)", (err) => {
            if (err) {
                console.error('❌ Error adding column:', err);
            } else {
                console.log('✅ Column room_id added successfully!');
            }
            db.close();
        });
    });
});
