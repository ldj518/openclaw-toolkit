#!/usr/bin/env bash
set -euo pipefail

# 一键恢复（不依赖 openclaw 命令）
# 用法：bash disaster-restore.sh <backup.tgz> [--force]

ARCHIVE="${1:-}"
FORCE="${2:-}"

if [[ -z "$ARCHIVE" || ! -f "$ARCHIVE" ]]; then
  echo "Usage: bash disaster-restore.sh <backup.tgz> [--force]" >&2
  exit 1
fi

SHA_FILE="${ARCHIVE}.sha256"
if [[ -f "$SHA_FILE" ]]; then
  EXPECTED="$(cat "$SHA_FILE" | tr -d '[:space:]')"
  ACTUAL="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
  if [[ "$EXPECTED" != "$ACTUAL" ]]; then
    echo "[x] 校验失败: sha256 不匹配" >&2
    echo "expected: $EXPECTED" >&2
    echo "actual  : $ACTUAL" >&2
    exit 1
  fi
  echo "[ok] sha256 校验通过"
else
  echo "[!] 未找到 .sha256 文件，跳过完整性校验"
fi

if [[ "$FORCE" != "--force" ]]; then
  echo "[!] 即将恢复到 /root，覆盖同名文件"
  read -r -p "确认继续？输入 YES: " ok
  [[ "$ok" == "YES" ]] || { echo "[skip] 已取消"; exit 0; }
fi

# 停掉可能占用文件的进程（尽量，不强依赖）
pkill -f openclaw-gateway >/dev/null 2>&1 || true
pkill -x openclaw >/dev/null 2>&1 || true
sleep 1

tar -xzf "$ARCHIVE" -C /

# 修权限
[[ -d /root/.ssh ]] && chmod 700 /root/.ssh || true
find /root/.ssh -type f -exec chmod 600 {} \; 2>/dev/null || true
chown -R root:root /root/.openclaw /root/.ssh /root/.secrets 2>/dev/null || true

echo "[ok] 恢复完成"
echo "[tip] 下一步执行："
echo "  1) node -v && npm -v"
echo "  2) openclaw --version"
echo "  3) openclaw gateway install && openclaw gateway start"
echo "  4) openclaw gateway status"
