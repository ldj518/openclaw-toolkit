#!/usr/bin/env bash
set -euo pipefail

# 用法：
#   bash config-restore.sh <backup.tgz> <part>
# part: config|memory|ops|skills|rescue|small-all

PKG="${1:-}"
PART="${2:-}"

if [[ -z "$PKG" || ! -f "$PKG" ]]; then
  echo "Usage: bash config-restore.sh <backup.tgz> <config|memory|ops|skills|rescue|small-all>" >&2
  exit 1
fi

if [[ -z "$PART" ]]; then
  echo "[x] 缺少 part 参数" >&2
  exit 1
fi

echo "将从 $PKG 恢复部分内容: $PART"
read -r -p "确认继续？输入 YES: " ok
[[ "$ok" == "YES" ]] || { echo "已取消"; exit 0; }

case "$PART" in
  config)
    tar -xzf "$PKG" -C / root/.openclaw/openclaw.json ;;
  memory)
    tar -xzf "$PKG" -C / root/.openclaw/workspace/MEMORY.md root/.openclaw/workspace/memory ;;
  ops)
    tar -xzf "$PKG" -C / root/.openclaw/workspace/ops ;;
  skills)
    tar -xzf "$PKG" -C / root/.openclaw/workspace/skills ;;
  rescue)
    tar -xzf "$PKG" -C / root/.openclaw/workspace/rescue-kit ;;
  small-all)
    tar -xzf "$PKG" -C / \
      root/.openclaw/openclaw.json \
      root/.openclaw/workspace/MEMORY.md \
      root/.openclaw/workspace/memory \
      root/.openclaw/workspace/ops \
      root/.openclaw/workspace/skills \
      root/.openclaw/workspace/rescue-kit \
      root/.openclaw/workspace/AGENTS.md \
      root/.openclaw/workspace/SOUL.md \
      root/.openclaw/workspace/USER.md \
      root/.openclaw/workspace/IDENTITY.md \
      root/.openclaw/workspace/TOOLS.md ;;
  *)
    echo "[x] 不支持 part=$PART" >&2
    exit 1 ;;
esac

echo "[ok] 部分恢复完成: $PART"
