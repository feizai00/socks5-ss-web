#!/bin/bash
echo "🚀 启动 Xray Converter..."

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "❌ 未检测到 Docker，请先安装 Docker 和 Docker Compose"
    exit 1
fi

# 加载环境变量
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        echo "⚠️ .env 文件不存在，从 .env.example 复制..."
        cp .env.example .env
    else
        echo "⚠️ .env 文件不存在，创建默认配置..."
        echo "PORT=3000" > .env
        echo "JWT_SECRET=$(openssl rand -hex 32)" >> .env
    fi
else
    echo "✅ 加载 .env 配置"
fi

# 确保有执行权限
chmod +x start.sh

# 启动服务
echo "🐳 正在构建并启动容器..."
docker-compose up -d --build

echo "✅ 服务已启动！"
echo "🌐 访问地址: http://localhost:3000"
echo "🔑 默认账号: admin / admin123"
echo "📂 数据目录: ./data"
