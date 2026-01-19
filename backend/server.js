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
const staticDir = path.join(__dirname, '../frontend/dist');
app.use(express.static(staticDir));

// 显式处理 assets 目录，防止根路径匹配问题
app.use('/assets', express.static(path.join(staticDir, 'assets'), { fallthrough: false }));

// 调试接口：列出静态文件（用于排查部署问题）
app.get('/api/debug/files', (req, res) => {
    const fs = require('fs');
    try {
        const files = [];
        function scan(dir) {
            if (!fs.existsSync(dir)) return;
            const items = fs.readdirSync(dir);
            for (const item of items) {
                const fullPath = path.join(dir, item);
                const stat = fs.statSync(fullPath);
                if (stat.isDirectory()) {
                    scan(fullPath);
                } else {
                    files.push(fullPath.replace(staticDir, '').replace(/\\/g, '/'));
                }
            }
        }
        if (fs.existsSync(staticDir)) {
            scan(staticDir);
            res.json({ 
                success: true,
                root: staticDir, 
                files: files,
                exists: true
            });
        } else {
            res.status(404).json({ 
                success: false,
                error: 'Static dir not found', 
                dir: staticDir,
                cwd: process.cwd(),
                dirname: __dirname
            });
        }
    } catch (e) {
        res.status(500).json({ success: false, error: e.message, stack: e.stack });
    }
});

// API 路由
app.get('/api/health', (req, res) => {
    res.json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        version: process.env.npm_package_version || '1.0.0'
    });
});

// 基础 API 路由
app.get('/api/status', (req, res) => {
    res.json({
        message: 'Xray Converter API is running',
        environment: process.env.NODE_ENV || 'development',
        timestamp: new Date().toISOString()
    });
});

// 用户管理 API
app.post('/api/auth/login', (req, res) => {
    const { username, password } = req.body;
    
    // 简单的演示登录
    if (username === 'admin' && password === 'admin123') {
        res.json({
            success: true,
            token: 'demo-jwt-token',
            user: {
                id: 1,
                username: 'admin',
                role: 'admin'
            }
        });
    } else {
        res.status(401).json({
            success: false,
            message: 'Invalid credentials'
        });
    }
});

// 配置管理 API
app.get('/api/configs', (req, res) => {
    res.json({
        success: true,
        data: [
            {
                id: 1,
                name: 'Demo Config',
                type: 'socks5',
                status: 'active',
                created_at: new Date().toISOString()
            }
        ]
    });
});

app.post('/api/configs', (req, res) => {
    const config = req.body;
    res.json({
        success: true,
        message: 'Configuration created successfully',
        data: {
            id: Date.now(),
            ...config,
            created_at: new Date().toISOString()
        }
    });
});

// 服务管理 API
app.get('/api/services', (req, res) => {
    res.json({
        success: true,
        data: [
            {
                id: 1,
                name: 'Demo Service',
                status: 'running',
                port: 1080,
                type: 'socks5'
            }
        ]
    });
});

// 统计信息 API
app.get('/api/stats', (req, res) => {
    res.json({
        success: true,
        data: {
            total_configs: 1,
            active_services: 1,
            total_traffic: '1.2GB',
            uptime: Math.floor(process.uptime())
        }
    });
});

// 文件上传 API
app.post('/api/upload', (req, res) => {
    res.json({
        success: true,
        message: 'File uploaded successfully',
        filename: 'demo-file.txt'
    });
});

// SPA 路由处理
app.get('*', (req, res) => {
    const indexPath = path.join(__dirname, '../frontend/dist/index.html');
    if (fs.existsSync(indexPath)) {
        res.sendFile(indexPath);
    } else {
        console.error(`❌ Index file not found at: ${indexPath}`);
        res.status(404).send('Application is loading... (Index file not found)');
    }
});

// 错误处理中间件
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({
        success: false,
        message: 'Internal server error'
    });
});

// 404 处理
app.use((req, res) => {
    res.status(404).json({
        success: false,
        message: 'API endpoint not found'
    });
});

// 启动服务器
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Xray Converter Server is running on port ${PORT}`);
    console.log(`📊 Health check: http://localhost:${PORT}/api/health`);
    console.log(`🌐 Web interface: http://localhost:${PORT}`);
    console.log(`📝 Environment: ${process.env.NODE_ENV || 'development'}`);
});

// 优雅关闭
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('SIGINT received, shutting down gracefully');
    process.exit(0);
});
