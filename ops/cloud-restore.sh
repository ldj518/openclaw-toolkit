#!/usr/bin/env bash
set -euo pipefail

# 用法：bash cloud-restore.sh <name.tgz.enc>

OBJ="${1:-}"
[[ -n "$OBJ" ]] || { echo "Usage: bash cloud-restore.sh <name.tgz.enc>" >&2; exit 1; }

ENV_FILE="${ENV_FILE:-/root/.secrets/cloud-backup.env}"
[[ -f "$ENV_FILE" ]] || { echo "[x] 缺少 $ENV_FILE" >&2; exit 1; }
# shellcheck source=/dev/null
source "$ENV_FILE"
: "${R2_BUCKET:?missing R2_BUCKET}"
: "${R2_ENDPOINT:?missing R2_ENDPOINT}"
: "${AWS_ACCESS_KEY_ID:?missing AWS_ACCESS_KEY_ID}"
: "${AWS_SECRET_ACCESS_KEY:?missing AWS_SECRET_ACCESS_KEY}"
: "${BACKUP_PASSPHRASE:?missing BACKUP_PASSPHRASE}"

TMP_DIR="$(mktemp -d)"
ENC="$TMP_DIR/$OBJ"
SHA_REMOTE="${OBJ%.tgz.enc}.sha256"
SHA_LOCAL="$TMP_DIR/$SHA_REMOTE"
TGZ="$TMP_DIR/${OBJ%.enc}"
cleanup(){ rm -rf "$TMP_DIR"; }
trap cleanup EXIT


echo "[1/5] 下载备份与校验文件"
aws s3 cp "s3://${R2_BUCKET}/openclaw/$OBJ" "$ENC" --endpoint-url "$R2_ENDPOINT"
aws s3 cp "s3://${R2_BUCKET}/openclaw/$SHA_REMOTE" "$SHA_LOCAL" --endpoint-url "$R2_ENDPOINT"


echo "[2/5] 校验完整性"
EXPECTED="$(cat "$SHA_LOCAL" | tr -d '[:space:]')"
ACTUAL="$(sha256sum "$ENC" | awk '{print $1}')"
[[ "$EXPECTED" == "$ACTUAL" ]] || { echo "[x] sha256 校验失败" >&2; exit 1; }


echo "[3/5] 解密"
openssl enc -d -aes-256-cbc -pbkdf2 -in "$ENC" -out "$TGZ" -pass env:BACKUP_PASSPHRASE


echo "[4/5] 恢复（覆盖）"
read -r -p "确认覆盖恢复到 /root ? 输入 YES: " ok
[[ "$ok" == "YES" ]] || { echo "[skip] 已取消"; exit 0; }
pkill -f openclaw-gateway >/dev/null 2>&1 || true
pkill -x openclaw >/dev/null 2>&1 || true
tar -xzf "$TGZ" -C /
chmod 700 /root/.ssh 2>/dev/null || true
find /root/.ssh -type f -exec chmod 600 {} \; 2>/dev/null || true


echo "[5/5] 恢复完成，建议执行："
echo "openclaw --version && openclaw gateway install && openclaw gateway start && openclaw gateway status"
