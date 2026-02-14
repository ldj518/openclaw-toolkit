#!/usr/bin/env bash
set -euo pipefail

# 一键恢复：升级失败/被OOM kill后使用
# 用法: bash update-recover.sh

STATE_FILE="/root/.openclaw/update-safe.state"
LOG_FILE="/root/.openclaw/update-safe.log"

pre_ver=""
if [[ -f "$STATE_FILE" ]]; then
  pre_ver="$(grep '^pre_version=' "$STATE_FILE" | tail -n1 | cut -d= -f2- || true)"
fi

if [[ -z "$pre_ver" || "$pre_ver" == "unknown" ]]; then
  echo "[x] 找不到可回滚版本（$STATE_FILE）"
  echo "[tip] 手动指定: npm install -g openclaw@2026.2.12"
  exit 1
fi

echo "[1/3] 回滚 openclaw@$pre_ver"
export NODE_OPTIONS="--max-old-space-size=1024"
npm install -g "openclaw@${pre_ver}" --no-fund --no-audit --maxsockets 1 --loglevel warn

echo "[2/4] 修复命令入口（若缺失）"
if ! command -v openclaw >/dev/null 2>&1; then
  if [[ -f /usr/lib/node_modules/openclaw/dist/index.js ]]; then
    cat > /usr/bin/openclaw <<'EOF'
#!/usr/bin/env bash
exec node /usr/lib/node_modules/openclaw/dist/index.js "$@"
EOF
    chmod +x /usr/bin/openclaw
    echo "[ok] 已修复 /usr/bin/openclaw"
  else
    echo "[x] 找不到 /usr/lib/node_modules/openclaw/dist/index.js" >&2
  fi
fi

echo "[3/4] 重启服务"
systemctl --user restart openclaw-gateway.service
sleep 2

echo "[4/4] 验收"
openclaw --version || true
systemctl --user is-active openclaw-gateway.service || true
openclaw gateway status || true

echo "[ok] 恢复完成"
echo "日志: $LOG_FILE"
