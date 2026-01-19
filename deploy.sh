#!/bin/bash

# Xray转换器管理平台部署脚本
# 使用方法: ./deploy.sh [production|staging]

set -e

# 配置变量
ENVIRONMENT=${1:-production}
PROJECT_NAME="xray-converter"
DEPLOY_USER="deploy"
DEPLOY_PATH="/opt/${PROJECT_NAME}"
BACKUP_PATH="/opt/backups/${PROJECT_NAME}"
NGINX_CONFIG_PATH="/etc/nginx/sites-available/${PROJECT_NAME}"
SYSTEMD_SERVICE_PATH="/etc/systemd/system/${PROJECT_NAME}.service"
LOG_FILE="/var/log/${PROJECT_NAME}-deploy.log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 初始化日志文件
init_log() {
    # 创建日志目录
    mkdir -p "$(dirname "$LOG_FILE")"

    # 创建日志文件
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"

    # 记录部署开始时间
    echo "=== 部署开始: $(date) ===" >> "$LOG_FILE"
    echo "环境: $ENVIRONMENT" >> "$LOG_FILE"
    echo "项目: $PROJECT_NAME" >> "$LOG_FILE"
    echo "部署路径: $DEPLOY_PATH" >> "$LOG_FILE"
    echo "==============================" >> "$LOG_FILE"
}

log_info() {
    local msg="[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo -e "${GREEN}[INFO]${NC} $1"
    echo "$msg" >> "$LOG_FILE"
}

log_warn() {
    local msg="[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "$msg" >> "$LOG_FILE"
}

log_error() {
    local msg="[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo -e "${RED}[ERROR]${NC} $1"
    echo "$msg" >> "$LOG_FILE"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi
}

# 清理旧配置和冲突
cleanup_old_configs() {
    log_info "清理可能存在的配置冲突..."

    # 停止可能运行的服务
    systemctl stop nginx >> "$LOG_FILE" 2>&1 || true

    # 清理可能存在的SSL配置文件
    if [ -f /etc/nginx/sites-available/xray-converter ]; then
        if grep -q "ssl_certificate" /etc/nginx/sites-available/xray-converter; then
            log_warn "发现包含SSL配置的旧文件，将备份并重新创建"
            mv /etc/nginx/sites-available/xray-converter /etc/nginx/sites-available/xray-converter.ssl-backup >> "$LOG_FILE" 2>&1
        fi
    fi

    # 移除可能的符号链接
    rm -f /etc/nginx/sites-enabled/xray-converter >> "$LOG_FILE" 2>&1 || true
    rm -f /etc/nginx/sites-enabled/default >> "$LOG_FILE" 2>&1 || true

    log_info "配置清理完成"
}

# 安装系统依赖
install_dependencies() {
    log_info "安装系统依赖..."
    
    # 更新包管理器
    apt update
    
    # 安装基础依赖
    apt install -y curl wget git nginx certbot python3-certbot-nginx
    
    # 安装Node.js 18
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt install -y nodejs
    
    # 安装PM2
    npm install -g pm2
    
    # 安装Docker
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker
        systemctl start docker
    fi
    
    # 安装Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    
    log_info "系统依赖安装完成"
}

# 创建部署用户
create_deploy_user() {
    log_info "创建部署用户..."
    
    if ! id "$DEPLOY_USER" &>/dev/null; then
        useradd -m -s /bin/bash $DEPLOY_USER
        usermod -aG docker $DEPLOY_USER
        log_info "用户 $DEPLOY_USER 创建成功"
    else
        log_warn "用户 $DEPLOY_USER 已存在"
    fi
}

# 创建目录结构
create_directories() {
    log_info "创建目录结构..."
    
    mkdir -p $DEPLOY_PATH
    mkdir -p $BACKUP_PATH
    mkdir -p $DEPLOY_PATH/logs
    mkdir -p $DEPLOY_PATH/data
    mkdir -p $DEPLOY_PATH/uploads
    
    chown -R $DEPLOY_USER:$DEPLOY_USER $DEPLOY_PATH
    chown -R $DEPLOY_USER:$DEPLOY_USER $BACKUP_PATH
    
    log_info "目录结构创建完成"
}

