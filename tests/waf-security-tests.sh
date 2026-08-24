#!/usr/bin/env bash
set -euo pipefail

if [[ ${CONFIRM_OWNED_AWS_LAB:-} != "yes" ]]; then
  echo "Refusing to run. Set CONFIRM_OWNED_AWS_LAB=yes only for your deployed lab." >&2
  exit 2
fi

if [[ $# -ne 1 ]]; then
  echo "Usage: CONFIRM_OWNED_AWS_LAB=yes $0 https://your-lab-host" >&2
  exit 2
fi

base_url=${1%/}
if [[ ! $base_url =~ ^https?://[A-Za-z0-9.-]+(:[0-9]+)?$ ]]; then
  echo "Target must be a bare HTTP(S) origin with no path, query, or credentials." >&2
  exit 2
fi

host=${base_url#*://}
host=${host%%:*}
if [[ $host != *.elb.amazonaws.com && ${ALLOW_CUSTOM_LAB_HOST:-} != "yes" ]]; then
  echo "Target is not an AWS ALB hostname. Set ALLOW_CUSTOM_LAB_HOST=yes only for your owned lab domain." >&2
  exit 2
fi

request_status() {
  curl --silent --show-error --location \
    --connect-timeout 5 --max-time 15 \
    --output /dev/null --write-out '%{http_code}' \
    --user-agent 'asop-controlled-waf-test/1.0' "$1"
}

assert_status() {
  local name=$1 expected=$2 url=$3 actual
  actual=$(request_status "$url")
  printf '%-24s expected=%s actual=%s\n' "$name" "$expected" "$actual"
  [[ $actual == "$expected" ]]
}

echo "Running three bounded requests against the explicitly confirmed lab target."
assert_status "normal request" "200" "$base_url/"
assert_status "encoded SQLi pattern" "403" "$base_url/api/products?id=1%27%20OR%201%3D1--"
assert_status "encoded XSS pattern" "403" "$base_url/?q=%3Cscript%3Ealert%281%29%3C%2Fscript%3E"

echo "PASS: normal traffic remained available and both controlled patterns were blocked."
