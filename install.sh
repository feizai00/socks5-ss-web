#!/bin/bash

# Xray Converter 一键部署脚本
# GitHub: https://github.com/YOUR_USERNAME/xray-converter

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 开始安装 Xray Converter Management Platform...${NC}"

# 1. 检查并安装系统依赖
echo "📦 检查系统依赖..."
if ! command -v git &> /dev/null; then
    echo "  - 安装 git..."
    if [ -f /etc/debian_version ]; then
        apt-get update && apt-get install -y git
    elif [ -f /etc/redhat-release ]; then
        yum install -y git
    fi
fi

if ! command -v docker &> /dev/null; then
    echo "  - 安装 Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi

if ! command -v docker-compose &> /dev/null; then
    echo "  - 安装 Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# 2. 克隆/更新代码
INSTALL_DIR="/opt/xray-converter"

if [ -d "$INSTALL_DIR" ]; then
    echo -e "${GREEN}📂 目录已存在，正在更新代码...${NC}"
    cd "$INSTALL_DIR"
    git pull
else
    echo -e "${GREEN}📂 克隆代码仓库...${NC}"
    # 请替换为您的实际 GitHub 地址
    git clone https://github.com/feizai00/socks5-ss-web.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# 3. 配置环境
if [ ! -f .env ]; then
    echo "⚙️ 配置环境变量..."
    cp .env.example .env
    # 生成随机 JWT 密钥
    if command -v openssl &> /dev/null; then
        RANDOM_SECRET=$(openssl rand -hex 32)
        sed -i "s/change-this-secret-key-in-production/$RANDOM_SECRET/" .env
    fi
fi

# 4. 创建数据目录
mkdir -p data logs uploads

# 5. 启动服务
echo -e "${GREEN}🐳 启动 Docker 容器...${NC}"

# 强制进入安装目录，防止在错误目录下执行
cd "$INSTALL_DIR" || { echo -e "${RED}❌ 无法进入安装目录 $INSTALL_DIR${NC}"; exit 1; }

# 停止旧容器（如果有）
echo "🛑 停止旧服务..."
docker-compose down --remove-orphans || true

# 清理未使用的镜像（可选，释放空间）
# docker image prune -f

# 使用 docker-compose 启动并强制构建
echo "🏗️ 构建并启动新服务..."
docker-compose up -d --build

# 6. 显示完成信息
echo
echo -e "${GREEN}✅ 安装完成！${NC}"
echo "-----------------------------------"
echo "🌐 访问地址: http://$(curl -s ifconfig.me):3000"
echo "🔑 默认账号: admin"
echo "🔑 默认密码: admin123"
echo "-----------------------------------"
echo "📂 安装目录: $INSTALL_DIR"
echo "📜 查看日志: cd $INSTALL_DIR && docker-compose logs -f"
