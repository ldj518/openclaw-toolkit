#!/usr/bin/env bash
set -euo pipefail

OPS_DIR="$(cd "$(dirname "$0")" && pwd)"
RESCUE_DIR="$OPS_DIR/../rescue-kit/bin"

ok(){ echo "[ok] $*"; }
bad(){ echo "[x]  $*"; }
warn(){ echo "[!]  $*"; }

check_file(){ [[ -f "$1" ]] && ok "脚本存在: $1" || bad "脚本缺失: $1"; }
check_cmd(){ command -v "$1" >/dev/null 2>&1 && ok "命令可用: $1" || warn "命令缺失: $1"; }

echo "===== 工具包自检 ====="
echo "time: $(date -Is)"

echo "\n[1] 关键脚本完整性"
for f in \
  "$OPS_DIR/onekit-menu-zh.sh" \
  "$OPS_DIR/task-wizard.sh" \
  "$OPS_DIR/bootstrap-toolkit.sh" \
  "$OPS_DIR/cloud-backup.sh" \
  "$OPS_DIR/cloud-restore.sh" \
  "$OPS_DIR/pc-connect.sh" \
  "$OPS_DIR/pc-backup-push.sh" \
  "$OPS_DIR/offline-alert-check.sh" \
  "$OPS_DIR/update-safe.sh" \
  "$OPS_DIR/update-recover.sh" \
  "$OPS_DIR/update-by-tarball.sh" \
  "$OPS_DIR/update-lowmem-atomic.sh" \
  "$OPS_DIR/offline-recover.sh" \
  "$OPS_DIR/gateway-real-status.sh" \
  "$OPS_DIR/openai-codex-oauth-setup.sh" \
  "$OPS_DIR/chat-knowledge.sh" \
  "$RESCUE_DIR/disaster-backup.sh" \
  "$RESCUE_DIR/disaster-restore.sh" \
  "$RESCUE_DIR/disaster-verify.sh"
  do check_file "$f"; done

echo "\n[2] 运行依赖"
for c in bash tar curl jq openssl ssh scp crontab systemctl; do check_cmd "$c"; done

echo "\n[3] 配置检查"
for envf in /root/.secrets/pc-bridge.env /root/.secrets/cloud-backup.env /root/.secrets/offline-alert.env; do
  if [[ -f "$envf" ]]; then
    ok "存在: $envf"
  else
    warn "缺失: $envf（对应功能将不可用）"
  fi
done

echo "\n[4] 服务与守护"
svc="$(systemctl --user is-active openclaw-gateway.service 2>/dev/null || true)"
[[ "$svc" == "active" ]] && ok "gateway service active" || warn "gateway service=$svc"
crontab -l 2>/dev/null | grep -E 'watchdog-gateway|model-failover-guard|memory-pressure-guard|offline-alert-check' >/dev/null && ok "关键cron存在" || warn "关键cron缺失（可运行: bash $OPS_DIR/install-cron.sh）"

echo "\n[5] 常见失败原因提示"
echo "- cloud-backup失败: 大多是 /root/.secrets/cloud-backup.env 未填真实密钥"
echo "- 电脑备份失败: 大多是 127.0.0.1:60022 不通 或 PC_KEY 不存在"
echo "- 告警不推送: /root/.secrets/offline-alert.env 未配置 TG_BOT_TOKEN/TG_CHAT_ID"
echo "- OpenClaw相关失败: gateway service 未active，先执行 systemctl --user restart openclaw-gateway.service"

echo "\n自检完成。"
