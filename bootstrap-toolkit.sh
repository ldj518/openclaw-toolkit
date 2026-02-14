#!/usr/bin/env bash
set -euo pipefail

# GitHub 一键安装入口
# 用法1（推荐，远程）：bash -c "$(curl -fsSL https://raw.githubusercontent.com/<user>/<repo>/main/bootstrap-toolkit.sh)" -- <user>/<repo> [ref]
# 用法2（本地仓库目录）：bash bootstrap-toolkit.sh

REPO_SLUG="${1:-}"   # 例如: yourname/openclaw-toolkit
REF="${2:-main}"
TARGET_ROOT="/root/.openclaw/workspace"
TARGET_TOOLKIT="$TARGET_ROOT/openclaw-toolkit"

if [[ -z "$REPO_SLUG" ]]; then
  # 本地模式：脚本旁边已有 ops/
  BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
  if [[ -x "$BASE_DIR/ops/bootstrap-toolkit.sh" ]]; then
    exec bash "$BASE_DIR/ops/bootstrap-toolkit.sh"
  fi
  echo "[x] 未提供 GitHub 仓库参数，且本地目录不完整。"
  echo "    远程用法：bash bootstrap-toolkit.sh <user>/<repo> [ref]"
  exit 1
fi

ARCHIVE_URL="https://codeload.github.com/${REPO_SLUG}/tar.gz/${REF}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "[1/4] 下载工具包: $ARCHIVE_URL"
curl -fsSL "$ARCHIVE_URL" -o "$TMP_DIR/toolkit.tgz"

echo "[2/4] 解压"
mkdir -p "$TMP_DIR/src"
tar -xzf "$TMP_DIR/toolkit.tgz" -C "$TMP_DIR/src"
TOP_DIR="$(find "$TMP_DIR/src" -mindepth 1 -maxdepth 1 -type d | head -n1)"

if [[ ! -x "$TOP_DIR/ops/bootstrap-toolkit.sh" ]]; then
  echo "[x] 仓库缺少 ops/bootstrap-toolkit.sh，无法继续"
  exit 1
fi

echo "[3/4] 安装到 $TARGET_TOOLKIT"
mkdir -p "$TARGET_ROOT"
rm -rf "$TARGET_TOOLKIT"
mkdir -p "$TARGET_TOOLKIT"
cp -a "$TOP_DIR/ops" "$TARGET_TOOLKIT/"
cp -a "$TOP_DIR/rescue-kit" "$TARGET_TOOLKIT/" 2>/dev/null || true
cp -a "$TOP_DIR"/README*.md "$TARGET_TOOLKIT/" 2>/dev/null || true

echo "[4/4] 执行初始化"
bash "$TARGET_TOOLKIT/ops/bootstrap-toolkit.sh"

echo "[ok] 完成。菜单入口：bash $TARGET_TOOLKIT/ops/onekit-menu-zh.sh"
