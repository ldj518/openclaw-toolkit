#!/usr/bin/env bash
set -euo pipefail

# 恢复后验收（尽量不依赖 openclaw，也给出 openclaw 验收）

echo "== 基础环境 =="
echo "time: $(date -Is)"
echo "node: $(node -v 2>/dev/null || echo 'missing')"
echo "npm : $(npm -v 2>/dev/null || echo 'missing')"

echo "\n== 关键路径 =="
for p in /root/.openclaw /root/.openclaw/workspace /root/.openclaw/openclaw.json /root/.openclaw/workspace/ops; do
  if [[ -e "$p" ]]; then
    echo "[ok] $p"
  else
    echo "[x]  $p"
  fi
done

echo "\n== openclaw 可执行性 =="
if command -v openclaw >/dev/null 2>&1; then
  openclaw --version || true
  openclaw gateway status || true
else
  echo "[x] openclaw 命令不存在"
fi
