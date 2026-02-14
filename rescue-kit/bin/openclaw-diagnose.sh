#!/usr/bin/env bash
set -euo pipefail

echo "== OpenClaw 诊断 =="
echo "time: $(date -Is)"
echo "host: $(hostname)"

echo "\n[1/7] Node/npm"
node -v 2>/dev/null || echo "node: missing"
npm -v 2>/dev/null || echo "npm : missing"

echo "\n[2/7] openclaw 可执行"
command -v openclaw >/dev/null 2>&1 && { echo "openclaw bin: $(command -v openclaw)"; openclaw --version || true; } || echo "openclaw: missing"

echo "\n[3/7] 关键目录"
for p in /root/.openclaw /root/.openclaw/openclaw.json /root/.openclaw/workspace; do
  [[ -e "$p" ]] && echo "[ok] $p" || echo "[x]  $p"
done

echo "\n[4/7] gateway status"
if command -v openclaw >/dev/null 2>&1; then
  openclaw gateway status || true
else
  echo "skip: openclaw missing"
fi

echo "\n[5/7] systemd user service"
systemctl --user is-enabled openclaw-gateway.service 2>/dev/null || true
systemctl --user is-active openclaw-gateway.service 2>/dev/null || true

echo "\n[6/7] 资源"
free -h || true
df -h / || true

echo "\n[7/7] 最近日志"
ls -1t /tmp/openclaw/openclaw-*.log 2>/dev/null | head -n1 | xargs -r tail -n 60 || true
