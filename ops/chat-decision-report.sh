#!/usr/bin/env bash
set -euo pipefail

# 决策版报告（第四阶段）
# 目标：过滤噪音，保留结论 + 动作 + 状态
# 用法：
#   bash chat-decision-report.sh [天数] [输出文件]

SESS_DIR="${SESS_DIR:-$HOME/.openclaw/agents/main/sessions}"
DAYS="${1:-30}"
OUT="${2:-$HOME/.openclaw/workspace/openclaw-toolkit/exports/decision-report-$(date +%F_%H%M%S).md}"

[[ -d "$SESS_DIR" ]] || { echo "[x] 会话目录不存在: $SESS_DIR" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"

now_epoch="$(date +%s)"
since_epoch=$((now_epoch - DAYS*86400))

search_raw(){
  local pattern="$1"
  if command -v rg >/dev/null 2>&1; then
    rg -n --no-heading --glob '*.jsonl' "$pattern" "$SESS_DIR"
  else
    grep -RIn --include='*.jsonl' -E "$pattern" "$SESS_DIR" || true
  fi
}

emit_section(){
  local title="$1" pattern="$2" max="${3:-25}"
  echo "## $title"
  search_raw "$pattern" | tail -n "$max" | while IFS=: read -r f l rest; do
    ts="$(sed -n "${l}p" "$f" | jq -r '.timestamp // ""' 2>/dev/null || true)"
    [[ -n "$ts" ]] || continue
    ts_epoch="$(date -d "$ts" +%s 2>/dev/null || echo 0)"
    (( ts_epoch >= since_epoch )) || continue

    role="$(sed -n "${l}p" "$f" | jq -r '.message.role // ""' 2>/dev/null || true)"
    text="$(sed -n "${l}p" "$f" | jq -r '[.message.content[]? | select(.type=="text") | .text] | join(" ")' 2>/dev/null || true)"
    [[ -n "$text" && "$text" != "null" ]] || text="$rest"
    # 去掉特别长噪音
    clean="$(echo "$text" | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-220)"
    echo "- [$ts][$role] ${clean}"
  done | awk '!seen[$0]++'
  echo
}

extract_actions(){
  echo "## 可执行动作清单（Action Items）"
  search_raw 'bash |openclaw |systemctl |crontab |ssh |scp ' | tail -n 120 | while IFS=: read -r f l rest; do
    ts="$(sed -n "${l}p" "$f" | jq -r '.timestamp // ""' 2>/dev/null || true)"
    [[ -n "$ts" ]] || continue
    ts_epoch="$(date -d "$ts" +%s 2>/dev/null || echo 0)"
    (( ts_epoch >= since_epoch )) || continue

    text="$(sed -n "${l}p" "$f" | jq -r '[.message.content[]? | select(.type=="text") | .text] | join(" ")' 2>/dev/null || true)"
    [[ -n "$text" && "$text" != "null" ]] || text="$rest"
    cmd="$(echo "$text" | grep -Eo 'bash [^` ]+|openclaw [^` ]+|systemctl --user [^` ]+|crontab [^` ]+|ssh [^` ]+|scp [^` ]+' | head -n1 || true)"
    [[ -n "$cmd" ]] || continue
    echo "- [ ] $cmd  （来源: $ts）"
  done | awk '!seen[$0]++'
  echo
}

extract_status(){
  echo "## 状态看板"
  echo "- ✅ 已完成：低内存升级闭环、离线恢复、聊天检索分阶段功能"
  echo "- 🟡 待完成：OAuth人工授权（需电脑在场）"
  echo "- ⚠️ 风险点：gateway 偶发 activating 抖动（已有降噪告警缓解）"
  echo
}

{
  echo "# 决策版结果页（自动生成）"
  echo "- 时间范围：最近 ${DAYS} 天"
  echo "- 生成时间：$(date '+%F %T')"
  echo "- 目标：过滤无效信息，只保留结论与动作"
  echo

  echo "## TL;DR"
  echo "- 对话噪音已过滤，核心聚焦在：升级稳定性、恢复能力、检索归档能力。"
  echo "- 当前可直接执行的关键路径：升级（11->4）、恢复（14）、检索（16）。"
  echo "- 如要对外汇报，优先发本报告 + 主题时间线报告。"
  echo

  emit_section "升级与回滚结论" '升级|回滚|OOM|update|recover|tarball' 30
  emit_section "备份与恢复结论" '备份|恢复|disaster|cloud-backup|offline-recover' 30
  emit_section "模型与OAuth结论" 'OAuth|auth|openai-codex|模型|model' 20
  emit_section "远程连接与协议结论" 'SSH|FRP|60022|openclaw_win_ed25519|远程' 20
  emit_section "AI资讯与检索结论" 'AI|推特|X\.com|最新|搜索' 20

  extract_actions
  extract_status

  echo "## 相关文件"
  echo "- 聊天检索: ops/chat-knowledge.sh"
  echo "- 主题时间线: ops/chat-timeline-report.sh"
  echo "- 本报告: $OUT"
} > "$OUT"

echo "[ok] 决策版报告已生成: $OUT"
