#!/usr/bin/env bash
set -euo pipefail
PROFILE_DIR="${XBOT_PROFILE_DIR:-/root/.xbot-profile}"
SESSION="${XBOT_SESSION:-xbot}"

echo "session: $SESSION"
if [ -f "$PROFILE_DIR/xbot.pid" ]; then
  PID=$(cat "$PROFILE_DIR/xbot.pid" || true)
  echo "pid_file: $PID"
  if [ -n "${PID:-}" ] && kill -0 "$PID" >/dev/null 2>&1; then
    echo "process: running"
  else
    echo "process: not running"
  fi
else
  echo "pid_file: none"
fi

ps -ef | grep -E "agent-browser.*--session ${SESSION}" | grep -v grep || true
