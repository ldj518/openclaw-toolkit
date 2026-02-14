#!/usr/bin/env bash
set -euo pipefail

# 低资源守护：仅在网关异常时重启；连续失败且检测到配置错误时，回滚配置。

CONFIG="${CONFIG:-$HOME/.openclaw/openclaw.json}"
CFG_BAK_DIR="${CFG_BAK_DIR:-$HOME/.openclaw/config-backups}"
STATE_DIR="${STATE_DIR:-$HOME/.openclaw/watchdog-state}"
MAX_FAILS="${MAX_FAILS:-3}"
LOG="${LOG:-$HOME/.openclaw/watchdog.log}"

mkdir -p "$CFG_BAK_DIR" "$STATE_DIR"

fail_file="$STATE_DIR/fail-count"
[[ -f "$fail_file" ]] || echo 0 > "$fail_file"

ts() { date '+%F %T'; }
log() { echo "[$(ts)] $*" | tee -a "$LOG" >/dev/null; }

backup_config() {
  local out="$CFG_BAK_DIR/openclaw.$(date +%F_%H%M%S).json"
  cp -a "$CONFIG" "$out"
  # 保留最近 40 份
  ls -1t "$CFG_BAK_DIR"/openclaw.*.json 2>/dev/null | tail -n +41 | xargs -r rm -f
  log "backup config => $out"
}

restore_latest_config() {
  local latest
  latest="$(ls -1t "$CFG_BAK_DIR"/openclaw.*.json 2>/dev/null | head -n1 || true)"
  if [[ -z "$latest" ]]; then
    log "no config backup found; skip restore"
    return 1
  fi
  cp -a "$latest" "$CONFIG"
  log "restored config <= $latest"
}

is_gateway_healthy() {
  # 直接检查网关进程是否存在（本机无 systemd user 时最可靠）
  pgrep -f 'openclaw-gateway' >/dev/null 2>&1
}

start_gateway_detached() {
  # 脱离终端启动，避免 SSH 断开导致 SIGTERM/SIGHUP
  # 统一加载共享密钥环境（Cloudflare/GitHub 等）
  nohup bash -lc '[[ -f /root/.secrets/openclaw.env ]] && source /root/.secrets/openclaw.env; openclaw gateway' >> "$LOG" 2>&1 &
  sleep 2
  pgrep -f 'openclaw-gateway' >/dev/null 2>&1
}

restart_gateway_detached() {
  pkill -f 'openclaw-gateway' >/dev/null 2>&1 || true
  pkill -x openclaw >/dev/null 2>&1 || true
  sleep 1
  start_gateway_detached
}

has_invalid_config_error() {
  local out
  out="$(openclaw models status 2>&1 || true)"
  if grep -qiE 'invalid config|unrecognized key|Config invalid' <<<"$out"; then
    echo "$out" >> "$LOG"
    return 0
  fi
  return 1
}

main() {
  backup_config

  if is_gateway_healthy; then
    echo 0 > "$fail_file"
    log "gateway healthy"
    exit 0
  fi

  local fails
  fails="$(cat "$fail_file")"
  fails=$((fails + 1))
  echo "$fails" > "$fail_file"
  log "gateway unhealthy (fail=$fails/$MAX_FAILS), try detached restart"

  if restart_gateway_detached; then
    log "detached restart ok"
    echo 0 > "$fail_file"
    exit 0
  fi

  if (( fails >= MAX_FAILS )); then
    log "consecutive failures reached threshold"
    if has_invalid_config_error; then
      log "invalid config detected, start rollback"
      if restore_latest_config && restart_gateway_detached; then
        log "rollback + detached restart success"
        echo 0 > "$fail_file"
        exit 0
      fi
    fi
  fi

  log "watchdog finished with failure"
  exit 1
}

main "$@"
