#!/bin/bash

# Xray转换器 - 真实部署包构建脚本
set -e

echo "🚀 开始构建部署包..."

# 1. 构建前端
echo "📦 构建前端资源..."
cd frontend
if [ ! -d "node_modules" ]; then
    echo "  - 安装前端依赖..."
    npm install
fi
echo "  - 编译 Vue 项目..."
npm run build
cd ..

# 2. 准备打包目录
PACKAGE_DIR="xray-converter-deploy"
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

echo "📂 复制项目文件..."

# 复制后端代码
mkdir -p "$PACKAGE_DIR/backend"
cp -r backend/src "$PACKAGE_DIR/backend/"
cp backend/server.js "$PACKAGE_DIR/backend/"
cp backend/package.json "$PACKAGE_DIR/backend/"

# 复制前端构建产物
mkdir -p "$PACKAGE_DIR/frontend/dist"
cp -r frontend/dist/* "$PACKAGE_DIR/frontend/dist/"

# 复制 Docker 相关文件
cp docker-compose.yml "$PACKAGE_DIR/"
cp Dockerfile "$PACKAGE_DIR/"
cp .env.example "$PACKAGE_DIR/.env" 2>/dev/null || touch "$PACKAGE_DIR/.env"

# 创建数据目录结构
mkdir -p "$PACKAGE_DIR/data"
mkdir -p "$PACKAGE_DIR/logs"
mkdir -p "$PACKAGE_DIR/uploads"

# 3. 创建服务器端启动脚本
echo "📜 生成启动脚本..."
cat > "$PACKAGE_DIR/start.sh" << 'EOF'
#!/bin/bash
echo "🚀 启动 Xray Converter..."

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "❌ 未检测到 Docker，请先安装 Docker 和 Docker Compose"
    exit 1
fi

# 加载环境变量
if [ ! -f .env ]; then
    echo "⚠️ .env 文件不存在，使用默认配置..."
else
    echo "✅ 加载 .env 配置"
fi

# 启动服务
echo "🐳 正在启动容器..."
docker-compose up -d --build

echo "✅ 服务已启动！"
echo "🌐 访问地址: http://localhost:3000"
echo "🔑 默认账号: admin / admin123"
EOF

chmod +x "$PACKAGE_DIR/start.sh"

# 4. 创建根目录的 package.json (用于 Docker 构建上下文)
# Dockerfile COPY . . 会复制根目录所有内容，所以我们需要一个根 package.json 或者调整 Dockerfile
# 当前 Dockerfile 期望在 /app 下有 package.json，且 COPY package*.json ./
# 我们的 Dockerfile 是：
# COPY package*.json ./ -> 这里指的是构建上下文根目录的 package.json
# 但实际上后端依赖在 backend/package.json。
# 让我们调整一下 Dockerfile 适配部署包结构。

# 修改部署包中的 Dockerfile 以适应新的目录结构
# 部署包结构:
# /backend/package.json
# /backend/server.js
# /backend/src
# /frontend/dist
# Dockerfile
# docker-compose.yml

echo "🔧 调整 Dockerfile..."
cat > "$PACKAGE_DIR/Dockerfile" << 'EOF'
FROM node:18-alpine

# 安装基础工具
RUN apk add --no-cache curl dumb-init

WORKDIR /app

# 复制后端依赖配置
# 注意：我们假设构建上下文是部署包根目录
COPY backend/package*.json ./

# 安装依赖
RUN npm install --production

# 复制后端代码
COPY backend ./backend

# 复制前端静态资源
COPY frontend/dist ./frontend/dist

# 创建数据目录
RUN mkdir -p /app/data /app/logs /app/uploads

# 暴露端口
EXPOSE 3000

# 启动命令
CMD ["node", "backend/server.js"]
EOF

# 5. 打包
echo "📦 正在压缩..."
tar -czf xray-converter-deploy.tar.gz "$PACKAGE_DIR"

# 清理
rm -rf "$PACKAGE_DIR"

echo "🎉 打包完成: xray-converter-deploy.tar.gz"
echo "👉 请将此文件上传至服务器并运行 start.sh"
