#!/usr/bin/env bash
set -euo pipefail

# 低内存安全升级（带自动回滚）
# 用法: bash update-safe.sh

LOG_DIR="/root/.openclaw"
STATE_FILE="$LOG_DIR/update-safe.state"
LOG_FILE="$LOG_DIR/update-safe.log"
mkdir -p "$LOG_DIR"

log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }

rollback(){
  local prev="$1"
  log "触发回滚 -> openclaw@$prev"
  export NODE_OPTIONS="--max-old-space-size=1024"
  npm install -g "openclaw@${prev}" --no-fund --no-audit --maxsockets 1 --loglevel warn || true
  systemctl --user restart openclaw-gateway.service || true
  sleep 2
  systemctl --user is-active openclaw-gateway.service || true
}

pre_ver="$(openclaw --version 2>/dev/null || echo unknown)"
log "升级前版本: $pre_ver"
printf 'pre_version=%s\nstart_at=%s\n' "$pre_ver" "$(date -Is)" > "$STATE_FILE"

# 升级前先做一个本地灾备包
if [[ -x /root/.openclaw/workspace/ops/disaster-backup.sh ]]; then
  log "执行升级前备份"
  bash /root/.openclaw/workspace/ops/disaster-backup.sh /root/backups || true
fi

log "开始低内存升级 latest"
export NODE_OPTIONS="--max-old-space-size=1024"
if ! npm install -g openclaw@latest --no-fund --no-audit --maxsockets 1 --loglevel warn; then
  log "升级命令失败"
  [[ "$pre_ver" != "unknown" ]] && rollback "$pre_ver"
  exit 1
fi

log "重启 gateway 并验收"
systemctl --user restart openclaw-gateway.service || true
sleep 3
active="$(systemctl --user is-active openclaw-gateway.service 2>/dev/null || true)"
new_ver="$(openclaw --version 2>/dev/null || echo unknown)"
log "升级后版本: $new_ver, service=$active"

if [[ "$active" != "active" || "$new_ver" == "unknown" ]]; then
  log "验收失败，自动回滚"
  [[ "$pre_ver" != "unknown" ]] && rollback "$pre_ver"
  exit 1
fi

log "升级成功"
printf 'post_version=%s\nend_at=%s\n' "$new_ver" "$(date -Is)" >> "$STATE_FILE"
