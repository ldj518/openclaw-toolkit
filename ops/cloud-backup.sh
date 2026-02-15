#!/usr/bin/env bash
set -euo pipefail

# 云端双备份：GitHub(非敏感 git 内容) + Cloudflare R2(加密包)
# 依赖：tar, sha256sum, openssl, aws(cli)
# 用法：
#   bash cloud-backup.sh            # 默认 small（配置/记忆/脚本/技能）
#   bash cloud-backup.sh full       # 全量（含 .secrets/.ssh）

ENV_FILE="${ENV_FILE:-/root/.secrets/cloud-backup.env}"
[[ -f "$ENV_FILE" ]] || { echo "[x] 缺少 $ENV_FILE" >&2; exit 1; }
# shellcheck source=/dev/null
source "$ENV_FILE"

: "${R2_BUCKET:?missing R2_BUCKET}"
: "${R2_ENDPOINT:?missing R2_ENDPOINT}"
: "${AWS_ACCESS_KEY_ID:?missing AWS_ACCESS_KEY_ID}"
: "${AWS_SECRET_ACCESS_KEY:?missing AWS_SECRET_ACCESS_KEY}"
: "${BACKUP_PASSPHRASE:?missing BACKUP_PASSPHRASE}"

bad(){
  local v="$1"
  [[ "$v" == *"<"* || "$v" == *">"* || "$v" == "xxx" || "$v" == *"你的"* || "$v" == *"你自己"* ]]
}

if bad "$R2_BUCKET" || bad "$R2_ENDPOINT" || bad "$AWS_ACCESS_KEY_ID" || bad "$AWS_SECRET_ACCESS_KEY" || bad "$BACKUP_PASSPHRASE"; then
  echo "[x] cloud-backup.env 仍是模板占位值，请先替换真实参数后再备份。" >&2
  echo "    例: R2_ENDPOINT=https://<你的accountid>.r2.cloudflarestorage.com（不要保留<>）" >&2
  exit 1
fi

command -v aws >/dev/null 2>&1 || { echo "[x] 缺少 aws CLI，请先安装: dnf -y install awscli" >&2; exit 1; }

WORKSPACE="${WORKSPACE:-/root/.openclaw/workspace}"
MODE="${1:-small}"
STAMP="$(date +%F_%H%M%S)"
HOST="$(hostname -s 2>/dev/null || echo host)"
NAME="openclaw-${MODE}-${HOST}-${STAMP}"
TMP_DIR="$(mktemp -d)"
ARCHIVE="${TMP_DIR}/${NAME}.tgz"
ENC="${TMP_DIR}/${NAME}.tgz.enc"
SHA="${TMP_DIR}/${NAME}.sha256"

cleanup(){ rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo "[1/5] 生成备份包（mode=${MODE}）"
if [[ "$MODE" == "full" ]]; then
  tar -czf "$ARCHIVE" /root/.openclaw /root/.secrets /root/.ssh 2>/dev/null || tar -czf "$ARCHIVE" /root/.openclaw /root/.ssh
else
  # small: 只备份“关键小文件”（配置/记忆/脚本/技能）
  INCLUDE=(
    /root/.openclaw/openclaw.json
    /root/.openclaw/workspace/MEMORY.md
    /root/.openclaw/workspace/memory
    /root/.openclaw/workspace/AGENTS.md
    /root/.openclaw/workspace/SOUL.md
    /root/.openclaw/workspace/USER.md
    /root/.openclaw/workspace/IDENTITY.md
    /root/.openclaw/workspace/TOOLS.md
    /root/.openclaw/workspace/ops
    /root/.openclaw/workspace/skills
    /root/.openclaw/workspace/rescue-kit
  )
  EXIST=()
  for p in "${INCLUDE[@]}"; do [[ -e "$p" ]] && EXIST+=("$p"); done
  [[ ${#EXIST[@]} -gt 0 ]] || { echo "[x] small 模式无可备份内容" >&2; exit 1; }
  tar -czf "$ARCHIVE" "${EXIST[@]}"
fi


echo "[2/5] 加密备份包 (openssl aes-256-cbc)"
openssl enc -aes-256-cbc -pbkdf2 -salt -in "$ARCHIVE" -out "$ENC" -pass env:BACKUP_PASSPHRASE
sha256sum "$ENC" | awk '{print $1}' > "$SHA"


echo "[3/5] 上传到 Cloudflare R2"
aws s3 cp "$ENC" "s3://${R2_BUCKET}/openclaw/${NAME}.tgz.enc" --endpoint-url "$R2_ENDPOINT"
aws s3 cp "$SHA" "s3://${R2_BUCKET}/openclaw/${NAME}.sha256" --endpoint-url "$R2_ENDPOINT"


echo "[4/5] 推送 workspace 到 GitHub（非敏感）"
if [[ -d "$WORKSPACE/.git" ]]; then
  if git -C "$WORKSPACE" remote get-url backup-github >/dev/null 2>&1; then
    if [[ -n "$(git -C "$WORKSPACE" status --porcelain)" ]]; then
      git -C "$WORKSPACE" add -A
      git -C "$WORKSPACE" commit -m "cloud backup ${STAMP}" >/dev/null || true
    fi
    branch="$(git -C "$WORKSPACE" branch --show-current || true)"; branch="${branch:-master}"
    git -C "$WORKSPACE" push backup-github "$branch"
  else
    echo "[!] 未配置 backup-github remote，已跳过 GitHub 推送"
  fi
else
  echo "[!] workspace 不是 git 仓库，已跳过 GitHub 推送"
fi


echo "[5/5] 完成"
echo "R2 object: openclaw/${NAME}.tgz.enc"
echo "R2 hash  : openclaw/${NAME}.sha256"
