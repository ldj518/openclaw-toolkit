#!/usr/bin/env bash
set -euo pipefail
source /root/.secrets/bird-x.env
exec bird "$@"
