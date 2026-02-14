#!/usr/bin/env bash
set -euo pipefail

OPS_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -d "$OPS_DIR/../rescue-kit/bin" ]]; then
  RESCUE_DIR="$OPS_DIR/../rescue-kit/bin"
else
  RESCUE_DIR="/root/.openclaw/workspace/rescue-kit/bin"
fi

ok(){ echo -e "\n✅ $1\n"; }
err(){ echo -e "\n❌ $1\n"; }
press(){ read -r -p "回车继续..." _; }
run(){
  local title="$1"; shift
  echo -e "\n>>> $title"
  if "$@"; then ok "$title"; else err "$title"; fi
}
need(){ [[ -f "$1" ]] || { echo "[x] 缺少脚本: $1"; return 1; }; }

menu_backup_all(){
  while true; do
    clear
    cat <<'EOF'
===== 统一备份/恢复 =====
1) 本地备份（git版本备份，改动可追溯）
2) 本地恢复（按标签回滚到历史版本）
3) 灾难备份（OpenClaw挂了也能用）
4) 灾难恢复（OpenClaw挂了也能用）
5) 灾难验收（恢复后自动检查是否可用）
6) 云端备份 small/full（small=小文件；full=含密钥）
7) 云端恢复（从R2下载并恢复）
8) 云端备份列表（查看可恢复时间点）
0) 返回上级
EOF
    read -r -p "选择: " c
    case "$c" in
      1) need "$OPS_DIR/backup-workspace.sh" && run "backup-workspace" bash "$OPS_DIR/backup-workspace.sh"; press ;;
      2) read -r -p "输入标签名(如 daily-2026-02-13): " tag; need "$OPS_DIR/restore-workspace.sh" && run "restore-workspace $tag" bash "$OPS_DIR/restore-workspace.sh" "$tag"; press ;;
      3) read -r -p "输出目录(默认 /root/backups): " out; out=${out:-/root/backups}; need "$RESCUE_DIR/disaster-backup.sh" && run "灾难备份" bash "$RESCUE_DIR/disaster-backup.sh" "$out"; press ;;
      4) read -r -p "输入备份包路径(.tgz): " tgz; need "$RESCUE_DIR/disaster-restore.sh" && run "灾难恢复" bash "$RESCUE_DIR/disaster-restore.sh" "$tgz"; press ;;
      5) need "$RESCUE_DIR/disaster-verify.sh" && run "灾难验收" bash "$RESCUE_DIR/disaster-verify.sh"; press ;;
      6) read -r -p "模式 small/full (默认small): " mode; mode=${mode:-small}; need "$OPS_DIR/cloud-backup.sh" && run "云端备份($mode)" bash "$OPS_DIR/cloud-backup.sh" "$mode"; press ;;
      7) read -r -p "输入对象名(如 openclaw-small-xxx.tgz.enc): " obj; need "$OPS_DIR/cloud-restore.sh" && run "云端恢复 $obj" bash "$OPS_DIR/cloud-restore.sh" "$obj"; press ;;
      8) need "$OPS_DIR/cloud-list.sh" && run "云端列表" bash "$OPS_DIR/cloud-list.sh"; press ;;
      0) return ;;
      *) echo "无效选择"; sleep 1 ;;
    esac
  done
}

menu_openclaw(){
  while true; do
    clear
    cat <<'EOF'
===== OpenClaw 运行/救援 =====
1) OpenClaw 状态（总览系统健康）
2) Gateway 启动（启动消息网关）
3) Gateway 停止（停止消息网关）
4) Gateway 重启（网关异常时常用）
5) OpenClaw 专用诊断（查版本/服务/日志）
6) OpenClaw 低内存一键救援安装（2G机器重装修复）
0) 返回上级
EOF
    read -r -p "选择: " c
    case "$c" in
      1) run "openclaw status" openclaw status; press ;;
      2) run "gateway start" openclaw gateway start; press ;;
      3) run "gateway stop" openclaw gateway stop; press ;;
      4) run "gateway restart" openclaw gateway restart; press ;;
      5) need "$RESCUE_DIR/openclaw-diagnose.sh" && run "openclaw 诊断" bash "$RESCUE_DIR/openclaw-diagnose.sh"; press ;;
      6) read -r -p "会修改系统环境，输入 YES 继续: " y; [[ "$y" == "YES" ]] && need "$RESCUE_DIR/openclaw-rescue-install.sh" && run "openclaw 救援安装" bash "$RESCUE_DIR/openclaw-rescue-install.sh" || echo "已取消"; press ;;
      0) return ;;
      *) echo "无效选择"; sleep 1 ;;
    esac
  done
}

