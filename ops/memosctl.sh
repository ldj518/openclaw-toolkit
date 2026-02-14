#!/usr/bin/env bash
set -euo pipefail

CONFIG="/root/.openclaw/openclaw.json"
STATE_DIR="/root/.openclaw/workspace/ops/.state"
STATE_FILE="$STATE_DIR/memos-switch.state"
mkdir -p "$STATE_DIR"

usage() {
  cat <<'EOF'
Usage: memosctl.sh <on|off|status> [reason]

on      Enable memos-cloud-openclaw-plugin and restart gateway
off     Disable memos-cloud-openclaw-plugin and restart gateway
status  Show current plugin enabled status
EOF
}

get_status() {
  python - <<'PY'
import json
p='/root/.openclaw/openclaw.json'
obj=json.load(open(p))
enabled=obj.get('plugins',{}).get('entries',{}).get('memos-cloud-openclaw-plugin',{}).get('enabled',False)
print('on' if enabled else 'off')
PY
}

set_status() {
  local target="$1"
  python - <<PY
import json
p='/root/.openclaw/openclaw.json'
obj=json.load(open(p))
plugins=obj.setdefault('plugins',{})
entries=plugins.setdefault('entries',{})
entry=entries.setdefault('memos-cloud-openclaw-plugin',{})
entry['enabled'] = True if '${target}'=='on' else False
with open(p,'w') as f:
    json.dump(obj,f,ensure_ascii=False,indent=2)
print('updated to ${target}')
PY
}

restart_gateway() {
  pkill -x openclaw-gateway >/dev/null 2>&1 || true
  pkill -x openclaw >/dev/null 2>&1 || true
  sleep 2
  nohup bash -lc '[[ -f /root/.secrets/openclaw.env ]] && source /root/.secrets/openclaw.env; openclaw' \
    >/tmp/openclaw/restart-memosctl-$(date +%Y%m%d_%H%M%S).log 2>&1 &
  sleep 4
}

cmd="${1:-}"
reason="${2:-manual}"

case "$cmd" in
  on|off)
    current="$(get_status)"
    if [[ "$current" == "$cmd" ]]; then
      echo "already $cmd"
      exit 0
    fi
    set_status "$cmd"
    restart_gateway
    echo "$(date '+%F %T') $cmd reason=$reason" > "$STATE_FILE"
    echo "memos plugin => $cmd"
    ;;
  status)
    echo "memos plugin => $(get_status)"
    [[ -f "$STATE_FILE" ]] && { echo "last switch:"; cat "$STATE_FILE"; }
    ;;
  *)
    usage
    exit 1
    ;;
esac
