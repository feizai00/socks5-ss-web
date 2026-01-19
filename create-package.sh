#!/bin/bash

# 创建完整的项目包
echo "🚀 创建 Xray转换器完整项目包..."

# 创建临时目录
PACKAGE_DIR="xray-converter-complete"
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

# 复制现有文件
echo "📁 复制现有文件..."
cp -r . "$PACKAGE_DIR/"

# 确保backend目录存在
mkdir -p "$PACKAGE_DIR/backend"
mkdir -p "$PACKAGE_DIR/config"
mkdir -p "$PACKAGE_DIR/data"
mkdir -p "$PACKAGE_DIR/logs"
mkdir -p "$PACKAGE_DIR/uploads"
mkdir -p "$PACKAGE_DIR/frontend/dist"

# 创建package.json（如果不存在）
if [ ! -f "$PACKAGE_DIR/package.json" ]; then
    echo "📦 创建 package.json..."
    cat > "$PACKAGE_DIR/package.json" << 'EOF'
{
  "name": "xray-converter",
  "version": "1.0.0",
  "description": "Xray SOCKS5 to Shadowsocks Management Platform",
  "main": "backend/server.js",
  "scripts": {
    "start": "node backend/server.js",
    "dev": "nodemon backend/server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "morgan": "^1.10.0",
    "dotenv": "^16.3.1"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF
fi

# 创建backend/server.js（如果不存在）
if [ ! -f "$PACKAGE_DIR/backend/server.js" ]; then
    echo "🖥️ 创建 backend/server.js..."
    cat > "$PACKAGE_DIR/backend/server.js" << 'EOF'
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

app.use(express.static(path.join(__dirname, '../frontend/dist')));

app.get('/api/health', (req, res) => {
    res.json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        version: '1.0.0'
    });
});

app.get('/api/status', (req, res) => {
    res.json({
        message: 'Xray Converter API is running',
        environment: process.env.NODE_ENV || 'development',
        timestamp: new Date().toISOString()
    });
});

app.post('/api/auth/login', (req, res) => {
    const { username, password } = req.body;
    
    if (username === 'admin' && password === 'admin123') {
        res.json({
            success: true,
            token: 'demo-jwt-token',
            user: { id: 1, username: 'admin', role: 'admin' }
        });
    } else {
        res.status(401).json({
            success: false,
            message: 'Invalid credentials'
        });
    }
});

app.get('/api/configs', (req, res) => {
    res.json({
        success: true,
        data: [{
            id: 1,
            name: 'Demo Config',
            type: 'socks5',
            status: 'active',
            created_at: new Date().toISOString()
        }]
    });
});

app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, '../frontend/dist/index.html'));
});

app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ success: false, message: 'Internal server error' });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Xray Converter Server is running on port ${PORT}`);
    console.log(`📊 Health check: http://localhost:${PORT}/api/health`);
    console.log(`🌐 Web interface: http://localhost:${PORT}`);
});

process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT', () => process.exit(0));
EOF
fi

# 创建简单的前端页面
echo "🌐 创建前端页面..."
cat > "$PACKAGE_DIR/frontend/dist/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Xray转换器管理平台</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { background: #fff; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 20px; }
        .card { background: #fff; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 20px; }
        .btn { background: #007bff; color: white; padding: 10px 20px; border: none; border-radius: 4px; cursor: pointer; }
        .btn:hover { background: #0056b3; }
        .status { display: inline-block; padding: 4px 8px; border-radius: 4px; font-size: 12px; }
        .status.active { background: #d4edda; color: #155724; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Xray转换器管理平台</h1>
            <p>SOCKS5 to Shadowsocks 转换管理系统</p>
        </div>
        
        <div class="grid">
            <div class="card">
                <h3>📊 系统状态</h3>
                <p>状态: <span class="status active">运行中</span></p>
                <p>版本: v1.0.0</p>
                <p>运行时间: <span id="uptime">加载中...</span></p>
            </div>
            
            <div class="card">
                <h3>⚙️ 配置管理</h3>
                <p>总配置数: 1</p>
                <p>活跃服务: 1</p>
                <button class="btn" onclick="alert('功能开发中...')">添加配置</button>
            </div>
            
            <div class="card">
                <h3>📈 统计信息</h3>
                <p>总流量: 1.2GB</p>
                <p>连接数: 0</p>
                <p>错误数: 0</p>
            </div>
        </div>
        
        <div class="card">
            <h3>🔧 快速操作</h3>
            <button class="btn" onclick="checkHealth()">健康检查</button>
            <button class="btn" onclick="alert('功能开发中...')">查看日志</button>
            <button class="btn" onclick="alert('功能开发中...')">重启服务</button>
        </div>
    </div>

    <script>
        async function checkHealth() {
            try {
                const response = await fetch('/api/health');
                const data = await response.json();
                alert('系统状态: ' + data.status + '\n运行时间: ' + Math.floor(data.uptime) + '秒');
            } catch (error) {
                alert('检查失败: ' + error.message);
            }
        }
        
        async function updateUptime() {
            try {
                const response = await fetch('/api/health');
                const data = await response.json();
                document.getElementById('uptime').textContent = Math.floor(data.uptime) + '秒';
            } catch (error) {
                document.getElementById('uptime').textContent = '获取失败';
            }
        }
        
        setInterval(updateUptime, 5000);
        updateUptime();
    </script>
</body>
</html>
EOF

# 创建 .gitkeep 文件
touch "$PACKAGE_DIR/config/.gitkeep"
touch "$PACKAGE_DIR/data/.gitkeep"
touch "$PACKAGE_DIR/logs/.gitkeep"
touch "$PACKAGE_DIR/uploads/.gitkeep"

# 打包
echo "📦 打包项目..."
tar -czf xray-converter-complete.tar.gz "$PACKAGE_DIR/"

# 清理临时目录
rm -rf "$PACKAGE_DIR"

echo "✅ 项目包创建完成: xray-converter-complete.tar.gz"
echo "📁 文件大小: $(ls -lh xray-converter-complete.tar.gz | awk '{print $5}')"
echo ""
echo "🚀 请将此文件上传到服务器，然后执行："
echo "tar -xzf xray-converter-complete.tar.gz"
echo "cd xray-converter-complete"
echo "sudo docker-compose up -d --build"
