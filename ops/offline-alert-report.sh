#!/usr/bin/env bash
set -euo pipefail
LOG_FILE="/root/.openclaw/offline-alert.log"
if [[ -f "$LOG_FILE" ]]; then
  tail -n 80 "$LOG_FILE"
else
  echo "暂无离线告警日志"
fi
