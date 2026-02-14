#!/usr/bin/env bash
set -euo pipefail

OPS_DIR="/root/.openclaw/workspace/ops"
ENV_PC="/root/.secrets/pc-bridge.env"
ENV_CLOUD="/root/.secrets/cloud-backup.env"

press(){ read -r -p "回车继续..." _; }

show_win_cmds(){
  local pubkey=""
  if [[ -f "$ENV_PC" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_PC"
  fi
  local pub="${PC_KEY:-/root/.ssh/openclaw_win_ed25519}.pub"
  if [[ -f "$pub" ]]; then
    pubkey="$(cat "$pub")"
  fi

  local cmd
  cmd=$(cat <<'EOF'
请在你的 Windows（管理员 PowerShell）执行：

# 1) 启用并启动 sshd
Get-Service sshd | Set-Service -StartupType Automatic
Start-Service sshd

# 2) 放行 22 端口（若已配置可跳过）
netsh advfirewall firewall add rule name="OpenSSH-Server-In-TCP" dir=in action=allow protocol=TCP localport=22

# 3) 写入 VPS 公钥（免密登录）
New-Item -ItemType Directory -Force -Path C:\ProgramData\ssh | Out-Null
New-Item -ItemType File -Force -Path C:\ProgramData\ssh\administrators_authorized_keys | Out-Null
"__PUBKEY__" | Add-Content -Path C:\ProgramData\ssh\administrators_authorized_keys
icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r
icacls C:\ProgramData\ssh\administrators_authorized_keys /grant "Administrators:F" "SYSTEM:F"

# 4) 启动 frpc（自动找路径；找不到就给明确报错）
$frpcCandidates = @(
  'D:\aizhushou\frp\frpc.exe',
  'D:\frp\frpc.exe',
  'C:\frp\frpc.exe',
  'C:\Users\51183\frp\frp_0.58.1_windows_amd64\frpc.exe'
)
$frpc = $frpcCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $frpc) {
  $frpc = Get-ChildItem -Path 'C:\Users' -Filter frpc.exe -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\frp\\' } |
    Select-Object -ExpandProperty FullName -First 1
}
if (-not $frpc) {
  Write-Host '未找到 frpc.exe。已自动搜索 D:/ C:/ 和 C:/Users/**/frp/**' -ForegroundColor Red
  Write-Host '并确保存在 frpc.toml 配置文件（含 60022 映射）' -ForegroundColor Yellow
  return
}
$frpDir = Split-Path $frpc -Parent
$config = Join-Path $frpDir 'frpc.toml'
if (-not (Test-Path $config)) {
  Write-Host "找到 frpc.exe，但缺少配置文件: $config" -ForegroundColor Red
  return
}
Set-Location $frpDir
& $frpc -c $config
EOF
)
  echo "${cmd/__PUBKEY__/$pubkey}"
}

wizard_pc_backup(){
  while true; do
    clear
    cat <<'EOF'
===== 向导：备份到我的电脑（VPS -> Windows）=====
你只要按顺序：1 -> 2 -> 3
1) 第1步：自动写入连接配置模板 + VPS环境自检
2) 第2步：显示“Windows要复制执行”的命令
3) 第3步：一键备份并上传到你的电脑
4) （可选）仅测试远程连接
0) 返回上级
EOF
    read -r -p "选择: " c
    case "$c" in
      1)
        mkdir -p /root/.secrets
        if [[ ! -f "$ENV_PC" ]]; then
          cp -f "$OPS_DIR/pc-bridge.env.example" "$ENV_PC"
          chmod 600 "$ENV_PC"
          echo "[ok] 已自动创建: $ENV_PC"
          echo "[提示] 如有变更，后续再改这个文件即可"
        else
          echo "[ok] 已存在: $ENV_PC"
        fi
        echo
        echo "[检查] 加载配置并自检"
        # shellcheck disable=SC1090
        source "$ENV_PC"
        echo "PC_HOST=${PC_HOST:-?}"
        echo "PC_PORT=${PC_PORT:-?}"
        echo "PC_USER=${PC_USER:-?}"
        echo "PC_KEY=${PC_KEY:-?}"
        echo "PC_DEST_DIR=${PC_DEST_DIR:-?}"
        if [[ -n "${PC_KEY:-}" && ! -f "$PC_KEY" ]]; then
          mkdir -p "$(dirname "$PC_KEY")"
          ssh-keygen -t ed25519 -N "" -f "$PC_KEY" -C "openclaw-vps-to-win" >/dev/null
          chmod 600 "$PC_KEY"
          echo "[ok] 私钥不存在，已自动生成: $PC_KEY"
          echo "[ok] 公钥: ${PC_KEY}.pub（第2步会自动显示可复制命令）"
        elif [[ -n "${PC_KEY:-}" && -f "$PC_KEY" ]]; then
          echo "[ok] 私钥存在"
        else
          echo "[x] PC_KEY 为空"
        fi
        if [[ -n "${PC_HOST:-}" && -n "${PC_PORT:-}" ]]; then
          timeout 5 bash -c "</dev/tcp/${PC_HOST}/${PC_PORT}" 2>/dev/null && echo "[ok] 端口可达" || echo "[x] 端口不通（先做第2步，在Windows启动sshd+frpc）"
        fi
        echo
        echo "下一步：选 2（去Windows复制命令执行）"
        press
        ;;
      2)
        show_win_cmds
        echo
        echo "执行完后回到这里，选 3（自动上传备份）"
        press
        ;;
      3)
        if bash "$OPS_DIR/pc-backup-push.sh"; then
          echo "[ok] 已完成上传。你的电脑目录里可看到备份包。"
        else
          echo "[x] 上传失败：先回第2步检查Windows服务是否真的启动。"
        fi
        press
        ;;
      4)
        bash "$OPS_DIR/pc-connect.sh" || true
        press
        ;;
      0) return ;;
      *) echo "无效选择"; sleep 1 ;;
    esac
  done
}

