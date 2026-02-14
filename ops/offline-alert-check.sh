#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="/root/.openclaw"
LOG_FILE="$LOG_DIR/offline-alert.log"
STATE_FILE="$LOG_DIR/offline-alert.state"
ALERT_ENV="/root/.secrets/offline-alert.env"
mkdir -p "$LOG_DIR"

# 降噪参数（可按需调大）
RECOVER_ALERT_COOLDOWN="${RECOVER_ALERT_COOLDOWN:-1800}" # 恢复通知最小间隔：30分钟
FAIL_ALERT_COOLDOWN="${FAIL_ALERT_COOLDOWN:-600}"         # 严重告警最小间隔：10分钟
TRANSIENT_GRACE_SEC="${TRANSIENT_GRACE_SEC:-8}"           # 瞬时抖动宽限：8秒

SERVICE="openclaw-gateway.service"

ts(){ date '+%F %T'; }
now(){ date +%s; }
log(){ echo "[$(ts)] $*" | tee -a "$LOG_FILE" >/dev/null; }

state_get(){
  local k="$1"
  [[ -f "$STATE_FILE" ]] || { echo ""; return 0; }
  awk -F= -v key="$k" '$1==key{print $2}' "$STATE_FILE" | tail -n1
}

state_set(){
  local k="$1" v="$2"
  touch "$STATE_FILE"
  grep -v "^${k}=" "$STATE_FILE" > "${STATE_FILE}.tmp" || true
  echo "${k}=${v}" >> "${STATE_FILE}.tmp"
  mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

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

active="$(systemctl --user is-active "$SERVICE" 2>/dev/null || true)"
enabled="$(systemctl --user is-enabled "$SERVICE" 2>/dev/null || true)"

if [[ "$active" == "active" ]]; then
  state_set last_ok "$(now)"
  exit 0
fi

# 瞬时抖动去噪：先等几秒再判定
sleep "$TRANSIENT_GRACE_SEC"
active_retry="$(systemctl --user is-active "$SERVICE" 2>/dev/null || true)"
if [[ "$active_retry" == "active" ]]; then
  log "忽略瞬时抖动: $SERVICE 已恢复 active（grace=${TRANSIENT_GRACE_SEC}s）"
  state_set last_ok "$(now)"
  exit 0
fi

log "告警: Gateway 不在线 (active=$active_retry, enabled=$enabled)"
log "动作: 尝试自动拉起 systemctl --user restart $SERVICE"
systemctl --user restart "$SERVICE" >/dev/null 2>&1 || true
sleep 2
active2="$(systemctl --user is-active "$SERVICE" 2>/dev/null || true)"

if [[ "$active2" == "active" ]]; then
  log "恢复: Gateway 已自动恢复为 active"
  log "建议: 执行 'openclaw gateway status' 复核"

  last_recovered="$(state_get last_recovered_ts)"
  now_ts="$(now)"
  if [[ -z "$last_recovered" || $((now_ts - last_recovered)) -ge $RECOVER_ALERT_COOLDOWN ]]; then
    send_tg "[OpenClaw告警恢复]\nGateway曾掉线，现已自动恢复。\n建议复核: openclaw gateway status"
    state_set last_recovered_ts "$now_ts"
  else
    log "抑制恢复通知: 距上次恢复通知不足 ${RECOVER_ALERT_COOLDOWN}s"
  fi

  state_set last_ok "$now_ts"
  exit 0
fi

log "严重: 自动恢复失败，当前 active=$active2"
log "建议命令1: systemctl --user status $SERVICE --no-pager"
log "建议命令2: journalctl --user -u $SERVICE -n 120 --no-pager"
log "建议命令3: openclaw gateway install && systemctl --user restart $SERVICE"
log "建议命令4: loginctl enable-linger $USER"

last_fail="$(state_get last_fail_ts)"
now_ts="$(now)"
if [[ -z "$last_fail" || $((now_ts - last_fail)) -ge $FAIL_ALERT_COOLDOWN ]]; then
  send_tg "[OpenClaw严重告警]\nGateway离线且自动恢复失败。\n1) systemctl --user status $SERVICE --no-pager\n2) journalctl --user -u $SERVICE -n 120 --no-pager\n3) openclaw gateway install && systemctl --user restart $SERVICE"
  state_set last_fail_ts "$now_ts"
else
  log "抑制严重告警: 距上次严重告警不足 ${FAIL_ALERT_COOLDOWN}s"
fi

exit 1
