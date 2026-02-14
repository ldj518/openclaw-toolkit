#!/usr/bin/env bash
set -euo pipefail

# 一键导出主题时间线报告
# 用法：
#   bash chat-timeline-report.sh <主题> [天数] [输出文件]
# 例：
#   bash chat-timeline-report.sh 升级 30

SESS_DIR="${SESS_DIR:-$HOME/.openclaw/agents/main/sessions}"
TOPIC="${1:-}"
DAYS="${2:-30}"
OUT="${3:-$HOME/.openclaw/workspace/openclaw-toolkit/exports/timeline-${TOPIC:-topic}-$(date +%F_%H%M%S).md}"

[[ -d "$SESS_DIR" ]] || { echo "[x] 会话目录不存在: $SESS_DIR" >&2; exit 1; }
[[ -n "$TOPIC" ]] || { echo "用法: bash chat-timeline-report.sh <主题> [天数] [输出文件]"; exit 1; }

case "$TOPIC" in
  升级|update) PATTERN='升级|回滚|OOM|update|recover|tarball' ;;
  备份|恢复|backup) PATTERN='备份|恢复|disaster|cloud-backup|offline-recover' ;;
  OAuth|模型|auth) PATTERN='OAuth|auth|openai-codex|模型|model' ;;
  Discord|路由) PATTERN='Discord|机器人|agent|路由|thread' ;;
  SSH|FRP|远程) PATTERN='SSH|FRP|60022|openclaw_win_ed25519|远程' ;;
  AI|资讯) PATTERN='AI|推特|X\.com|最新|LLM|大模型' ;;
  *) PATTERN="$TOPIC" ;;
esac

mkdir -p "$(dirname "$OUT")"

now_epoch="$(date +%s)"
since_epoch=$((now_epoch - DAYS*86400))

search_raw(){
  if command -v rg >/dev/null 2>&1; then
    rg -n --no-heading --glob '*.jsonl' "$PATTERN" "$SESS_DIR"
  else
    grep -RIn --include='*.jsonl' -E "$PATTERN" "$SESS_DIR" || true
  fi
}

{
  echo "# 主题时间线报告"
  echo "- 主题: $TOPIC"
  echo "- 关键词: $PATTERN"
  echo "- 时间窗口: 最近 ${DAYS} 天"
  echo "- 生成时间: $(date '+%F %T')"
  echo
  echo "## 关键时间线"

  search_raw | while IFS=: read -r f l rest; do
    ts="$(sed -n "${l}p" "$f" | jq -r '.timestamp // ""' 2>/dev/null || true)"
    [[ -n "$ts" ]] || continue
    ts_epoch="$(date -d "$ts" +%s 2>/dev/null || echo 0)"
    (( ts_epoch >= since_epoch )) || continue

    role="$(sed -n "${l}p" "$f" | jq -r '.message.role // ""' 2>/dev/null || true)"
    text="$(sed -n "${l}p" "$f" | jq -r '[.message.content[]? | select(.type=="text") | .text] | join(" ")' 2>/dev/null || true)"
    [[ -n "$text" && "$text" != "null" ]] || text="$rest"
    echo "- [$ts] [$role] $(basename "$f"):$l"
    echo "  - 摘要: ${text:0:220}"
  done

  echo
  echo "## 检索建议"
  echo "- 深挖某关键词: bash chat-knowledge.sh search \"$TOPIC\" 80"
  echo "- 最近${DAYS}天复查: bash chat-knowledge.sh search-days \"$TOPIC\" $DAYS 80"
  echo "- 标签总览: bash chat-knowledge.sh tags 120"
} > "$OUT"

echo "[ok] 报告已生成: $OUT"