wizard_cloud_backup(){
  while true; do
    clear
    cat <<'EOF'
===== 向导：云端备份（R2 + GitHub）=====
1) 第1步：检查 cloud 配置是否存在
2) 第2步：输出模板（复制到 /root/.secrets/cloud-backup.env）
3) 第3步：测试云端列表
4) 第4步：执行云端备份（small）
5) 第5步：执行云端备份（full）
0) 返回上级
EOF
    read -r -p "选择: " c
    case "$c" in
      1)
        mkdir -p /root/.secrets
        if [[ ! -f "$ENV_CLOUD" ]]; then
          cat > "$ENV_CLOUD" <<'EOF'
R2_BUCKET=你的bucket
R2_ENDPOINT=https://<accountid>.r2.cloudflarestorage.com
AWS_ACCESS_KEY_ID=xxx
AWS_SECRET_ACCESS_KEY=xxx
BACKUP_PASSPHRASE=你自己设的强口令
EOF
          chmod 600 "$ENV_CLOUD"
          echo "[ok] 已自动创建模板: $ENV_CLOUD"
          echo "[下一步] 打开这个文件填真实值，然后回到第3步测试连通"
        else
          echo "[ok] $ENV_CLOUD 存在"
        fi
        press
        ;;
      2)
        cat <<'EOF'
R2_BUCKET=你的bucket
R2_ENDPOINT=https://<accountid>.r2.cloudflarestorage.com
AWS_ACCESS_KEY_ID=xxx
AWS_SECRET_ACCESS_KEY=xxx
BACKUP_PASSPHRASE=你自己设的强口令
EOF
        press
        ;;
      3)
        bash "$OPS_DIR/cloud-list.sh" || true
        press
        ;;
      4)
        bash "$OPS_DIR/cloud-backup.sh" small || true
        press
        ;;
      5)
        bash "$OPS_DIR/cloud-backup.sh" full || true
        press
        ;;
      0) return ;;
      *) echo "无效选择"; sleep 1 ;;
    esac
  done
}

while true; do
  clear
  cat <<'EOF'
===== 一步一步向导模式（新手专用）=====
1) 备份到我的电脑（分4步）
2) 云端备份（分5步）
0) 返回上级
EOF
  read -r -p "选择: " m
  case "$m" in
    1) wizard_pc_backup ;;
    2) wizard_cloud_backup ;;
    0) exit 0 ;;
    *) echo "无效选择"; sleep 1 ;;
  esac
done
