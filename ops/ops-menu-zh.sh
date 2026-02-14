#!/usr/bin/env bash
set -euo pipefail

OPS_DIR="$(cd "$(dirname "$0")" && pwd)"

ok(){ echo "\n✅ 成功：$1\n"; }
err(){ echo "\n❌ 失败：$1\n"; }
press(){ read -r -p "回车继续..." _; }
run(){
  local title="$1"; shift
  echo "\n>>> $title"
  if "$@"; then ok "$title"; else err "$title"; fi
}

menu_gateway(){
  while true; do
    clear
    cat <<'EOF'
===== 网关 / 更新 =====
1) 查看 OpenClaw 状态
2) 启动 Gateway
3) 停止 Gateway
4) 重启 Gateway
5) 查看当前版本
6) 检查更新
7) 更新 OpenClaw（低内存模式）
0) 返回上级
EOF
    read -r -p "选择: " c
    case "$c" in
      1) run "openclaw status" openclaw status; press;;
      2) run "gateway start" openclaw gateway start; press;;
      3) run "gateway stop" openclaw gateway stop; press;;
      4) run "gateway restart" openclaw gateway restart; press;;
      5) run "openclaw --version" openclaw --version; press;;
      6) run "openclaw update status" openclaw update status; press;;
      7) export NODE_OPTIONS="--max-old-space-size=1024"; run "低内存更新" openclaw update; press;;
      0) return;;
      *) echo "无效选择"; sleep 1;;
    esac
  done
}

menu_backup(){
  while true; do
    clear
    cat <<'EOF'
===== 备份 / 恢复 =====
1) 初始化备份仓库（setup-backup）
2) 执行一次备份（backup-workspace）
3) 查看备份标签（daily-...）
4) 恢复到当前分支远端（危险）
5) 按标签恢复（危险）
0) 返回上级
EOF
    read -r -p "选择: " c
    case "$c" in
      1) run "setup-backup" bash "$OPS_DIR/setup-backup.sh"; press;;
      2) run "backup-workspace" bash "$OPS_DIR/backup-workspace.sh"; press;;
      3) git -C "$HOME/.openclaw/workspace" tag -l 'daily-*' | tail -n 30; press;;
      4) run "恢复到远端当前分支" bash "$OPS_DIR/restore-workspace.sh"; press;;
      5) read -r -p "输入标签名(如 daily-2026-02-13): " tag; run "按标签恢复 $tag" bash "$OPS_DIR/restore-workspace.sh" "$tag"; press;;
      0) return;;
      *) echo "无效选择"; sleep 1;;
    esac
  done
}

menu_antfarm(){
  while true; do
    clear
    cat <<'EOF'
===== Antfarm（冷配置） =====
1) 查看冷配置状态
2) 启用全部工作流
3) 启用单个工作流
4) 停用并释放资源
0) 返回上级
EOF
    read -r -p "选择: " c
    case "$c" in
      1) run "antfarm 冷状态" bash "$OPS_DIR/antfarm-cold-status.sh"; press;;
      2) run "antfarm 启用全部" bash "$OPS_DIR/antfarm-enable.sh"; press;;
      3) read -r -p "输入工作流ID(如 feature-dev): " wf; run "antfarm 启用 $wf" bash "$OPS_DIR/antfarm-enable.sh" "$wf"; press;;
      4) run "antfarm 停用" bash "$OPS_DIR/antfarm-disable.sh"; press;;
      0) return;;
      *) echo "无效选择"; sleep 1;;
    esac
  done
}

menu_memos(){
  while true; do
    clear
    cat <<'EOF'
===== MemOS 插件 =====
1) 查看状态
2) 开启
3) 关闭
4) 运行一次自动切换巡检
0) 返回上级
EOF
    read -r -p "选择: " c
    case "$c" in
      1) run "memos status" bash "$OPS_DIR/memosctl.sh" status; press;;
      2) run "memos on" bash "$OPS_DIR/memosctl.sh" on manual; press;;
      3) run "memos off" bash "$OPS_DIR/memosctl.sh" off manual; press;;
      4) run "memos auto-switch" bash "$OPS_DIR/memos-auto-switch.sh"; press;;
      0) return;;
      *) echo "无效选择"; sleep 1;;
    esac
  done
}

menu_guard(){
  while true; do
    clear
    cat <<'EOF'
===== 守护 / 定时任务 =====
1) 执行一次网关守护
2) 执行一次模型守护
3) 执行一次内存守护
4) 安装 cron 定时任务
5) 查看当前 crontab
0) 返回上级
EOF
    read -r -p "选择: " c
    case "$c" in
      1) run "watchdog-gateway" bash "$OPS_DIR/watchdog-gateway.sh"; press;;
      2) run "model-failover-guard" bash "$OPS_DIR/model-failover-guard.sh"; press;;
      3) run "memory-pressure-guard" bash "$OPS_DIR/memory-pressure-guard.sh"; press;;
      4) run "install-cron" bash "$OPS_DIR/install-cron.sh"; press;;
      5) crontab -l || true; press;;
      0) return;;
      *) echo "无效选择"; sleep 1;;
    esac
  done
}