# 安装Nginx
install_nginx() {
    log_info "安装Nginx..."

    # 检查Nginx是否已安装
    if command -v nginx &> /dev/null; then
        log_warn "Nginx已安装，跳过安装步骤"
        return 0
    fi

    # 更新包列表
    if ! apt-get update >> "$LOG_FILE" 2>&1; then
        log_error "更新包列表失败，请检查网络连接"
        return 1
    fi

    # 安装Nginx
    log_info "正在安装Nginx..."
    if ! apt-get install -y nginx >> "$LOG_FILE" 2>&1; then
        log_error "Nginx安装失败，请检查日志: $LOG_FILE"
        return 1
    fi

    # 启动Nginx服务
    if ! systemctl start nginx >> "$LOG_FILE" 2>&1; then
        log_error "Nginx启动失败"
        systemctl status nginx >> "$LOG_FILE" 2>&1
        return 1
    fi

    # 设置开机自启
    if ! systemctl enable nginx >> "$LOG_FILE" 2>&1; then
        log_error "Nginx开机自启设置失败"
        return 1
    fi

    # 检查Nginx状态
    if ! systemctl is-active --quiet nginx; then
        log_error "Nginx服务未正常运行"
        systemctl status nginx >> "$LOG_FILE" 2>&1
        return 1
    fi

    log_info "Nginx安装完成"
    return 0
}

# 配置Nginx
configure_nginx() {
    log_info "配置Nginx..."

    # 停止Nginx服务以避免配置冲突
    log_info "停止Nginx服务..."
    systemctl stop nginx >> "$LOG_FILE" 2>&1 || true

    # 备份并清理旧配置
    if [ -f /etc/nginx/sites-enabled/default ]; then
        cp /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default.backup >> "$LOG_FILE" 2>&1
        rm -f /etc/nginx/sites-enabled/default >> "$LOG_FILE" 2>&1
        log_info "已备份并移除默认Nginx配置"
    fi

    # 移除可能存在的旧配置
    if [ -f /etc/nginx/sites-enabled/xray-converter ]; then
        rm -f /etc/nginx/sites-enabled/xray-converter >> "$LOG_FILE" 2>&1
        log_info "已移除旧的站点配置"
    fi

    # 创建HTTP-only Nginx配置（无SSL）
    log_info "创建HTTP-only Nginx配置文件..."
    cat > $NGINX_CONFIG_PATH << 'EOF'
server {
    listen 80;
    server_name _;

    # 安全头设置
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # 客户端最大上传大小
    client_max_body_size 100M;

    # 主应用代理
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # 静态文件缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 缓存设置
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # API路由
    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # API超时设置
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    # WebSocket支持
    location /socket.io/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 健康检查
    location /health {
        proxy_pass http://localhost:3000/api/health;
        proxy_set_header Host $host;
        access_log off;
    }

    # 禁止访问隐藏文件
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # 日志配置
    access_log /var/log/nginx/xray-converter.access.log;
    error_log /var/log/nginx/xray-converter.error.log;
}
EOF

    # 检查配置文件是否创建成功
    if [ ! -f "$NGINX_CONFIG_PATH" ]; then
        log_error "Nginx配置文件创建失败"
        return 1
    fi

    log_info "Nginx配置文件创建成功"

    # 启用站点配置
    log_info "启用Nginx站点配置..."
    if ! ln -sf "$NGINX_CONFIG_PATH" /etc/nginx/sites-enabled/ >> "$LOG_FILE" 2>&1; then
        log_error "启用Nginx站点配置失败"
        return 1
    fi

    # 禁用默认站点
    if [ -f /etc/nginx/sites-enabled/default ]; then
        rm -f /etc/nginx/sites-enabled/default >> "$LOG_FILE" 2>&1
        log_info "已禁用默认Nginx站点"
    fi

    # 测试Nginx配置
    log_info "测试Nginx配置..."
    if ! nginx -t >> "$LOG_FILE" 2>&1; then
        log_error "Nginx配置测试失败"
        echo "=== Nginx配置测试错误详情 ===" >> "$LOG_FILE"
        nginx -t >> "$LOG_FILE" 2>&1
        echo "=== 当前配置文件内容 ===" >> "$LOG_FILE"
        cat "$NGINX_CONFIG_PATH" >> "$LOG_FILE" 2>&1
        echo "=== 尝试修复配置 ===" >> "$LOG_FILE"

        # 尝试使用最简单的配置
        log_warn "尝试使用简化配置修复..."
        cat > $NGINX_CONFIG_PATH << 'SIMPLE_EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
SIMPLE_EOF

        # 再次测试简化配置
        if ! nginx -t >> "$LOG_FILE" 2>&1; then
            log_error "简化配置也失败，请检查Nginx安装"
            return 1
        fi
        log_info "简化配置测试通过"
    else
        log_info "Nginx配置测试通过"
    fi

    # 启动Nginx服务
    log_info "启动Nginx服务..."
    if ! systemctl start nginx >> "$LOG_FILE" 2>&1; then
        log_error "Nginx启动失败，尝试重启"
        if ! systemctl restart nginx >> "$LOG_FILE" 2>&1; then
            log_error "Nginx重启失败"
            echo "=== Nginx状态信息 ===" >> "$LOG_FILE"
            systemctl status nginx >> "$LOG_FILE" 2>&1
            echo "=== Nginx错误日志 ===" >> "$LOG_FILE"
            tail -20 /var/log/nginx/error.log >> "$LOG_FILE" 2>&1
            return 1
        fi
    fi

    # 验证Nginx状态
    if ! systemctl is-active --quiet nginx; then
        log_error "Nginx服务未正常运行"
        systemctl status nginx >> "$LOG_FILE" 2>&1
        return 1
    fi

    log_info "Nginx配置完成并已生效"
    return 0
}

