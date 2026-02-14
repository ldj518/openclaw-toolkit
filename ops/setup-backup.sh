#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
BARE_REPO="${BARE_REPO:-$HOME/.openclaw/workspace-backup.git}"
REMOTE_NAME="${REMOTE_NAME:-backup-local}"

if [[ ! -d "$WORKSPACE/.git" ]]; then
  echo "[x] $WORKSPACE 不是 git 仓库，先在 workspace 初始化 git。" >&2
  exit 1
fi

mkdir -p "$(dirname "$BARE_REPO")"
if [[ ! -d "$BARE_REPO" ]]; then
  git init --bare "$BARE_REPO"
  echo "[ok] 已创建 bare 仓库: $BARE_REPO"
else
  echo "[ok] bare 仓库已存在: $BARE_REPO"
fi

if git -C "$WORKSPACE" remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
  git -C "$WORKSPACE" remote set-url "$REMOTE_NAME" "$BARE_REPO"
else
  git -C "$WORKSPACE" remote add "$REMOTE_NAME" "$BARE_REPO"
fi

echo "[ok] remote $REMOTE_NAME -> $BARE_REPO"

branch="$(git -C "$WORKSPACE" branch --show-current || true)"
branch="${branch:-master}"

git -C "$WORKSPACE" remote show "$REMOTE_NAME" >/dev/null 2>&1 || true

echo "[ok] 当前分支: $branch"
echo "[tip] 下一步可执行: $WORKSPACE/ops/backup-workspace.sh"
