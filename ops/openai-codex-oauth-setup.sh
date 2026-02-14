#!/usr/bin/env bash
set -euo pipefail

LOG="/tmp/openclaw-oauth-setup-$(date +%F_%H%M%S).log"

echo "========================================="
echo " OpenAI Codex OAuth 一键配置向导"
echo "========================================="
echo "1) 即将启动 OAuth 流程"
echo "2) 终端出现授权网址后，请在浏览器打开并登录"
echo "3) 完成后把回调URL/授权码粘贴回终端"
echo
read -r -p "确认开始？输入 YES: " y
[[ "$y" == "YES" ]] || { echo "已取消"; exit 0; }

echo "[i] 先确保 gateway 在运行"
systemctl --user restart openclaw-gateway.service || true
sleep 1

set +e
openclaw models auth login --provider openai-codex 2>&1 | tee "$LOG"
code=${PIPESTATUS[0]}
set -e

if [[ $code -ne 0 ]]; then
  echo "[!] 直接登录命令失败，尝试 onboard OAuth 向导..."
  set +e
  openclaw onboard --auth-choice openai-codex 2>&1 | tee -a "$LOG"
  code=${PIPESTATUS[0]}
  set -e
fi

if [[ $code -ne 0 ]]; then
  echo "[x] OAuth 配置失败。日志: $LOG"
  exit 1
fi

echo "[i] OAuth 看起来已完成，执行验收..."
openclaw --version || true
systemctl --user is-active openclaw-gateway.service || true
openclaw gateway status | sed -n '1,35p' || true

echo
echo "[ok] OAuth 配置流程执行完成。"
echo "日志: $LOG"
echo "如果需要切换主模型为 gpt-5.3-codex，可在会话里执行 /model openai-codex/gpt-5.3-codex"
