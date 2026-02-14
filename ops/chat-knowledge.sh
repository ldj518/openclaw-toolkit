#!/usr/bin/env bash
set -euo pipefail

# 聊天记录检索与归档（基于 OpenClaw session JSONL）
# 用法：
#   bash chat-knowledge.sh search <关键词> [条数]
#   bash chat-knowledge.sh recent [条数]
#   bash chat-knowledge.sh index [输出文件]

SESS_DIR="${SESS_DIR:-$HOME/.openclaw/agents/main/sessions}"

if [[ ! -d "$SESS_DIR" ]]; then
  echo "[x] 会话目录不存在: $SESS_DIR" >&2
  exit 1
fi

cmd="${1:-}"

search(){
  local kw="${1:-}"
  local limit="${2:-40}"
  [[ -n "$kw" ]] || { echo "用法: bash chat-knowledge.sh search <关键词> [条数]"; exit 1; }

  echo "=== 搜索关键词: $kw (limit=$limit) ==="
  rg -n --no-heading --glob '*.jsonl' "$kw" "$SESS_DIR" \
    | tail -n "$limit" \
    | while IFS=: read -r file line rest; do
        local ts role text
        ts="$(sed -n "${line}p" "$file" | jq -r '.timestamp // ""' 2>/dev/null || true)"
        role="$(sed -n "${line}p" "$file" | jq -r '.message.role // ""' 2>/dev/null || true)"
        text="$(sed -n "${line}p" "$file" | jq -r '[.message.content[]? | select(.type=="text") | .text] | join(" ")' 2>/dev/null || true)"
        [[ -n "$text" && "$text" != "null" ]] || text="$rest"
        echo "- [$ts] [$role] $(basename "$file"):$line"
        echo "  $text"
      done
}

recent(){
  local limit="${1:-30}"
  echo "=== 最近用户消息 (limit=$limit) ==="
  find "$SESS_DIR" -type f -name '*.jsonl' -print0 \
    | xargs -0 jq -r 'select(.type=="message" and .message.role=="user") | [.timestamp, ([.message.content[]? | select(.type=="text") | .text] | join(" "))] | @tsv' 2>/dev/null \
    | tail -n "$limit" \
    | sed $'s/\t/ | /'
}

index_build(){
  local out="${1:-$HOME/.openclaw/workspace/openclaw-toolkit/exports/chat-index-$(date +%F_%H%M%S).md}"
  mkdir -p "$(dirname "$out")"

  cat > "$out" <<EOF
# 聊天知识索引
生成时间: $(date '+%F %T')
会话目录: $SESS_DIR

> 说明：这是关键词索引，点击文件+行号可回溯原记录。

EOF

  add_section(){
    local title="$1"; shift
    local pattern="$1"
    {
      echo "## $title"
      rg -n --glob '*.jsonl' -e "$pattern" "$SESS_DIR" | tail -n 40 | while IFS=: read -r f l r; do
        local ts role
        ts="$(sed -n "${l}p" "$f" | jq -r '.timestamp // ""' 2>/dev/null || true)"
        role="$(sed -n "${l}p" "$f" | jq -r '.message.role // ""' 2>/dev/null || true)"
        echo "- [$ts][$role] $(basename "$f"):$l"
      done
      echo
    } >> "$out"
  }

  add_section "升级/回滚" "升级|回滚|OOM|update|recover|tarball"
  add_section "备份/恢复" "备份|恢复|disaster|cloud-backup|offline-recover"
  add_section "OAuth/模型" "OAuth|auth|openai-codex|模型|model"
  add_section "Discord/机器人路由" "Discord|机器人|agent|路由|thread"
  add_section "SSH/FRP/远程" "SSH|FRP|60022|openclaw_win_ed25519"

  echo "[ok] 已生成索引: $out"
}

case "$cmd" in
  search) shift; search "$@" ;;
  recent) shift; recent "$@" ;;
  index) shift; index_build "$@" ;;
  *)
    echo "用法:"
    echo "  bash chat-knowledge.sh search <关键词> [条数]"
    echo "  bash chat-knowledge.sh recent [条数]"
    echo "  bash chat-knowledge.sh index [输出文件]"
    exit 1 ;;
esac
