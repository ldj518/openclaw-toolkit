#!/usr/bin/env bash
set -euo pipefail

echo "== antfarm cold status =="
echo "time: $(date -Is)"
echo "node: $(node -v)"
echo "npm : $(npm -v)"

if command -v antfarm >/dev/null 2>&1; then
  echo "antfarm: $(antfarm --version 2>/dev/null || echo 'installed (version unknown)')"
else
  echo "antfarm: NOT FOUND in PATH"
  exit 1
fi

if [ -d /root/.openclaw/workspace/antfarm ]; then
  echo "repo: /root/.openclaw/workspace/antfarm (present)"
else
  echo "repo: missing"
fi

echo "\n-- dashboard --"
antfarm dashboard status || true

echo "\n-- workflows (may be empty before first enable) --"
antfarm workflow list || true

echo "\n-- logs tail --"
antfarm logs 30 || true