# 配置systemd服务
configure_systemd() {
    log_info "配置systemd服务..."
    
    cat > $SYSTEMD_SERVICE_PATH << EOF
[Unit]
Description=Xray Converter Management Platform
After=network.target

[Service]
Type=simple
User=$DEPLOY_USER
WorkingDirectory=$DEPLOY_PATH
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
Environment=NODE_ENV=$ENVIRONMENT
Environment=PORT=3000

# 日志
StandardOutput=append:$DEPLOY_PATH/logs/app.log
StandardError=append:$DEPLOY_PATH/logs/error.log

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DEPLOY_PATH

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable $PROJECT_NAME
    
    log_info "systemd服务配置完成"
}

# 部署应用
deploy_application() {
    log_info "部署应用..."
    
    # 切换到部署用户
    sudo -u $DEPLOY_USER bash << 'DEPLOY_SCRIPT'
    
    # 进入部署目录
    cd /opt/xray-converter
    
    # 如果是首次部署，克隆代码
    if [ ! -d ".git" ]; then
        git clone https://github.com/feizai00/socks5-ss.git .
    else
        # 更新代码
        git fetch origin
        git reset --hard origin/main
    fi
    
    # 安装后端依赖
    npm install --production
    
    # 构建前端
    cd frontend
    npm install
    npm run build
    cd ..
    
    # 复制环境配置
    if [ ! -f ".env" ]; then
        cp .env.example .env
        echo "请编辑 .env 文件配置数据库等信息"
    fi
    
DEPLOY_SCRIPT
    
    log_info "应用部署完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."
    
    # 安装ufw
    apt install -y ufw
    
    # 基础规则
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # 允许SSH
    ufw allow ssh
    
    # 允许HTTP/HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # 启用防火墙
    ufw --force enable
    
    log_info "防火墙配置完成"
}

# 设置SSL证书
setup_ssl() {
    log_info "设置SSL证书..."
    
    read -p "请输入您的域名: " DOMAIN
    read -p "请输入您的邮箱: " EMAIL
    
    if [ -n "$DOMAIN" ] && [ -n "$EMAIL" ]; then
        # 替换Nginx配置中的域名
        sed -i "s/your-domain.com/$DOMAIN/g" $NGINX_CONFIG_PATH
        
        # 重新加载Nginx
        systemctl reload nginx
        
        # 获取SSL证书
        certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --non-interactive
        
        log_info "SSL证书设置完成"
    else
        log_warn "跳过SSL证书设置"
    fi
}

