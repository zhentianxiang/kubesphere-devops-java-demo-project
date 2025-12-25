services:
  ${IMAGE_NAME}:
    image: ${IMAGE_FULL_NAME}
    container_name: ${IMAGE_NAME}-dev
    restart: unless-stopped
    ports:
      - "${APP_PORT}:${APP_PORT}"
    environment:
      JAVA_OPTS: "-Xms512m -Xmx2048m -Xmn256m -XX:+UseG1GC -Dspring.profiles.active=dev"
      LANG: "zh_CN.UTF-8"
      TZ: "Asia/Shanghai"
      PORT: "${APP_PORT}"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3