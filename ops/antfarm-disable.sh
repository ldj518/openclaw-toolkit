#!/usr/bin/env bash
set -euo pipefail

# Disables antfarm runtime components.
# This removes installed workflows/agents/crons/db provisioned by antfarm.

echo "[antfarm-disable] $(date -Is) stopping"

if ! command -v antfarm >/dev/null 2>&1; then
  echo "antfarm not found; nothing to disable"
  exit 0
fi

antfarm dashboard stop || true
antfarm uninstall --force || true

echo "[antfarm-disable] done"
