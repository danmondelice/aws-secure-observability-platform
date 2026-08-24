#!/usr/bin/env bash
set -euo pipefail

base_url="${1:-http://127.0.0.1:8000}"

curl --fail --silent --show-error \
  --connect-timeout 2 \
  --max-time 5 \
  "${base_url}/health"
