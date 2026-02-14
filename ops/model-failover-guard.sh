#!/usr/bin/env bash
set -euo pipefail

node /root/.openclaw/workspace/ops/model-failover-guard.js "$@" >> /root/.openclaw/model-guard-cron.log 2>&1
