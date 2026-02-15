#!/usr/bin/env bash
set -euo pipefail
ENV_FILE="${ENV_FILE:-/root/.secrets/cloud-backup.env}"
[[ -f "$ENV_FILE" ]] || { echo "[x] 缺少 $ENV_FILE" >&2; exit 1; }
# shellcheck source=/dev/null
source "$ENV_FILE"
: "${R2_BUCKET:?missing R2_BUCKET}"
: "${R2_ENDPOINT:?missing R2_ENDPOINT}"
: "${AWS_ACCESS_KEY_ID:?missing AWS_ACCESS_KEY_ID}"
: "${AWS_SECRET_ACCESS_KEY:?missing AWS_SECRET_ACCESS_KEY}"

bad(){
  local v="$1"
  [[ "$v" == *"<"* || "$v" == *">"* || "$v" == "xxx" || "$v" == *"你的"* || "$v" == *"你自己"* ]]
}

if bad "$R2_BUCKET" || bad "$R2_ENDPOINT" || bad "$AWS_ACCESS_KEY_ID" || bad "$AWS_SECRET_ACCESS_KEY"; then
  echo "[x] cloud-backup.env 仍是模板占位值，请先替换真实 R2 参数。" >&2
  echo "    例: R2_ENDPOINT=https://<你的accountid>.r2.cloudflarestorage.com（不要保留<>）" >&2
  exit 1
fi

command -v aws >/dev/null 2>&1 || { echo "[x] 缺少 aws CLI，请先安装: dnf -y install awscli" >&2; exit 1; }

aws s3 ls "s3://${R2_BUCKET}/openclaw/" --endpoint-url "$R2_ENDPOINT"
