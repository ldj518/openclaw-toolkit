#!/usr/bin/env bash
set -euo pipefail

# 聊天记录检索与归档（Stage 2）
# 用法：
#   bash chat-knowledge.sh search <关键词> [条数]
#   bash chat-knowledge.sh recent [条数]
#   bash chat-knowledge.sh index [输出文件]
#   bash chat-knowledge.sh search-days <关键词> <天数> [条数]
#   bash chat-knowledge.sh tags [条数]
#   bash chat-knowledge.sh ask <问题>

SESS_DIR="${SESS_DIR:-$HOME/.openclaw/agents/main/sessions}"

[[ -d "$SESS_DIR" ]] || { echo "[x] 会话目录不存在: $SESS_DIR" >&2; exit 1; }

cmd="${1:-}"

search_raw(){
  local pattern="$1"
  if command -v rg >/dev/null 2>&1; then
    rg -n --no-heading --glob '*.jsonl' "$pattern" "$SESS_DIR"
  else
    grep -RIn --include='*.jsonl' -E "$pattern" "$SESS_DIR" || true
  fi
}

extract_text_line(){
  local file="$1" line="$2" fallback="$3"
  local ts role text
  ts="$(sed -n "${line}p" "$file" | jq -r '.timestamp // ""' 2>/dev/null || true)"
  role="$(sed -n "${line}p" "$file" | jq -r '.message.role // ""' 2>/dev/null || true)"
  text="$(sed -n "${line}p" "$file" | jq -r '[.message.content[]? | select(.type=="text") | .text] | join(" ")' 2>/dev/null || true)"
  [[ -n "$text" && "$text" != "null" ]] || text="$fallback"
  echo "- [$ts] [$role] $(basename "$file"):$line"
  echo "  $text"
}

search(){
  local kw="${1:-}"; local limit="${2:-40}"
  [[ -n "$kw" ]] || { echo "用法: bash chat-knowledge.sh search <关键词> [条数]"; exit 1; }
  echo "=== 搜索关键词: $kw (limit=$limit) ==="
  search_raw "$kw" | tail -n "$limit" |
  while IFS=: read -r file line rest; do extract_text_line "$file" "$line" "$rest"; done
}

recent(){
  local limit="${1:-30}"
  echo "=== 最近用户消息 (limit=$limit) ==="
  find "$SESS_DIR" -type f -name '*.jsonl' -print0 |
    xargs -0 jq -r 'select(.type=="message" and .message.role=="user") | [.timestamp, ([.message.content[]? | select(.type=="text") | .text] | join(" "))] | @tsv' 2>/dev/null |
    tail -n "$limit" | sed $'s/\t/ | /'
}

search_days(){
  local kw="${1:-}"; local days="${2:-}"; local limit="${3:-40}"
  [[ -n "$kw" && -n "$days" ]] || { echo "用法: bash chat-knowledge.sh search-days <关键词> <天数> [条数]"; exit 1; }
  local since_epoch now_epoch
  now_epoch="$(date +%s)"
  since_epoch=$((now_epoch - days*86400))
  echo "=== 最近 ${days} 天关键词搜索: $kw (limit=$limit) ==="

  search_raw "$kw" |
  while IFS=: read -r file line rest; do
    ts="$(sed -n "${line}p" "$file" | jq -r '.timestamp // ""' 2>/dev/null || true)"
    [[ -n "$ts" ]] || continue
    ts_epoch="$(date -d "$ts" +%s 2>/dev/null || echo 0)"
    if (( ts_epoch >= since_epoch )); then
      echo "$file:$line:$rest"
    fi
  done | tail -n "$limit" | while IFS=: read -r file line rest; do
    extract_text_line "$file" "$line" "$rest"
  done
}

index_build(){
  local out="${1:-$HOME/.openclaw/workspace/openclaw-toolkit/exports/chat-index-$(date +%F_%H%M%S).md}"
  mkdir -p "$(dirname "$out")"
  cat > "$out" <<EOF
# 聊天知识索引（Stage 2）
生成时间: $(date '+%F %T')
会话目录: $SESS_DIR

EOF

  add_section(){
    local title="$1"; local pattern="$2"
    {
      echo "## $title"
      search_raw "$pattern" | tail -n 60 | while IFS=: read -r f l _; do
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
  add_section "AI资讯/推特" "AI|推特|X\.com|最新"

  echo "[ok] 已生成索引: $out"
}

tags(){
  local limit="${1:-80}"
  echo "=== 自动标签视图 (limit=$limit) ==="
  search_raw '升级|回滚|OOM|备份|恢复|OAuth|Discord|SSH|FRP|60022|AI|推特|X\.com' | tail -n "$limit" |
  while IFS=: read -r f l r; do
    tag="other"
    if echo "$r" | grep -Eq '升级|回滚|OOM|update|recover|tarball'; then tag="升级"; fi
    if echo "$r" | grep -Eq '备份|恢复|disaster|cloud-backup|offline-recover'; then tag="备份恢复"; fi
    if echo "$r" | grep -Eq 'OAuth|auth|openai-codex|模型|model'; then tag="OAuth模型"; fi
    if echo "$r" | grep -Eq 'Discord|机器人|agent|路由|thread'; then tag="Discord路由"; fi
    if echo "$r" | grep -Eq 'SSH|FRP|60022|openclaw_win_ed25519'; then tag="SSH远程"; fi
    if echo "$r" | grep -Eq 'AI|推特|X\.com|最新'; then tag="AI资讯"; fi
    ts="$(sed -n "${l}p" "$f" | jq -r '.timestamp // ""' 2>/dev/null || true)"
    echo "[$tag] [$ts] $(basename "$f"):$l"
  done
}

ask(){
  local q="${1:-}"
  [[ -n "$q" ]] || { echo "用法: bash chat-knowledge.sh ask <问题>"; exit 1; }
  echo "=== 问题检索: $q ==="
  echo "[步骤1] 关键词命中"
  search "$q" 15
  echo
  echo "[步骤2] 相关主题建议"
  if echo "$q" | grep -Eqi '升级|回滚|oom'; then echo "- 建议查看: 升级/回滚索引"; fi
  if echo "$q" | grep -Eqi '备份|恢复|disaster'; then echo "- 建议查看: 备份/恢复索引"; fi
  if echo "$q" | grep -Eqi 'oauth|模型|auth'; then echo "- 建议查看: OAuth/模型索引"; fi
  if echo "$q" | grep -Eqi 'discord|机器人|路由|thread'; then echo "- 建议查看: Discord/机器人路由索引"; fi
  if echo "$q" | grep -Eqi 'ssh|frp|60022|远程'; then echo "- 建议查看: SSH/FRP/远程索引"; fi
}

case "$cmd" in
  search) shift; search "$@" ;;
  recent) shift; recent "$@" ;;
  index) shift; index_build "$@" ;;
  search-days) shift; search_days "$@" ;;
  tags) shift; tags "$@" ;;
  ask) shift; ask "$*" ;;
  *)
    cat <<EOF
用法:
  bash chat-knowledge.sh search <关键词> [条数]
  bash chat-knowledge.sh recent [条数]
  bash chat-knowledge.sh index [输出文件]
  bash chat-knowledge.sh search-days <关键词> <天数> [条数]
  bash chat-knowledge.sh tags [条数]
  bash chat-knowledge.sh ask <问题>
EOF
    exit 1 ;;
esac