menu_plugins_skills(){
  while true; do
    clear
    cat <<'EOF'
===== 插件/技能（中文） =====
1) 查看插件列表（Plugin：给OpenClaw加能力）
2) 开启插件（Plugin ON）
3) 关闭插件（Plugin OFF）
4) 查看技能清单（Skill：特定任务的说明模板）
5) 功能名中文对照（英文名->用途）
0) 返回上级
EOF
    read -r -p "选择: " c
    case "$c" in
      1) need "$OPS_DIR/plugin-manager.sh" && bash "$OPS_DIR/plugin-manager.sh" list; press ;;
      2) read -r -p "插件ID: " k; need "$OPS_DIR/plugin-manager.sh" && bash "$OPS_DIR/plugin-manager.sh" on "$k"; press ;;
      3) read -r -p "插件ID: " k; need "$OPS_DIR/plugin-manager.sh" && bash "$OPS_DIR/plugin-manager.sh" off "$k"; press ;;
      4) need "$OPS_DIR/skill-list.sh" && bash "$OPS_DIR/skill-list.sh"; press ;;
      5) cat "$OPS_DIR/README-FUNCTION-MAP-ZH.md"; press ;;
      0) return ;;
      *) echo "无效选择"; sleep 1 ;;
    esac
  done
}

while true; do
  clear
  cat <<'EOF'
=========================================
 OpenClaw 一体化工具包（中文总控）
=========================================
1) OpenClaw 运行/救援（主程序状态、启动、修复）
2) 统一备份/恢复（本地+云端+灾难）
3) 插件/技能管理（开关与说明）
4) 守护/定时任务（自动巡检与自动恢复）
5) Antfarm 冷配置（平时不运行，需用时再启动，省资源）
6) VPS->我的电脑向导（仅电脑连接/上传）
7) XBot（X/Twitter 自动化机器人状态）
8) 文档中心（每项功能是干嘛的）
9) 全功能向导模式（电脑+云备份）
10) 健康状态总览（服务+告警+守护）
11) 升级安全模式/一键恢复（OOM兜底）
12) 新机器一键初始化（迁移后即用）
13) 工具包自检（查缺失/失败原因）
14) 离线恢复专用（OpenClaw命令丢失/服务起不来）
0) 退出
EOF
  read -r -p "请选择: " m
  case "$m" in
    1) menu_openclaw ;;
    2) menu_backup_all ;;
    3) menu_plugins_skills ;;
    4) bash "$OPS_DIR/install-cron.sh"; press ;;
    5) bash "$OPS_DIR/antfarm-cold-status.sh"; press ;;
    6) bash "$OPS_DIR/task-wizard.sh" pc ;;
    7) bash "$OPS_DIR/xbot-status.sh"; press ;;
    8) clear; ls -1 "$OPS_DIR"/README-*.md 2>/dev/null || true; echo; read -r -p "输入文档文件名(如 README-OPS-ZH.md): " f; [[ -f "$OPS_DIR/$f" ]] && cat "$OPS_DIR/$f" || echo "未找到"; press ;;
    9) bash "$OPS_DIR/task-wizard.sh" ;;
    10) bash "$OPS_DIR/health-summary.sh"; press ;;
    11)
      while true; do
        clear
        cat <<'EOF'
