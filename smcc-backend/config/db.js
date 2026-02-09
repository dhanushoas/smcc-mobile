const { Sequelize } = require('sequelize');
require('dotenv').config();

const dbUrl = process.env.DATABASE_URL;

if (!dbUrl) {
    console.error('CRITICAL ERROR: DATABASE_URL is not defined in environment variables!');
    console.error('Please add DATABASE_URL in Render -> Dashboard -> Environment.');
}

const sequelize = new Sequelize(dbUrl || 'mysql://localhost/test', {
    dialect: 'mysql',
    logging: false,
    dialectOptions: {
        ssl: {
            rejectUnauthorized: false
        }
    }
});

const connectDB = async () => {
    try {
        await sequelize.authenticate();
        console.log('MySQL Connected...');

        // Manual Schema Migration: Ensure 'history' column exists
        try {
            await sequelize.query("ALTER TABLE Matches ADD COLUMN history JSON NULL AFTER manOfTheMatch");
            console.log('Migration: Added missing "history" column.');
        } catch (err) {
            // Error 1060 is "Duplicate column name", safe to ignore
            if (!err.message.includes('1060') && !err.message.includes('Duplicate')) {
                console.warn('Migration Note:', err.message);
            }
        }
    } catch (err) {
        console.error('CRITICAL: Unable to connect to the database:', err.message);
        console.error('The server will continue to run to maintain port binding, but API calls requiring DB will fail.');
    }
};

module.exports = { sequelize, connectDB };
