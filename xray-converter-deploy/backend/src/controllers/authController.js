const { db } = require('../config/db');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

exports.login = (req, res) => {
    const { username, password } = req.body;

    if (!(username && password)) {
        return res.status(400).send("所有输入均为必填项");
    }

    db.get("SELECT * FROM users WHERE username = ?", [username], async (err, user) => {
        if (err) return res.status(500).send("服务器错误");
        if (!user) return res.status(404).send("用户不存在");

        const passwordIsValid = await bcrypt.compare(password, user.password);

        if (!passwordIsValid) {
            return res.status(401).send({ auth: false, token: null, reason: "密码无效" });
        }

        const token = jwt.sign(
            { id: user.id, username: user.username, role: user.role },
            process.env.JWT_SECRET || 'default_secret_key',
            { expiresIn: 86400 } // 24 hours
        );

        res.status(200).send({ auth: true, token: token, user: { username: user.username, role: user.role } });
    });
};

exports.me = (req, res) => {
    db.get("SELECT id, username, role, created_at FROM users WHERE id = ?", [req.user.id], (err, user) => {
        if (err) return res.status(500).send("查找用户时出错");
        if (!user) return res.status(404).send("找不到用户");
        res.status(200).send(user);
    });
};
