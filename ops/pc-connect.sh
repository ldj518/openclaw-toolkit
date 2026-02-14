#!/usr/bin/env bash
set -euo pipefail
ENV_FILE="${ENV_FILE:-/root/.secrets/pc-bridge.env}"
[[ -f "$ENV_FILE" ]] || { echo "[x] 缺少 $ENV_FILE (可参考 ops/pc-bridge.env.example)"; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"

: "${PC_HOST:?missing PC_HOST}"
: "${PC_PORT:?missing PC_PORT}"
: "${PC_USER:?missing PC_USER}"
: "${PC_KEY:?missing PC_KEY}"

[[ -f "$PC_KEY" ]] || { echo "[x] 私钥不存在: $PC_KEY"; echo "    请把私钥放到该路径，或修改 /root/.secrets/pc-bridge.env"; exit 1; }

if ! timeout 5 bash -c "</dev/tcp/${PC_HOST}/${PC_PORT}" 2>/dev/null; then
  echo "[x] 连接失败: ${PC_HOST}:${PC_PORT} 不通（可能 FRP/Windows sshd 未启动）"
  exit 1
fi

exec ssh -o StrictHostKeyChecking=accept-new -i "$PC_KEY" -p "$PC_PORT" "$PC_USER@$PC_HOST"
