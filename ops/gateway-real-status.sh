#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-18789}"
WS_URL="ws://127.0.0.1:${PORT}"
DASH="http://127.0.0.1:${PORT}/"

ok=1

echo "=== OpenClaw 网关真实状态验收 ==="
echo "time: $(date '+%F %T')"

echo "[1/4] systemd 状态"
if systemctl --user is-active openclaw-gateway.service >/dev/null 2>&1; then
  echo "[ok] systemd: active"
else
  echo "[x] systemd: inactive"
  ok=0
fi

echo "[2/4] 端口监听"
if ss -lntp 2>/dev/null | grep -q ":${PORT} "; then
  echo "[ok] port ${PORT}: listening"
else
  echo "[x] port ${PORT}: not listening"
  ok=0
fi

echo "[3/4] HTTP 探活"
if command -v curl >/dev/null 2>&1 && curl -fsS --max-time 3 "$DASH" >/dev/null 2>&1; then
  echo "[ok] http dashboard: reachable"
else
  echo "[x] http dashboard: unreachable"
  ok=0
fi

echo "[4/4] RPC 探活"
STATUS_OUT="$(openclaw gateway status 2>&1 || true)"
if echo "$STATUS_OUT" | grep -q "RPC probe: ok"; then
  echo "[ok] rpc probe: ok"
else
  echo "[x] rpc probe: fail"
  ok=0
fi

echo "--- gateway status 摘要 ---"
echo "$STATUS_OUT" | sed -n '1,25p'

if [[ $ok -eq 1 ]]; then
  echo "[PASS] 网关真实可用（即使 runtime 文案偶发异常）"
  exit 0
else
  echo "[FAIL] 网关未通过真实状态验收"
  echo "建议: systemctl --user restart openclaw-gateway.service"
  exit 1
fi
