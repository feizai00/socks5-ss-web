#!/bin/bash

# Xray转换器一键安装包
# 使用方法: ./install-package.sh

set -e

echo "🚀 开始安装 Xray转换器管理平台..."

# 创建项目目录
PROJECT_DIR="/opt/xray-converter"
echo "📁 创建项目目录: $PROJECT_DIR"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# 创建目录结构
echo "📂 创建目录结构..."
mkdir -p backend config data logs uploads frontend/dist

# 创建 package.json
echo "📦 创建 package.json..."
cat > package.json << 'EOF'
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

# 创建后端服务器
echo "🖥️ 创建后端服务器..."
cat > backend/server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// 中间件
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// 静态文件服务
app.use(express.static(path.join(__dirname, '../frontend/dist')));

// API 路由
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

// 用户认证
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

// 配置管理
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

// SPA 路由处理
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, '../frontend/dist/index.html'));
});

// 错误处理
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ success: false, message: 'Internal server error' });
});

// 启动服务器
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Xray Converter Server is running on port ${PORT}`);
    console.log(`📊 Health check: http://localhost:${PORT}/api/health`);
    console.log(`🌐 Web interface: http://localhost:${PORT}`);
});

// 优雅关闭
process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT', () => process.exit(0));
EOF

# 创建简单的前端页面
echo "🌐 创建前端页面..."
cat > frontend/dist/index.html << 'EOF'
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
            <button class="btn" onclick="viewLogs()">查看日志</button>
            <button class="btn" onclick="restart()">重启服务</button>
        </div>
    </div>

    <script>
        // 获取系统状态
        async function checkHealth() {
            try {
                const response = await fetch('/api/health');
                const data = await response.json();
                alert('系统状态: ' + data.status + '\n运行时间: ' + Math.floor(data.uptime) + '秒');
            } catch (error) {
                alert('检查失败: ' + error.message);
            }
        }
        
        function viewLogs() {
            alert('日志查看功能开发中...');
        }
        
        function restart() {
            if (confirm('确定要重启服务吗？')) {
                alert('重启功能开发中...');
            }
        }
        
        // 更新运行时间
        async function updateUptime() {
            try {
                const response = await fetch('/api/health');
                const data = await response.json();
                document.getElementById('uptime').textContent = Math.floor(data.uptime) + '秒';
            } catch (error) {
                document.getElementById('uptime').textContent = '获取失败';
            }
        }
        
        // 每5秒更新一次
        setInterval(updateUptime, 5000);
        updateUptime();
    </script>
</body>
</html>
EOF

# 创建环境配置
echo "⚙️ 创建环境配置..."
cat > .env << 'EOF'
NODE_ENV=production
PORT=3000
APP_NAME=Xray转换器管理平台
APP_VERSION=1.0.0
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production
LOG_LEVEL=info
LOG_FILE=./logs/app.log
EOF

# 创建 Dockerfile
echo "🐳 创建 Dockerfile..."
cat > Dockerfile << 'EOF'
FROM node:18-alpine

RUN apk add --no-cache dumb-init curl

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

RUN mkdir -p /app/data /app/logs /app/uploads

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/api/health || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["npm", "start"]
EOF

# 创建 docker-compose.yml
echo "🐙 创建 docker-compose.yml..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: xray-converter-app
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - JWT_SECRET=${JWT_SECRET:-your-super-secret-jwt-key}
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
      - ./uploads:/app/uploads
    networks:
      - xray-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

networks:
  xray-network:
    driver: bridge
EOF

echo "✅ 项目文件创建完成！"
echo ""
echo "🚀 现在启动服务："
echo "cd $PROJECT_DIR"
echo "sudo docker-compose up -d --build"
echo ""
echo "🌐 访问地址："
echo "http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP'):3000"
echo ""
echo "👤 默认登录："
echo "用户名: admin"
echo "密码: admin123"
