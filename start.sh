#!/bin/bash
set -e

# 复制 Nginx 配置
cp /app/nginx.conf /etc/nginx/nginx.conf

# 创建 Nginx 日志目录
mkdir -p /var/log/nginx /var/run

# 启动 Nginx
nginx

echo "[start.sh] Nginx 已启动，监听 5000 端口"
echo "[start.sh] Flask 将运行在 5001 端口"

# 启动 Flask（内部端口 5001）
export FLASK_PORT=5001
exec python app.py
