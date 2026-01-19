const { db } = require('../config/db');

exports.getAllNodes = (req, res) => {
    db.all("SELECT * FROM nodes ORDER BY created_at DESC", [], (err, rows) => {
        if (err) return res.status(500).send("查询错误");
        res.json(rows);
    });
};

exports.createNode = (req, res) => {
    const { name, ip, port, username, password, region, notes } = req.body;
    if (!name || !ip || !port) return res.status(400).send("名称、IP、端口必填");

    db.run(
        "INSERT INTO nodes (name, ip, port, username, password, region, notes) VALUES (?, ?, ?, ?, ?, ?, ?)",
        [name, ip, port, username, password, region, notes],
        function(err) {
            if (err) return res.status(500).send("创建失败: " + err.message);
            res.status(201).json({ id: this.lastID, ...req.body });
        }
    );
};

exports.updateNode = (req, res) => {
    const { name, ip, port, username, password, region, status, notes } = req.body;
    db.run(
        "UPDATE nodes SET name=?, ip=?, port=?, username=?, password=?, region=?, status=?, notes=? WHERE id=?",
        [name, ip, port, username, password, region, status, notes, req.params.id],
        function(err) {
            if (err) return res.status(500).send("更新失败");
            res.json({ message: "更新成功" });
        }
    );
};

exports.deleteNode = (req, res) => {
    db.run("DELETE FROM nodes WHERE id=?", [req.params.id], function(err) {
        if (err) return res.status(500).send("删除失败");
        res.json({ message: "删除成功" });
    });
};
