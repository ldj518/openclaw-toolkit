#!/usr/bin/env sh
# Source this in any shell/session before using gh/wrangler
# Usage: . /root/.openclaw/workspace/ops/shared-env.sh

[ -f /root/.secrets/openclaw.env ] && . /root/.secrets/openclaw.env

export OPENCLAW_GH_READY=1
# Requires in /root/.secrets/openclaw.env:
# export CLOUDFLARE_API_TOKEN=...
# export CLOUDFLARE_ACCOUNT_ID=...

# Wrangler reads CLOUDFLARE_API_TOKEN automatically.
