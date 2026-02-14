#!/usr/bin/env bash
set -euo pipefail

# 一键初始化工具包（新机器可用）
# 用法：bash bootstrap-toolkit.sh

WORKSPACE="/root/.openclaw/workspace"
OPS_DIR="$WORKSPACE/ops"
SECRETS_DIR="/root/.secrets"
LOG_DIR="/root/.openclaw"

log(){ echo "[$(date '+%F %T')] $*"; }
need_root(){ [[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo "请用 root 执行"; exit 1; }; }
cmd_exists(){ command -v "$1" >/dev/null 2>&1; }

install_deps(){
  log "安装基础依赖..."
  if cmd_exists dnf; then
    dnf install -y bash tar gzip coreutils curl jq openssl cronie util-linux findutils procps-ng iproute openssh-clients >/dev/null || true
  elif cmd_exists apt-get; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null || true
    apt-get install -y bash tar gzip coreutils curl jq openssl cron util-linux findutils procps iproute2 openssh-client >/dev/null || true
  else
    log "未识别包管理器，跳过依赖安装（请手动安装 bash/tar/curl/jq/openssl/cron）"
  fi

  if ! cmd_exists node || ! cmd_exists npm; then
    log "检测到缺少 node/npm，尝试安装 Node 24..."
    if cmd_exists dnf; then
      dnf module reset nodejs -y >/dev/null 2>&1 || true
      dnf module disable nodejs -y >/dev/null 2>&1 || true
      curl -fsSL https://rpm.nodesource.com/setup_24.x | bash - >/dev/null 2>&1 || true
      dnf install -y nodejs >/dev/null 2>&1 || true
    elif cmd_exists apt-get; then
      curl -fsSL https://deb.nodesource.com/setup_24.x | bash - >/dev/null 2>&1 || true
      apt-get install -y nodejs >/dev/null 2>&1 || true
    fi
  fi
}

ensure_dirs(){
  mkdir -p "$SECRETS_DIR" "$LOG_DIR" "$WORKSPACE" "$OPS_DIR"
  chmod 700 "$SECRETS_DIR" || true
}

ensure_env_templates(){
  log "创建/检查 secrets 模板..."
  [[ -f "$SECRETS_DIR/pc-bridge.env" ]] || cp -f "$OPS_DIR/pc-bridge.env.example" "$SECRETS_DIR/pc-bridge.env" 2>/dev/null || true
  [[ -f "$SECRETS_DIR/cloud-backup.env" ]] || cat > "$SECRETS_DIR/cloud-backup.env" <<'EOF'
R2_BUCKET=你的bucket
R2_ENDPOINT=https://<accountid>.r2.cloudflarestorage.com
AWS_ACCESS_KEY_ID=xxx
AWS_SECRET_ACCESS_KEY=xxx
BACKUP_PASSPHRASE=你自己设的强口令
EOF
  [[ -f "$SECRETS_DIR/offline-alert.env" ]] || cp -f "$OPS_DIR/offline-alert.env.example" "$SECRETS_DIR/offline-alert.env" 2>/dev/null || true
  chmod 600 "$SECRETS_DIR"/*.env 2>/dev/null || true
}

install_cron_jobs(){
  log "安装守护 cron..."
  if [[ -x "$OPS_DIR/install-cron.sh" ]]; then
    bash "$OPS_DIR/install-cron.sh" >/dev/null || true
  else
    log "未找到 $OPS_DIR/install-cron.sh，跳过"
  fi
}

enable_gateway_service(){
  log "修复/启用 gateway user service..."
  if cmd_exists openclaw; then
    openclaw gateway install >/dev/null 2>&1 || true
    systemctl --user enable --now openclaw-gateway.service >/dev/null 2>&1 || true
  fi
  loginctl enable-linger root >/dev/null 2>&1 || true
}

self_check(){
  log "首轮自检："
  echo "- node: $(node -v 2>/dev/null || echo missing)"
  echo "- npm : $(npm -v 2>/dev/null || echo missing)"
  echo "- openclaw: $(openclaw --version 2>/dev/null || echo missing)"
  echo "- gateway: $(systemctl --user is-active openclaw-gateway.service 2>/dev/null || echo unknown)"
  echo "- cron lines: $(crontab -l 2>/dev/null | wc -l | tr -d ' ')"
  echo "- menu: bash $OPS_DIR/onekit-menu-zh.sh"
}

main(){
  need_root
  install_deps
  ensure_dirs
  ensure_env_templates
  install_cron_jobs
  enable_gateway_service
  self_check
  log "初始化完成。"
}

main "$@"
