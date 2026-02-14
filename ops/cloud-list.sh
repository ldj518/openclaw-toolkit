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

aws s3 ls "s3://${R2_BUCKET}/openclaw/" --endpoint-url "$R2_ENDPOINT"
