const { db } = require('../config/db');

exports.getAllCustomers = (req, res) => {
    db.all("SELECT * FROM customers ORDER BY created_at DESC", [], (err, rows) => {
        if (err) return res.status(500).send("查询错误");
        res.json(rows);
    });
};

exports.createCustomer = (req, res) => {
    const { wechat_name, wechat_id, phone, email, notes } = req.body;
    if (!wechat_name) return res.status(400).send("微信名称必填");

    db.run(
        "INSERT INTO customers (wechat_name, wechat_id, phone, email, notes) VALUES (?, ?, ?, ?, ?)",
        [wechat_name, wechat_id, phone, email, notes],
        function(err) {
            if (err) return res.status(500).send("创建失败: " + err.message);
            res.status(201).json({ id: this.lastID, ...req.body });
        }
    );
};

exports.updateCustomer = (req, res) => {
    const { wechat_name, wechat_id, phone, email, status, notes } = req.body;
    db.run(
        "UPDATE customers SET wechat_name=?, wechat_id=?, phone=?, email=?, status=?, notes=? WHERE id=?",
        [wechat_name, wechat_id, phone, email, status, notes, req.params.id],
        function(err) {
            if (err) return res.status(500).send("更新失败");
            res.json({ message: "更新成功" });
        }
    );
};

exports.deleteCustomer = (req, res) => {
    db.run("DELETE FROM customers WHERE id=?", [req.params.id], function(err) {
        if (err) return res.status(500).send("删除失败");
        res.json({ message: "删除成功" });
    });
};
