const { db } = require('../config/db');
const Docker = require('dockerode');
const docker = new Docker(); // Defaults to socket/pipe

// 获取所有服务
exports.getAllServices = (req, res) => {
    const sql = `
        SELECT s.*, 
               c.wechat_name as customer_name,
               n.name as node_name, n.ip as node_ip
        FROM services s
        LEFT JOIN customers c ON s.customer_id = c.id
        LEFT JOIN nodes n ON s.node_id = n.id
        ORDER BY s.created_at DESC
    `;
    db.all(sql, [], async (err, rows) => {
        if (err) return res.status(500).send("查询错误");
        
        // 实时获取容器状态
        const servicesWithStatus = await Promise.all(rows.map(async (service) => {
            if (service.container_id) {
                try {
                    const container = docker.getContainer(service.container_id);
                    const info = await container.inspect();
                    service.runtime_status = info.State.Status; // running, exited, etc.
                } catch (e) {
                    service.runtime_status = 'missing';
                }
            } else {
                service.runtime_status = 'unknown';
            }
            return service;
        }));
        
        res.json(servicesWithStatus);
    });
};

// 创建服务
exports.createService = async (req, res) => {
    const { port, password, method, node_id, customer_id, expires_at } = req.body;
    
    if (!port || !password || !node_id) {
        return res.status(400).send("端口、密码、节点必填");
    }

    // 1. 获取节点信息
    db.get("SELECT * FROM nodes WHERE id = ?", [node_id], async (err, node) => {
        if (err || !node) return res.status(400).send("无效的节点");

        // 2. 检查端口占用
        db.get("SELECT id FROM services WHERE port = ?", [port], async (err, existing) => {
            if (existing) return res.status(400).send("端口已被使用");

            // 3. 构建 Xray 配置
            const config = {
                log: { loglevel: "warning" },
                inbounds: [{
                    port: parseInt(port),
                    protocol: "shadowsocks",
                    settings: {
                        method: method || "aes-256-gcm",
                        password: password,
                        network: "tcp,udp"
                    },
                    tag: "ss-in"
                }],
                outbounds: [{
                    protocol: "socks",
                    settings: {
                        servers: [{
                            address: node.ip,
                            port: node.port,
                            users: (node.username && node.password) ? [{ user: node.username, pass: node.password }] : []
                        }]
                    },
                    tag: "proxy"
                }],
                routing: {
                    rules: [{ type: "field", inboundTag: ["ss-in"], outboundTag: "proxy" }]
                }
            };

            // 4. 启动 Docker 容器
            const containerName = `xray-converter-${port}`;
            try {
                const container = await docker.createContainer({
                    Image: 'teddysun/xray', // 确保镜像存在，或先 pull
                    name: containerName,
                    ExposedPorts: {
                        [`${port}/tcp`]: {},
                        [`${port}/udp`]: {}
                    },
                    HostConfig: {
                        PortBindings: {
                            [`${port}/tcp`]: [{ HostPort: port.toString() }],
                            [`${port}/udp`]: [{ HostPort: port.toString() }]
                        },
                        RestartPolicy: { Name: 'unless-stopped' }
                    },
                    Env: [`XRAY_CONFIG=${JSON.stringify(config)}`]
                });

                await container.start();
                
                // 5. 保存到数据库
                db.run(
                    "INSERT INTO services (port, password, method, node_id, customer_id, container_id, status, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                    [port, password, method || "aes-256-gcm", node_id, customer_id, container.id, 'running', expires_at],
                    function(err) {
                        if (err) {
                            // 回滚：删除容器
                            container.remove({ force: true }).catch(console.error);
                            return res.status(500).send("数据库保存失败: " + err.message);
                        }
                        res.status(201).json({ id: this.lastID, message: "服务创建成功" });
                    }
                );

            } catch (dockerErr) {
                console.error("Docker Error:", dockerErr);
                res.status(500).send("容器创建失败: " + dockerErr.message);
            }
        });
    });
};

// 删除服务
exports.deleteService = (req, res) => {
    db.get("SELECT container_id FROM services WHERE id = ?", [req.params.id], async (err, service) => {
        if (err || !service) return res.status(404).send("服务不存在");

        if (service.container_id) {
            try {
                const container = docker.getContainer(service.container_id);
                await container.remove({ force: true });
            } catch (e) {
                console.warn("容器删除失败或不存在:", e.message);
            }
        }

        db.run("DELETE FROM services WHERE id = ?", [req.params.id], (err) => {
            if (err) return res.status(500).send("数据库删除失败");
            res.json({ message: "删除成功" });
        });
    });
};

// 停止/启动服务 (Toggle)
exports.toggleService = (req, res) => {
    db.get("SELECT container_id, status FROM services WHERE id = ?", [req.params.id], async (err, service) => {
        if (err || !service) return res.status(404).send("服务不存在");

        if (!service.container_id) return res.status(400).send("无容器ID");

        try {
            const container = docker.getContainer(service.container_id);
            const info = await container.inspect();
            
            if (info.State.Running) {
                await container.stop();
                db.run("UPDATE services SET status='stopped' WHERE id=?", [req.params.id]);
                res.json({ status: 'stopped' });
            } else {
                await container.start();
                db.run("UPDATE services SET status='running' WHERE id=?", [req.params.id]);
                res.json({ status: 'running' });
            }
        } catch (e) {
            res.status(500).send("Docker操作失败: " + e.message);
        }
    });
};
