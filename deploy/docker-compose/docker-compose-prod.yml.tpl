version: '3.8'

services:
  ${IMAGE_NAME}:
    image: ${IMAGE_FULL_NAME}
    container_name: ${IMAGE_NAME}-prod
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      JAVA_OPTS: "-Xms512m -Xmx2048m -Xmn256m -XX:+UseG1GC -Dspring.profiles.active=prod"
      LANG: "zh_CN.UTF-8"
      TZ: "Asia/Shanghai"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3