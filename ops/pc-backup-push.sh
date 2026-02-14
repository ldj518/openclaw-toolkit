#!/usr/bin/env bash
set -euo pipefail

# 一键：在VPS打包 -> 推送到你的Windows电脑
# 包含：
# 1) 灾难恢复全量包（.openclaw/.secrets/.ssh）
# 2) 工具包与中文文档包（ops + rescue-kit + README）

ENV_FILE="${ENV_FILE:-/root/.secrets/pc-bridge.env}"
[[ -f "$ENV_FILE" ]] || { echo "[x] 缺少 $ENV_FILE (可参考 ops/pc-bridge.env.example)"; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"

: "${PC_HOST:?missing PC_HOST}"
: "${PC_PORT:?missing PC_PORT}"
: "${PC_USER:?missing PC_USER}"
: "${PC_KEY:?missing PC_KEY}"
: "${PC_DEST_DIR:?missing PC_DEST_DIR}"

[[ -f "$PC_KEY" ]] || { echo "[x] 私钥不存在: $PC_KEY"; echo "    请把私钥放到该路径，或修改 /root/.secrets/pc-bridge.env"; exit 1; }
if ! timeout 5 bash -c "</dev/tcp/${PC_HOST}/${PC_PORT}" 2>/dev/null; then
  echo "[x] 连接失败: ${PC_HOST}:${PC_PORT} 不通（可能 FRP/Windows sshd 未启动）"
  exit 1
fi

TS="$(date +%F_%H%M%S)"
OUT="/root/backups"
mkdir -p "$OUT"

echo "[1/5] 生成灾难恢复备份"
bash /root/.openclaw/workspace/ops/disaster-backup.sh "$OUT"
LAST_TGZ="$(ls -1t "$OUT"/openclaw-disaster-*.tgz | head -n1)"
LAST_SHA="${LAST_TGZ}.sha256"
LAST_MANIFEST="${LAST_TGZ%.tgz}.manifest.txt"

echo "[2/5] 打包工具包与中文文档"
KIT="${OUT}/openclaw-toolkit-docs-${TS}.tgz"
tar -czf "$KIT" \
  /root/.openclaw/workspace/ops \
  /root/.openclaw/workspace/rescue-kit \
  /root/.openclaw/workspace/AGENTS.md \
  /root/.openclaw/workspace/SOUL.md \
  /root/.openclaw/workspace/USER.md \
  /root/.openclaw/workspace/IDENTITY.md \
  /root/.openclaw/workspace/TOOLS.md
sha256sum "$KIT" > "${KIT}.sha256"

echo "[3/5] 连接测试"
ssh -o StrictHostKeyChecking=accept-new -i "$PC_KEY" -p "$PC_PORT" "$PC_USER@$PC_HOST" "echo connected && mkdir -p '$PC_DEST_DIR'"

echo "[4/5] 上传到你的电脑"
scp -i "$PC_KEY" -P "$PC_PORT" "$LAST_TGZ" "$LAST_SHA" "$LAST_MANIFEST" "$KIT" "${KIT}.sha256" "$PC_USER@$PC_HOST:$PC_DEST_DIR/"

echo "[5/5] 完成"
echo "已上传到: $PC_USER@$PC_HOST:$PC_DEST_DIR"
echo "- $(basename "$LAST_TGZ")"
echo "- $(basename "$LAST_SHA")"
echo "- $(basename "$LAST_MANIFEST")"
echo "- $(basename "$KIT")"
echo "- $(basename "${KIT}.sha256")"