menu_xbot(){
  while true; do
    clear
    cat <<'EOF'
===== XBot =====
1) 启动 xbot
2) 查看 xbot 状态
3) 停止 xbot
0) 返回上级
EOF
    read -r -p "选择: " c
    case "$c" in
      1) run "xbot 启动" bash "$OPS_DIR/xbot-start.sh"; press;;
      2) run "xbot 状态" bash "$OPS_DIR/xbot-status.sh"; press;;
      3) run "xbot 停止" bash "$OPS_DIR/xbot-stop.sh"; press;;
      0) return;;
      *) echo "无效选择"; sleep 1;;
    esac
  done
}

menu_diag(){
  clear
  echo "===== 快速诊断 ====="
  echo "时间: $(date -Is)"
  echo
  openclaw --version || true
  echo
  openclaw gateway status || true
  echo
  free -h || true
  echo
  df -h / || true
  press
}

menu_toolbox(){
  while true; do
    clear
    cat <<'EOF'
===== 其他工具 =====
1) free-search 关键词搜索
2) bird-x 状态/环境检查
3) 打开 ops 目录文件清单
4) 云端备份（GitHub + R2）
5) 云端备份列表（R2）
6) 云端恢复（R2）
7) 打开云备份说明文档
0) 返回上级
EOF
    read -r -p "选择: " c
    case "$c" in
      1) read -r -p "输入搜索关键词: " q; run "free-search: $q" bash "$OPS_DIR/free-search.sh" "$q" 8; press;;
      2) run "bird-x 环境检查" bash "$OPS_DIR/bird-x.sh" --help; press;;
      3) ls -lah "$OPS_DIR"; press;;
      4) read -r -p "备份模式 small/full (默认 small): " mode; mode=${mode:-small}; run "云端备份($mode)" bash "$OPS_DIR/cloud-backup.sh" "$mode"; press;;
      5) run "云端列表" bash "$OPS_DIR/cloud-list.sh"; press;;
      6) read -r -p "输入 R2 对象名(如 openclaw-full-xxx.tgz.enc): " obj; run "云端恢复 $obj" bash "$OPS_DIR/cloud-restore.sh" "$obj"; press;;
      7) cat "$OPS_DIR/README-CLOUD-BACKUP-ZH.md"; press;;
      0) return;;
      *) echo "无效选择"; sleep 1;;
    esac
  done
}

while true; do
  clear
  cat <<'EOF'
==============================
 OpenClaw 运维总控台（中文）
==============================
1) 网关 / 更新
2) 备份 / 恢复
3) Antfarm（冷配置）
4) MemOS 插件
5) 守护 / 定时任务
6) XBot
7) 快速诊断
8) 查看中文说明文档
9) 其他工具
10) 灾难恢复工具（OpenClaw挂了也能用）
11) 插件/技能管理（中文）
0) 退出
EOF
  read -r -p "请选择: " main
  case "$main" in
    1) menu_gateway ;;
    2) menu_backup ;;
    3) menu_antfarm ;;
    4) menu_memos ;;
    5) menu_guard ;;
    6) menu_xbot ;;
    7) menu_diag ;;
    8) cat "$OPS_DIR/README-OPS-ZH.md"; press ;;
    9) menu_toolbox ;;
    10) clear; cat "$OPS_DIR/README-DISASTER-ZH.md"; press ;;
    11)
      while true; do
        clear
        cat <<'EOF'
===== 插件 / 技能管理（中文） =====
1) 查看插件列表与开关状态
2) 开启某插件
3) 关闭某插件
4) 查看技能清单（系统+自定义）
5) 查看功能名中文对照文档
0) 返回上级
EOF
        read -r -p "选择: " p
        case "$p" in
          1) bash "$OPS_DIR/plugin-manager.sh" list; press ;;
          2) read -r -p "输入插件ID: " k; bash "$OPS_DIR/plugin-manager.sh" on "$k"; press ;;
          3) read -r -p "输入插件ID: " k; bash "$OPS_DIR/plugin-manager.sh" off "$k"; press ;;
          4) bash "$OPS_DIR/skill-list.sh"; press ;;
          5) cat "$OPS_DIR/README-FUNCTION-MAP-ZH.md"; press ;;
          0) break ;;
          *) echo "无效选择"; sleep 1 ;;
        esac
      done
      ;;
    0) echo "已退出"; exit 0 ;;
    *) echo "无效选择"; sleep 1 ;;
  esac
done
