#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="/root/.openclaw"
LOG_FILE="$LOG_DIR/offline-alert.log"
STATE_FILE="$LOG_DIR/offline-alert.state"
ALERT_ENV="/root/.secrets/offline-alert.env"
mkdir -p "$LOG_DIR"

ts(){ date '+%F %T'; }
log(){ echo "[$(ts)] $*" | tee -a "$LOG_FILE" >/dev/null; }

send_tg(){
  [[ -f "$ALERT_ENV" ]] || return 0
  # shellcheck disable=SC1090
  source "$ALERT_ENV"
  [[ -n "${TG_BOT_TOKEN:-}" && -n "${TG_CHAT_ID:-}" ]] || return 0
  local text="$1"
  curl -sS -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TG_CHAT_ID}" \
    --data-urlencode "text=${text}" >/dev/null 2>&1 || true
}

SERVICE="openclaw-gateway.service"

active="$(systemctl --user is-active "$SERVICE" 2>/dev/null || true)"
enabled="$(systemctl --user is-enabled "$SERVICE" 2>/dev/null || true)"

if [[ "$active" == "active" ]]; then
  echo "last_ok=$(date +%s)" > "$STATE_FILE"
  exit 0
fi

log "告警: Gateway 不在线 (active=$active, enabled=$enabled)"
log "动作: 尝试自动拉起 systemctl --user restart $SERVICE"
systemctl --user restart "$SERVICE" >/dev/null 2>&1 || true
sleep 2
active2="$(systemctl --user is-active "$SERVICE" 2>/dev/null || true)"

if [[ "$active2" == "active" ]]; then
  log "恢复: Gateway 已自动恢复为 active"
  log "建议: 执行 'openclaw gateway status' 复核"
  send_tg "[OpenClaw告警恢复]\nGateway曾掉线，现已自动恢复。\n建议复核: openclaw gateway status"
  echo "last_recovered=$(date +%s)" >> "$STATE_FILE"
  exit 0
fi

log "严重: 自动恢复失败，当前 active=$active2"
log "建议命令1: systemctl --user status $SERVICE --no-pager"
log "建议命令2: journalctl --user -u $SERVICE -n 120 --no-pager"
log "建议命令3: openclaw gateway install && systemctl --user restart $SERVICE"
log "建议命令4: loginctl enable-linger $USER"
send_tg "[OpenClaw严重告警]\nGateway离线且自动恢复失败。\n1) systemctl --user status $SERVICE --no-pager\n2) journalctl --user -u $SERVICE -n 120 --no-pager\n3) openclaw gateway install && systemctl --user restart $SERVICE"

echo "last_fail=$(date +%s)" >> "$STATE_FILE"
exit 1
