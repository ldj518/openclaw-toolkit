#!/usr/bin/env bash
set -euo pipefail

PROFILE_DIR="${XBOT_PROFILE_DIR:-/root/.xbot-profile}"
SESSION="${XBOT_SESSION:-xbot}"

# graceful close session first
agent-browser close --session "$SESSION" >/dev/null 2>&1 || true

if [ -f "$PROFILE_DIR/xbot.pid" ]; then
  PID=$(cat "$PROFILE_DIR/xbot.pid" || true)
  if [ -n "${PID:-}" ] && kill -0 "$PID" >/dev/null 2>&1; then
    kill "$PID" || true
  fi
  rm -f "$PROFILE_DIR/xbot.pid"
fi

# fallback cleanup
pkill -f "agent-browser.*--session ${SESSION}" >/dev/null 2>&1 || true

echo "stopped: session=$SESSION"
