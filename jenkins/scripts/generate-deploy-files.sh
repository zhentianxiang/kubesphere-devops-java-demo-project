#!/bin/bash

# 生成部署文件脚本
# 用法: ./generate-deploy-files.sh <环境> <镜像完整名称>

ENV=$1
IMAGE_FULL_NAME=$2
PROJECT_DIR=$(pwd)

echo "🔧 生成 ${ENV} 环境部署文件..."

# 设置变量
IMAGE_NAME=$(basename "$IMAGE_FULL_NAME" | cut -d: -f1)
TAG_NAME=$(basename "$IMAGE_FULL_NAME" | cut -d: -f2)

APP_PORT=${APP_PORT:-8080}

# 创建临时目录
TEMP_DIR=$(mktemp -d)
mkdir -p $TEMP_DIR/start-app

# 选择对应的模板文件
case $ENV in
    dev)
        COMPOSE_TEMPLATE="$PROJECT_DIR/deploy/docker-compose/docker-compose-dev.yml.tpl"
        ;;
    pre)
        COMPOSE_TEMPLATE="$PROJECT_DIR/deploy/docker-compose/docker-compose-pre.yml.tpl"
        ;;
    prod)
        COMPOSE_TEMPLATE="$PROJECT_DIR/deploy/docker-compose/docker-compose-prod.yml.tpl"
        ;;
    *)
        echo "❌ 未知环境: $ENV"
        exit 1
        ;;
esac

# 生成docker-compose.yml
if [ -f "$COMPOSE_TEMPLATE" ]; then
    envsubst < "$COMPOSE_TEMPLATE" > "$TEMP_DIR/start-app/docker-compose.yml"
    echo "✅ 生成 docker-compose.yml"
else
    echo "⚠️  模板文件不存在: $COMPOSE_TEMPLATE，使用默认模板"
    cat > "$TEMP_DIR/start-app/docker-compose.yml" << EOF
version: '3.8'

services:
  ${IMAGE_NAME}:
    image: ${IMAGE_FULL_NAME}
    container_name: ${IMAGE_NAME}-${ENV}
    restart: unless-stopped
    ports:
      - "${APP_PORT}:${APP_PORT}"
    environment:
      JAVA_OPTS: "-Xms512m -Xmx2048m -Xmn256m -XX:+UseG1GC -Dspring.profiles.active=${ENV}"
      LANG:"zh_CN.UTF-8"
      TZ: "Asia/Shanghai"
      PORT: ${APP_PORT}
EOF
fi

# 输出生成的文件
echo "📁 生成的文件列表:"
ls -la "$TEMP_DIR/start-app/"

# 将生成的文件复制到项目目录
cp -r "$TEMP_DIR/start-app/" "$PROJECT_DIR/"
echo "🎉 部署文件生成完成！（当前仅生成 docker-compose.yml，用于远程 docker compose 部署）"