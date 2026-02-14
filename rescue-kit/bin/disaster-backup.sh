#!/usr/bin/env bash
set -euo pipefail

# 一键全量备份（不依赖 openclaw 命令）
# 用法：bash disaster-backup.sh [输出目录]

OUT_DIR="${1:-/root/backups}"
TS="$(date +%F_%H%M%S)"
HOST="$(hostname -s 2>/dev/null || echo host)"
BASE="openclaw-disaster-${HOST}-${TS}"
TMP_DIR="$(mktemp -d)"
mkdir -p "$OUT_DIR"

# 备份清单（尽量覆盖“重装后恢复我”所需）
PATHS=(
  "/root/.openclaw"
  "/root/.secrets"
  "/root/.ssh"
)

MANIFEST="$TMP_DIR/${BASE}.manifest.txt"
ARCHIVE="$OUT_DIR/${BASE}.tgz"
SHA_FILE="$OUT_DIR/${BASE}.tgz.sha256"

{
  echo "time: $(date -Is)"
  echo "host: $(hostname 2>/dev/null || true)"
  echo "kernel: $(uname -a 2>/dev/null || true)"
  echo "paths:"
  for p in "${PATHS[@]}"; do
    if [[ -e "$p" ]]; then
      echo "  - $p"
    else
      echo "  - $p (missing)"
    fi
  done
} > "$MANIFEST"

# 仅打包存在的路径
EXISTING=()
for p in "${PATHS[@]}"; do
  [[ -e "$p" ]] && EXISTING+=("$p")
done

if [[ ${#EXISTING[@]} -eq 0 ]]; then
  echo "[x] 没有可备份路径，退出" >&2
  exit 1
fi

tar -czf "$ARCHIVE" "${EXISTING[@]}" -C "$TMP_DIR" "$(basename "$MANIFEST")"
sha256sum "$ARCHIVE" | awk '{print $1}' > "$SHA_FILE"

cp -f "$MANIFEST" "$OUT_DIR/${BASE}.manifest.txt"

echo "[ok] 备份完成"
echo "archive: $ARCHIVE"
echo "sha256 : $(cat "$SHA_FILE")"
echo "manifest: $OUT_DIR/${BASE}.manifest.txt"
