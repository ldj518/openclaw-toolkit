#!/usr/bin/env bash
set -euo pipefail

echo "===== 健康状态总览 ====="
echo "time: $(date -Is)"

echo "\n[1] gateway service"
systemctl --user is-enabled openclaw-gateway.service 2>/dev/null || true
systemctl --user is-active openclaw-gateway.service 2>/dev/null || true

echo "\n[2] gateway rpc"
openclaw gateway status 2>/dev/null | sed -n '1,40p' || echo "openclaw gateway status 不可用"

echo "\n[3] 最近离线告警"
if [[ -f /root/.openclaw/offline-alert.log ]]; then
  tail -n 20 /root/.openclaw/offline-alert.log
else
  echo "暂无离线告警日志"
fi

echo "\n[4] 关键守护 cron"
crontab -l 2>/dev/null | grep -E 'watchdog-gateway|model-failover-guard|memory-pressure-guard|offline-alert-check' || echo "未找到关键守护任务"
