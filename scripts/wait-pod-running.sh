#!/bin/bash
set +x
NAMESPACE="$1"
APP_NAME="$2"

if [[ -z "$NAMESPACE" || -z "$APP_NAME" ]]; then
  echo "用法: $0 <namespace> <appName>"
  exit 2
fi

echo "⏳ 等待 Pod 启动... (ns=${NAMESPACE}, app=${APP_NAME})"
source /tmp/deploy_time.env 2>/dev/null || true

MAX_RETRIES=120
SLEEP_SECONDS=3

# 选择 jq 可执行文件；若系统无 jq，则尝试临时下载一个静态二进制
JQ_BIN="jq"
if ! command -v "$JQ_BIN" >/dev/null 2>&1; then
  JQ_BIN="/tmp/jq"
  if [[ ! -x "$JQ_BIN" ]]; then
    echo "未检测到系统 jq，尝试临时下载到 $JQ_BIN"
    JQ_URL="https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64"
    # 优先使用 curl，其次 wget；下载失败则继续后续流程并让命令报错
    (curl -fsSL -o "$JQ_BIN" "$JQ_URL" || wget -qO "$JQ_BIN" "$JQ_URL") || true
    chmod +x "$JQ_BIN" 2>/dev/null || true
  fi
fi

for ((i=1; i<=MAX_RETRIES; i++)); do
    PODS_JSON=$(kubectl get pods -n "${NAMESPACE}" -l k8s-app="${APP_NAME}" -o json 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo "⚠️  无法获取 Pod 信息，重试..."
        sleep $SLEEP_SECONDS
        continue
    fi  

    READY_COUNT=$(echo "$PODS_JSON" | "$JQ_BIN" --argjson start_time "$DEPLOY_START_TIME" '
        [.items[]
            | select(.status.phase == "Running")
            | select(.status.containerStatuses != null)
            | select(.status.containerStatuses[]?.ready == true)
            | select((.metadata.creationTimestamp | sub("Z$"; "") | sub("T"; " ") | strptime("%Y-%m-%d %H:%M:%S") | mktime) >= $start_time)
        ] | length
    ')  
    EXPECTED_REPLICAS=$(kubectl get deploy -n "${NAMESPACE}" "${APP_NAME}" -o jsonpath="{.spec.replicas}" 2>/dev/null || echo "1")

    echo "第 $i 次检测：新就绪 Pod 数量: $READY_COUNT / 期望副本数: $EXPECTED_REPLICAS"

    if [[ "$READY_COUNT" -eq "$EXPECTED_REPLICAS" ]]; then
        echo "✅ 最新部署的 Pod 均已就绪" 
        kubectl get pods -n "${NAMESPACE}" -l k8s-app="${APP_NAME}" -o wide
        kubectl get svc -n "${NAMESPACE}" -l k8s-app="${APP_NAME}"
        rm -f /tmp/deploy_time.env
        exit 0
    fi  

    sleep $SLEEP_SECONDS
done

echo "❌ 部署超时，Pod 未全部就绪" 
kubectl get pods -n "${NAMESPACE}" -o wide
kubectl describe pods -n "${NAMESPACE}" -l k8s-app="${APP_NAME}"
exit 1