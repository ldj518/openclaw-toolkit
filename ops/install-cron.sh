#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
CRON_TMP="$(mktemp)"

backup_job="*/30 * * * * $WORKSPACE/ops/backup-workspace.sh >> $HOME/.openclaw/backup.log 2>&1"
watchdog_job="*/1 * * * * $WORKSPACE/ops/watchdog-gateway.sh >> $HOME/.openclaw/watchdog-cron.log 2>&1"
model_guard_job="*/10 * * * * $WORKSPACE/ops/model-failover-guard.sh"
memory_guard_job="*/3 * * * * $WORKSPACE/ops/memory-pressure-guard.sh"
offline_alert_job="*/2 * * * * $WORKSPACE/ops/offline-alert-check.sh >> $HOME/.openclaw/offline-alert-cron.log 2>&1"
boot_job="@reboot systemctl --user restart openclaw-gateway.service >> $HOME/.openclaw/gateway-boot.log 2>&1"

crontab -l 2>/dev/null \
  | grep -v 'ops/backup-workspace.sh' \
  | grep -v 'ops/watchdog-gateway.sh' \
  | grep -v 'ops/model-failover-guard.sh' \
  | grep -v 'ops/memory-pressure-guard.sh' \
  | grep -v 'ops/offline-alert-check.sh' \
  | grep -v 'gateway-boot.log' > "$CRON_TMP" || true

{
  cat "$CRON_TMP"
  echo "$backup_job"
  echo "$watchdog_job"
  echo "$model_guard_job"
  echo "$memory_guard_job"
  echo "$offline_alert_job"
  echo "$boot_job"
} | awk '!seen[$0]++' | crontab -

rm -f "$CRON_TMP"
echo "[ok] cron jobs installed"
crontab -l | grep -E 'backup-workspace|watchdog-gateway|model-failover-guard|memory-pressure-guard|offline-alert-check' || true
