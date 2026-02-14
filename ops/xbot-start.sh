#!/usr/bin/env bash
set -euo pipefail

PROFILE_DIR="${XBOT_PROFILE_DIR:-/root/.xbot-profile}"
LOG_DIR="${XBOT_LOG_DIR:-/root/.openclaw/workspace/logs}"
SESSION="${XBOT_SESSION:-xbot}"
PROXY="${XBOT_PROXY:-}"

mkdir -p "$PROFILE_DIR" "$LOG_DIR"

# single-session guard
if pgrep -af "agent-browser.*--session ${SESSION}" >/dev/null 2>&1; then
  echo "xbot already running (session=${SESSION})"
  exit 0
fi

HEADED="${XBOT_HEADED:-0}"
CMD=(agent-browser open https://x.com --session "$SESSION" --profile "$PROFILE_DIR")
if [ "$HEADED" = "1" ]; then
  CMD+=(--headed)
fi
if [ -n "$PROXY" ]; then
  CMD+=(--proxy "$PROXY")
fi

nohup "${CMD[@]}" >"$LOG_DIR/xbot-start.log" 2>&1 &
echo $! > "$PROFILE_DIR/xbot.pid"

echo "started: pid=$(cat "$PROFILE_DIR/xbot.pid") session=$SESSION"
echo "log: $LOG_DIR/xbot-start.log"
