const mysql = require('mysql2/promise');
const https = require('https');

// Aiven DB Configuration
const dbConfig = {
    host: 'mysql-1e3b4df3-dhanushkrock-d32b.g.aivencloud.com',
    port: 16560,
    user: 'avnadmin',
    password: process.env.DB_PASSWORD,
    database: 'defaultdb',
    ssl: { rejectUnauthorized: false }
};

// Render Backend URL
const renderUrl = 'https://smcc-backend.onrender.com/ping'; // or just / to wake it up

async function pingDatabase() {
    console.log('Initiating DB heartbeat...');
    try {
        const connection = await mysql.createConnection(dbConfig);
        await connection.query('SELECT 1');
        console.log('✅ DB Heartbeat successful: Connection verified.');
        await connection.end();
    } catch (err) {
        console.error('❌ DB Heartbeat failed:', err.message);
        // We calculate if we should exit with error or allow partial success
        // For now, let's just log it. If DB is down, we want to know, but maybe not fail the whole action if Render is up?
        // But usually, actions should fail if something is wrong.
        throw err;
    }
}

function pingRenderService() {
    return new Promise((resolve, reject) => {
        console.log(`Initiating Render heartbeat to: ${renderUrl}`);
        https.get(renderUrl, (res) => {
            console.log(`✅ Render Service responded with Status: ${res.statusCode}`);
            if (res.statusCode >= 200 && res.statusCode < 300) {
                resolve();
            } else {
                // Determine if 404 is "alive" enough. 
                // Any response means it's awake.
                resolve();
            }
        }).on('error', (e) => {
            console.error(`❌ Render Heartbeat failed: ${e.message}`);
            reject(e);
        });
    });
}

async function run() {
    try {
        // Run paralell or sequential? Sequential is fine.
        if (process.env.DB_PASSWORD) {
            await pingDatabase();
        } else {
            console.log('⚠️ DB_PASSWORD not provided, skipping DB ping.');
        }

        await pingRenderService();
        console.log('🎉 All keep-alive checks completed.');
        process.exit(0);
    } catch (error) {
        console.error('⚠️ Keep-alive script encountered errors.');
        process.exit(1);
    }
}

run();
