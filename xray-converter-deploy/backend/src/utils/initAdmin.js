const { db } = require('../config/db');
const bcrypt = require('bcryptjs');

const initAdmin = async () => {
    return new Promise((resolve, reject) => {
        db.get("SELECT count(*) as count FROM users", async (err, row) => {
            if (err) {
                console.error("检查用户表失败:", err);
                return reject(err);
            }
            
            if (row && row.count === 0) {
                console.log("未发现用户，正在创建默认管理员...");
                const username = "admin";
                const password = "admin123";
                const hashedPassword = await bcrypt.hash(password, 8);
                
                db.run("INSERT INTO users (username, password, role) VALUES (?, ?, ?)", 
                    [username, hashedPassword, 'admin'], 
                    (err) => {
                        if (err) {
                            console.error("创建默认管理员失败:", err);
                            reject(err);
                        } else {
                            console.log("默认管理员已创建: admin / admin123");
                            resolve();
                        }
                    }
                );
            } else {
                resolve();
            }
        });
    });
};

module.exports = initAdmin;