# 启动服务
start_services() {
    log_info "启动服务..."
    
    # 启动应用
    systemctl start $PROJECT_NAME
    
    # 启动Nginx
    systemctl start nginx
    systemctl enable nginx
    
    # 检查服务状态
    sleep 5
    
    if systemctl is-active --quiet $PROJECT_NAME; then
        log_info "应用服务启动成功"
    else
        log_error "应用服务启动失败"
        systemctl status $PROJECT_NAME
    fi
    
    if systemctl is-active --quiet nginx; then
        log_info "Nginx服务启动成功"
    else
        log_error "Nginx服务启动失败"
        systemctl status nginx
    fi
}

# 显示部署信息
show_deployment_info() {
    # 记录部署完成时间
    echo "=== 部署完成: $(date) ===" >> "$LOG_FILE"

    log_info "🎉 部署完成！"
    echo
    echo "==================================="
    echo "🚀 部署信息"
    echo "==================================="
    echo "项目路径: $DEPLOY_PATH"
    echo "部署日志: $LOG_FILE"
    echo "应用日志: $DEPLOY_PATH/logs"
    echo "备份路径: $BACKUP_PATH"
    echo "Nginx配置: $NGINX_CONFIG_PATH"
    echo "systemd服务: $SYSTEMD_SERVICE_PATH"
    echo
    echo "🌐 访问地址:"
    local server_ip=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")
    echo "HTTP访问: http://$server_ip"
    echo "直接端口: http://$server_ip:3000"
    echo
    echo "🔧 常用命令:"
    echo "查看部署日志: tail -f $LOG_FILE"
    echo "查看应用状态: systemctl status $PROJECT_NAME"
    echo "查看应用日志: journalctl -u $PROJECT_NAME -f"
    echo "查看Docker状态: docker-compose ps"
    echo "查看Docker日志: docker-compose logs -f"
    echo "重启应用: systemctl restart $PROJECT_NAME"
    echo "重新加载Nginx: systemctl reload nginx"
    echo
    echo "🔍 故障排除:"
    echo "如果遇到问题，请检查以下日志："
    echo "- 部署日志: $LOG_FILE"
    echo "- Nginx错误日志: /var/log/nginx/error.log"
    echo "- Nginx访问日志: /var/log/nginx/xray-converter.access.log"
    echo "- 系统日志: journalctl -xe"
    echo
    echo "📋 下一步:"
    echo "1. 访问 http://$server_ip 测试应用"
    echo "2. 使用默认账号登录: admin / admin123"
    echo "3. 修改默认密码"
    echo "4. 配置域名和SSL（可选）"
    echo "==================================="

    # 检查服务状态
    echo
    echo "📊 服务状态检查:"
    echo "==================================="

    # 检查Nginx状态
    if systemctl is-active --quiet nginx; then
        echo "✅ Nginx: 运行中"
    else
        echo "❌ Nginx: 未运行"
    fi

    # 检查Docker状态
    if systemctl is-active --quiet docker; then
        echo "✅ Docker: 运行中"
    else
        echo "❌ Docker: 未运行"
    fi

    # 检查端口监听
    if netstat -tlnp | grep -q ":80 "; then
        echo "✅ 端口80: 监听中"
    else
        echo "❌ 端口80: 未监听"
    fi

    if netstat -tlnp | grep -q ":3000 "; then
        echo "✅ 端口3000: 监听中"
    else
        echo "❌ 端口3000: 未监听"
    fi

    echo "==================================="
}

# 主函数
main() {
    # 初始化日志
    init_log

    log_info "开始部署 Xray转换器管理平台 ($ENVIRONMENT 环境)"
    log_info "日志文件: $LOG_FILE"

    check_root
    cleanup_old_configs
    install_dependencies
    install_nginx
    create_deploy_user
    create_directories
    configure_nginx
    configure_systemd
    deploy_application
    configure_firewall
    
    # 询问是否设置SSL
    read -p "是否设置SSL证书? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        setup_ssl
    fi
    
    start_services
    show_deployment_info
}

# 运行主函数
main "$@"
