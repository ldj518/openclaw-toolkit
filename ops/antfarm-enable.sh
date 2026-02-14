#!/usr/bin/env bash
set -euo pipefail

# Enables antfarm runtime components when user explicitly asks.
# Usage:
#   ./ops/antfarm-enable.sh            # install bundled workflows
#   ./ops/antfarm-enable.sh feature-dev # install one workflow

WORKFLOW="${1:-all}"

echo "[antfarm-enable] $(date -Is) starting"
cd /root/.openclaw/workspace/antfarm

if ! command -v antfarm >/dev/null 2>&1; then
  echo "antfarm binary not found in PATH" >&2
  exit 1
fi

if [ "$WORKFLOW" = "all" ]; then
  antfarm install
else
  antfarm workflow install "$WORKFLOW"
fi

echo "[antfarm-enable] done"
antfarm workflow list || true
