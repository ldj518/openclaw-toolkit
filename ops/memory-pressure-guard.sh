#!/usr/bin/env bash
set -euo pipefail
node /root/.openclaw/workspace/ops/memory-pressure-guard.js >> /root/.openclaw/memory-guard-cron.log 2>&1
