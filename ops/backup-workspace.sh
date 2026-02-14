#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
REMOTE_NAME="${REMOTE_NAME:-backup-local}"
LOCK_FILE="${LOCK_FILE:-$HOME/.openclaw/workspace/.backup.lock}"
TAG_KEEP_DAYS="${TAG_KEEP_DAYS:-30}"

mkdir -p "$(dirname "$LOCK_FILE")"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "[skip] backup 正在运行"
  exit 0
fi

if [[ ! -d "$WORKSPACE/.git" ]]; then
  echo "[x] $WORKSPACE 不是 git 仓库" >&2
  exit 1
fi

if ! git -C "$WORKSPACE" remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
  echo "[x] remote $REMOTE_NAME 不存在，先跑 setup-backup.sh" >&2
  exit 1
fi

branch="$(git -C "$WORKSPACE" branch --show-current || true)"
branch="${branch:-master}"

# 自动提交（无变更就跳过）
if [[ -n "$(git -C "$WORKSPACE" status --porcelain)" ]]; then
  # 避免 cron/root 环境缺少 git 身份导致提交失败
  git -C "$WORKSPACE" config user.name >/dev/null 2>&1 || git -C "$WORKSPACE" config user.name "openclaw-auto-backup"
  git -C "$WORKSPACE" config user.email >/dev/null 2>&1 || git -C "$WORKSPACE" config user.email "openclaw@localhost"

  git -C "$WORKSPACE" add -A
  git -C "$WORKSPACE" commit -m "auto backup $(date '+%F %T %z')" >/dev/null
  echo "[ok] 已提交本地变更"
else
  echo "[ok] 无变更，跳过 commit"
fi

# 推送到本地 bare 仓库
git -C "$WORKSPACE" push "$REMOTE_NAME" "$branch" >/dev/null

echo "[ok] 已推送到 $REMOTE_NAME/$branch"

# 每日标签（幂等）
today_tag="daily-$(date +%F)"
if ! git -C "$WORKSPACE" rev-parse -q --verify "refs/tags/$today_tag" >/dev/null 2>&1; then
  git -C "$WORKSPACE" tag "$today_tag"
  git -C "$WORKSPACE" push "$REMOTE_NAME" "$today_tag" >/dev/null
  echo "[ok] 已打标签 $today_tag"
fi

# 清理旧标签（超过 TAG_KEEP_DAYS）
cutoff_epoch="$(date -d "-$TAG_KEEP_DAYS days" +%s)"
while IFS= read -r tag; do
  [[ -z "$tag" ]] && continue
  d="${tag#daily-}"
  if date -d "$d" +%s >/dev/null 2>&1; then
    t_epoch="$(date -d "$d" +%s)"
    if (( t_epoch < cutoff_epoch )); then
      git -C "$WORKSPACE" tag -d "$tag" >/dev/null 2>&1 || true
      git -C "$WORKSPACE" push "$REMOTE_NAME" ":refs/tags/$tag" >/dev/null 2>&1 || true
      echo "[ok] 已删除旧标签 $tag"
    fi
  fi
done < <(git -C "$WORKSPACE" tag -l 'daily-*')
