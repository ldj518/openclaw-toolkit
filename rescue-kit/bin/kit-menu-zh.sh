#!/usr/bin/env bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
ok(){ echo -e "\n✅ $1\n"; }
err(){ echo -e "\n❌ $1\n"; }
pause(){ read -r -p "回车继续..." _; }

while true; do
  clear
  cat <<'MENU'
==============================
 OpenClaw 离线救援工具包（中文）
 (不依赖 openclaw 命令)
==============================
1) 一键备份（全量）
2) 一键恢复（从备份包）
3) 一键验收（恢复后）
4) OpenClaw 诊断（专用）
5) OpenClaw 一键救援安装（低内存）
6) 系统信息诊断（内存/磁盘/node）
7) 打开说明文档
0) 退出
MENU
  read -r -p "请选择: " c
  case "$c" in
    1)
      read -r -p "备份输出目录(默认 /root/backups): " out
      out=${out:-/root/backups}
      if bash "$BASE_DIR/disaster-backup.sh" "$out"; then ok "备份完成"; else err "备份失败"; fi
      pause
      ;;
    2)
      read -r -p "输入备份包路径(.tgz): " pkg
      if [[ -z "$pkg" ]]; then err "路径不能为空"; pause; continue; fi
      if bash "$BASE_DIR/disaster-restore.sh" "$pkg"; then ok "恢复完成"; else err "恢复失败"; fi
      pause
      ;;
    3)
      if bash "$BASE_DIR/disaster-verify.sh"; then ok "验收执行完成"; else err "验收失败"; fi
      pause
      ;;
    4)
      if bash "$BASE_DIR/openclaw-diagnose.sh"; then ok "OpenClaw 诊断完成"; else err "OpenClaw 诊断失败"; fi
      pause
      ;;
    5)
      read -r -p "将执行救援安装（会改系统环境），确认继续？输入 YES: " ok
      if [[ "$ok" == "YES" ]]; then
        if bash "$BASE_DIR/openclaw-rescue-install.sh"; then ok "OpenClaw 救援安装完成"; else err "OpenClaw 救援安装失败"; fi
      else
        echo "已取消"
      fi
      pause
      ;;
    6)
      echo "time: $(date -Is)"
      echo "kernel: $(uname -a)"
      echo "node: $(node -v 2>/dev/null || echo missing)"
      echo "npm : $(npm -v 2>/dev/null || echo missing)"
      echo "---- free -h ----"; free -h || true
      echo "---- df -h / ----"; df -h / || true
      pause
      ;;
    7)
      cat "$BASE_DIR/../README-RESCUE-KIT-ZH.md"
      pause
      ;;
    0) echo "已退出"; exit 0 ;;
    *) echo "无效选择"; sleep 1 ;;
  esac
done
