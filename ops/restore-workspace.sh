#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
REMOTE_NAME="${REMOTE_NAME:-backup-local}"
REF="${1:-}"

if [[ ! -d "$WORKSPACE/.git" ]]; then
  echo "[x] $WORKSPACE 不是 git 仓库" >&2
  exit 1
fi

if ! git -C "$WORKSPACE" remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
  echo "[x] remote $REMOTE_NAME 不存在，先执行 setup-backup.sh" >&2
  exit 1
fi

branch="$(git -C "$WORKSPACE" branch --show-current || true)"
branch="${branch:-master}"

if [[ -z "$REF" ]]; then
  REF="$REMOTE_NAME/$branch"
fi

echo "[!] 即将恢复 workspace 到: $REF"
echo "[!] 当前未提交改动会丢失（会执行 reset --hard + clean -fd）"
read -r -p "确认继续？输入 YES: " ok
if [[ "$ok" != "YES" ]]; then
  echo "[skip] 已取消"
  exit 0
fi

git -C "$WORKSPACE" fetch --all --tags --prune

# 支持 daily-YYYY-MM-DD 这类 tag
if git -C "$WORKSPACE" rev-parse -q --verify "refs/tags/$REF" >/dev/null 2>&1; then
  target="$REF"
else
  target="$REF"
fi

git -C "$WORKSPACE" reset --hard "$target"
git -C "$WORKSPACE" clean -fd

echo "[ok] 已恢复到 $target"
git -C "$WORKSPACE" --no-pager log -1 --oneline
