FROM node:18-alpine

# 安装基础工具
RUN apk add --no-cache curl dumb-init sqlite

WORKDIR /app

# 复制后端依赖配置
COPY backend/package.json ./

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
