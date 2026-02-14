#!/usr/bin/env bash
set -euo pipefail

OPS_DIR="$(cd "$(dirname "$0")" && pwd)"
RESCUE_DIR="$OPS_DIR/../rescue-kit/bin"

PKG="${1:-}"
if [[ -z "$PKG" ]]; then
  PKG="$(ls -1t /root/backups/openclaw-disaster-*.tgz 2>/dev/null | head -n1 || true)"
fi

if [[ -z "$PKG" || ! -f "$PKG" ]]; then
  echo "[x] 未找到可用备份包。请传入路径：bash offline-recover.sh /root/backups/xxx.tgz" >&2
  exit 1
fi

echo "[1/4] 使用灾难包恢复: $PKG"
bash "$RESCUE_DIR/disaster-restore.sh" "$PKG" --force

echo "[2/4] 修复 openclaw 命令入口（若缺失）"
if ! command -v openclaw >/dev/null 2>&1 && [[ -f /usr/lib/node_modules/openclaw/dist/index.js ]]; then
  cat > /usr/bin/openclaw <<'EOF'
#!/usr/bin/env bash
exec node /usr/lib/node_modules/openclaw/dist/index.js "$@"
EOF
  chmod +x /usr/bin/openclaw
  echo "[ok] 已修复 /usr/bin/openclaw"
fi

echo "[3/4] 重启 gateway 服务"
systemctl --user restart openclaw-gateway.service || true
sleep 2

echo "[4/4] 验收"
systemctl --user is-active openclaw-gateway.service || true
openclaw --version 2>/dev/null || echo "[!] openclaw 命令仍不可用"
openclaw gateway status 2>/dev/null || echo "[!] gateway status 暂不可用"

echo "[ok] 离线恢复流程完成"