===== 升级安全模式 / 一键恢复 =====
1) 安全升级（低内存 + 自动回滚）
2) 一键恢复（升级失败/OOM后）
3) Tarball升级（低内存首选，不走npm install）
4) 查看升级恢复说明文档（含2G机器固定SOP）
0) 返回上级
EOF
        read -r -p "选择: " u
        case "$u" in
          1) bash "$OPS_DIR/update-safe.sh"; press ;;
          2) bash "$OPS_DIR/update-recover.sh"; press ;;
          3) read -r -p "输入目标版本(默认 latest): " v; v=${v:-latest}; bash "$OPS_DIR/update-by-tarball.sh" "$v"; press ;;
          4) cat "$OPS_DIR/README-UPDATE-RECOVER-ZH.md"; press ;;
          0) break ;;
          *) echo "无效选择"; sleep 1 ;;
        esac
      done
      ;;
    12)
      echo "即将执行：新机器一键初始化（会安装依赖、创建模板、安装守护）"
      read -r -p "确认执行？输入 YES: " y
      if [[ "$y" == "YES" ]]; then
        bash "$OPS_DIR/bootstrap-toolkit.sh"
      else
        echo "已取消"
      fi
      press ;;
    13) bash "$OPS_DIR/toolkit-selfcheck.sh"; press ;;
    14)
      while true; do
        clear
        cat <<'EOF'
===== 离线恢复专用 =====
1) 一键离线恢复（用最新灾难包）
2) 指定灾难包恢复
3) 仅修复 openclaw 命令入口
4) 重启 gateway 并验收
5) 部分恢复（配置/记忆/脚本）
6) 按日期编号选择完整恢复包
0) 返回上级
EOF
        read -r -p "选择: " r
        case "$r" in
          1) bash "$OPS_DIR/offline-recover.sh"; press ;;
          2) read -r -p "输入备份包路径(.tgz): " p; bash "$OPS_DIR/offline-recover.sh" "$p"; press ;;
          3)
            if [[ -f /usr/lib/node_modules/openclaw/dist/index.js ]]; then
              cat > /usr/bin/openclaw <<'EOF'
#!/usr/bin/env bash
exec node /usr/lib/node_modules/openclaw/dist/index.js "$@"
EOF
              chmod +x /usr/bin/openclaw
              echo "[ok] 已修复 /usr/bin/openclaw"
            else
              echo "[x] 缺少 /usr/lib/node_modules/openclaw/dist/index.js"
            fi
            press ;;
          4) systemctl --user restart openclaw-gateway.service || true; sleep 2; systemctl --user is-active openclaw-gateway.service || true; openclaw --version 2>/dev/null || true; openclaw gateway status 2>/dev/null || true; press ;;
          5)
            echo "可选 part: config | memory | ops | skills | rescue | small-all"
            read -r -p "输入备份包路径(回车=最新): " p
            if [[ -z "$p" ]]; then p="$(ls -1t /root/backups/openclaw-disaster-*.tgz 2>/dev/null | head -n1)"; fi
            read -r -p "输入 part: " part
            bash "$OPS_DIR/config-restore.sh" "$p" "$part"
            press ;;
          6)
            mapfile -t arr < <(ls -1t /root/backups/openclaw-disaster-*.tgz 2>/dev/null)
            if [[ ${#arr[@]} -eq 0 ]]; then echo "[x] 没有可用备份包"; press; continue; fi
            i=1; for f in "${arr[@]}"; do echo "$i) $(basename "$f")"; i=$((i+1)); done
            read -r -p "选择编号: " idx
            if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx>=1 && idx<=${#arr[@]} )); then
              bash "$OPS_DIR/offline-recover.sh" "${arr[$((idx-1))]}"
            else
              echo "无效编号"
            fi
            press ;;
          0) break ;;
          *) echo "无效选择"; sleep 1 ;;
        esac
      done
      ;;
    0) echo "已退出"; exit 0 ;;
    *) echo "无效选择"; sleep 1 ;;
  esac
done
