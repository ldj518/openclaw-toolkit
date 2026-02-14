#!/usr/bin/env bash
set -euo pipefail

# Auto switch based on recent plugin failures in log
STATE_DIR="/root/.openclaw/workspace/ops/.state"
AUTO_FILE="$STATE_DIR/memos-auto.state"
mkdir -p "$STATE_DIR"

LOG_FILE="/tmp/openclaw/openclaw-$(date +%F).log"
WINDOW_LINES=500
HEALTHY_TO_REENABLE=3

if [[ ! -f "$AUTO_FILE" ]]; then
  cat > "$AUTO_FILE" <<EOF
DISABLED_BY=none
HEALTHY_STREAK=0
EOF
fi

# shellcheck source=/dev/null
source "$AUTO_FILE"

recent=""
[[ -f "$LOG_FILE" ]] && recent="$(tail -n $WINDOW_LINES "$LOG_FILE" 2>/dev/null || true)"

has_bad=0
if echo "$recent" | grep -Eqi 'memos-cloud.*(Missing MEMOS_API_KEY|401|403|429|quota|rate limit|insufficient|token|auth|timeout|ECONN|ENOTFOUND)'; then
  has_bad=1
fi

# Check current status
status=$(/root/.openclaw/workspace/ops/memosctl.sh status | head -n1 | awk '{print $4}')

if [[ "$has_bad" -eq 1 ]]; then
  HEALTHY_STREAK=0
  if [[ "$status" == "on" ]]; then
    /root/.openclaw/workspace/ops/memosctl.sh off auto_error >/dev/null 2>&1 || true
    DISABLED_BY=auto
  fi
else
  HEALTHY_STREAK=$((HEALTHY_STREAK+1))
  if [[ "$status" == "off" && "$DISABLED_BY" == "auto" && "$HEALTHY_STREAK" -ge "$HEALTHY_TO_REENABLE" ]]; then
    /root/.openclaw/workspace/ops/memosctl.sh on auto_recover >/dev/null 2>&1 || true
    DISABLED_BY=none
    HEALTHY_STREAK=0
  fi
fi

cat > "$AUTO_FILE" <<EOF
DISABLED_BY=$DISABLED_BY
HEALTHY_STREAK=$HEALTHY_STREAK
EOF
