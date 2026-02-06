FROM registry.cn-hangzhou.aliyuncs.com/tianxiang_app/jdk-8u421:v1.8.0_421

MAINTAINER zhentianxiang

# 构建参数
ARG PORT=8080
ARG LANG=zh_CN.UTF-8
ARG TZ=Asia/Shanghai
ARG PROFILE=dev
ARG JAR_FILE
ARG SPRING_PROFILES_ACTIVE

# 环境变量
ENV JAVA_OPTS="-Dspring.profiles.active=${PROFILE} -Dfile.encoding=UTF-8"
ENV SPRING_PROFILES_ACTIVE=${SPRING_PROFILES_ACTIVE}
ENV PORT=${PORT}
ENV USER=root
ENV APP_HOME=/home/${USER}/apps
ENV LANG=${LANG}
ENV TZ=${TZ}

# 创建工作目录
RUN mkdir -p ${APP_HOME}

# 复制文件
COPY ${JAR_FILE} ${APP_HOME}/app.jar

# 设置工作目录
WORKDIR ${APP_HOME}

# 暴露端口
EXPOSE ${PORT}

# 启动命令 - 选择一种方式

# 方式1: 直接使用java命令启动（推荐）
CMD java ${JAVA_OPTS} -jar ${APP_HOME}/app.jar --server.port=${PORT}

# 方式2: 通过start.sh脚本启动
# CMD ["sh", "-c", "${APP_HOME}/start.sh"]

# 方式3: 使用exec格式
# ENTRYPOINT ["java", "${JAVA_OPTS}", "-jar", "app.jar", "--server.port=${PORT}"]
