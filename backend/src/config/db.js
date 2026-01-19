const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs');

// 确保数据目录存在
const dataDir = path.join(__dirname, '../../../data');
if (!fs.existsSync(dataDir)) {
    fs.mkdirSync(dataDir, { recursive: true });
}

const dbPath = path.join(dataDir, 'xray-converter.db');
const db = new sqlite3.Database(dbPath, (err) => {
    if (err) {
        console.error('无法连接到 SQLite 数据库:', err.message);
    } else {
        console.log('已连接到 SQLite 数据库');
    }
});

const initDb = () => {
    return new Promise((resolve, reject) => {
        db.serialize(() => {
            // 用户表
            db.run(`CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                password TEXT NOT NULL,
                role TEXT DEFAULT 'admin',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )`);

            // 客户表
            db.run(`CREATE TABLE IF NOT EXISTS customers (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                wechat_id TEXT,
                wechat_name TEXT NOT NULL,
                phone TEXT,
                email TEXT,
                status TEXT DEFAULT 'active',
                notes TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )`);

            // 节点表 (SOCKS5 来源)
            db.run(`CREATE TABLE IF NOT EXISTS nodes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                ip TEXT NOT NULL,
                port INTEGER NOT NULL,
                username TEXT,
                password TEXT,
                region TEXT,
                status TEXT DEFAULT 'active',
                notes TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )`);

            // 服务表 (Shadowsocks 输出)
            db.run(`CREATE TABLE IF NOT EXISTS services (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                port INTEGER UNIQUE NOT NULL,
                password TEXT NOT NULL,
                method TEXT DEFAULT 'aes-256-gcm',
                node_id INTEGER,
                customer_id INTEGER,
                container_id TEXT,
                status TEXT DEFAULT 'stopped',
                expires_at DATETIME,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY(node_id) REFERENCES nodes(id),
                FOREIGN KEY(customer_id) REFERENCES customers(id)
            )`, (err) => {
                if (err) reject(err);
                else resolve();
            });
        });
    });
};

module.exports = { db, initDb };
