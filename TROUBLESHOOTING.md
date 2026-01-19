# 🔧 故障排除指南

## 📋 常见问题解决方案

### 1. Nginx配置错误

#### 问题：SSL证书文件不存在
```
nginx: [emerg] cannot load certificate "/etc/letsencrypt/live/your-domain.com/fullchain.pem"
```

**解决方案：**
```bash
# 1. 停止Nginx
sudo systemctl stop nginx

# 2. 使用HTTP-only配置
sudo tee /etc/nginx/sites-available/xray-converter > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;
    
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
    }
}
EOF

# 3. 启用配置并重启
sudo ln -sf /etc/nginx/sites-available/xray-converter /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl start nginx
```

#### 问题：Nginx配置测试失败
```bash
# 检查配置语法
sudo nginx -t

# 查看详细错误
sudo nginx -T

# 检查配置文件权限
ls -la /etc/nginx/sites-available/xray-converter
```

### 2. Docker相关问题

#### 问题：Docker服务未启动
```bash
# 检查Docker状态
sudo systemctl status docker

# 启动Docker
sudo systemctl start docker
sudo systemctl enable docker

# 检查Docker版本
docker --version
docker-compose --version
```

#### 问题：容器启动失败
```bash
# 查看容器状态
docker-compose ps

# 查看容器日志
docker-compose logs -f

# 重新构建容器
docker-compose down
docker-compose up -d --build

# 清理Docker缓存
docker system prune -a
```

### 3. 端口占用问题

#### 检查端口占用
```bash
# 检查80端口
sudo netstat -tlnp | grep :80

# 检查3000端口
sudo netstat -tlnp | grep :3000

# 检查443端口
sudo netstat -tlnp | grep :443

# 杀死占用端口的进程
sudo kill -9 PID_NUMBER
```

#### 防火墙配置
```bash
# Ubuntu/Debian
sudo ufw status
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 3000/tcp
sudo ufw reload

# CentOS/RHEL
sudo firewall-cmd --list-all
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --reload
```

### 4. 应用无法访问

#### 检查服务状态
```bash
# 检查应用服务
sudo systemctl status xray-converter

# 检查Nginx状态
sudo systemctl status nginx

# 检查Docker容器
docker-compose ps

# 测试本地连接
curl http://localhost:3000/api/health
curl http://localhost/health
```

#### 重启所有服务
```bash
# 重启应用
sudo systemctl restart xray-converter

# 重启Nginx
sudo systemctl restart nginx

# 重启Docker容器
docker-compose restart
```

### 5. 数据库连接问题

#### 检查数据库状态
```bash
# 检查MySQL/PostgreSQL容器
docker-compose logs db

# 进入数据库容器
docker-compose exec db bash

# 测试数据库连接
docker-compose exec app npm run db:test
```

#### 重置数据库
```bash
# 停止服务
docker-compose down

# 删除数据卷
docker volume rm xray-converter_db_data

# 重新启动
docker-compose up -d
```

### 6. 权限问题

#### 修复文件权限
```bash
# 修复部署目录权限
sudo chown -R deploy:deploy /opt/xray-converter
sudo chmod -R 755 /opt/xray-converter

# 修复日志目录权限
sudo mkdir -p /var/log/xray-converter
sudo chown deploy:deploy /var/log/xray-converter
sudo chmod 755 /var/log/xray-converter
```

### 7. 内存不足

#### 检查系统资源
```bash
# 检查内存使用
free -h

# 检查磁盘空间
df -h

# 检查CPU使用
top

# 清理Docker资源
docker system prune -a --volumes
```

### 8. 网络连接问题

#### 检查网络连接
```bash
# 测试外网连接
ping google.com

# 测试DNS解析
nslookup github.com

# 检查路由
traceroute github.com

# 测试端口连通性
telnet github.com 443
```

## 📊 日志文件位置

### 部署日志
- **完整部署**: `/var/log/xray-converter-deploy.log`
- **快速部署**: `/var/log/xray-converter-quick-deploy.log`

### 应用日志
- **应用日志**: `/opt/xray-converter/logs/`
- **系统服务日志**: `journalctl -u xray-converter -f`
- **Docker日志**: `docker-compose logs -f`

### 系统日志
- **Nginx访问日志**: `/var/log/nginx/xray-converter.access.log`
- **Nginx错误日志**: `/var/log/nginx/xray-converter.error.log`
- **系统日志**: `/var/log/syslog`

## 🔍 调试命令

### 一键诊断脚本
```bash
#!/bin/bash
echo "=== 系统诊断报告 ==="
echo "时间: $(date)"
echo

echo "=== 系统信息 ==="
uname -a
cat /etc/os-release

echo "=== 内存使用 ==="
free -h

echo "=== 磁盘使用 ==="
df -h

echo "=== 服务状态 ==="
systemctl status nginx --no-pager
systemctl status docker --no-pager
systemctl status xray-converter --no-pager

echo "=== 端口监听 ==="
netstat -tlnp | grep -E ':(80|443|3000)'

echo "=== Docker状态 ==="
docker-compose ps

echo "=== 最近错误日志 ==="
tail -20 /var/log/xray-converter-deploy.log
tail -20 /var/log/nginx/error.log
```

### 保存为诊断脚本
```bash
# 创建诊断脚本
sudo tee /usr/local/bin/xray-diagnose > /dev/null << 'EOF'
# 上面的诊断脚本内容
EOF

# 给执行权限
sudo chmod +x /usr/local/bin/xray-diagnose

# 运行诊断
xray-diagnose
```

## 🆘 获取帮助

1. **查看部署日志**: `tail -f /var/log/xray-converter-deploy.log`
2. **运行诊断脚本**: `xray-diagnose`
3. **检查GitHub Issues**: https://github.com/feizai00/socks5-ss/issues
4. **重新部署**: 删除 `/opt/xray-converter` 目录后重新运行部署脚本

## 🔄 完全重置

如果所有方法都无效，可以完全重置：

```bash
# 停止所有服务
sudo systemctl stop xray-converter nginx docker

# 删除项目文件
sudo rm -rf /opt/xray-converter

# 删除Nginx配置
sudo rm -f /etc/nginx/sites-enabled/xray-converter
sudo rm -f /etc/nginx/sites-available/xray-converter

# 删除systemd服务
sudo rm -f /etc/systemd/system/xray-converter.service
sudo systemctl daemon-reload

# 清理Docker
docker system prune -a --volumes

# 重新运行部署脚本
wget https://raw.githubusercontent.com/feizai00/socks5-ss/main/deploy.sh
chmod +x deploy.sh
sudo ./deploy.sh production
```
