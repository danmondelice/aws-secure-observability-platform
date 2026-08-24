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
request_count=${WAF_TEST_REQUESTS:-130}

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

if [[ ! $request_count =~ ^[0-9]+$ ]] || (( request_count < 1 || request_count > 200 )); then
  echo "WAF_TEST_REQUESTS must be an integer from 1 through 200." >&2
  exit 2
fi

allowed=0
blocked=0
other=0

echo "Sending at most $request_count sequential requests; no concurrency is used."
for ((request_number = 1; request_number <= request_count; request_number++)); do
  status=$(curl --silent --show-error --location \
    --connect-timeout 5 --max-time 10 \
    --output /dev/null --write-out '%{http_code}' \
    --user-agent 'asop-controlled-rate-test/1.0' "$base_url/health")

  case "$status" in
    200) ((allowed += 1)) || true ;;
    403) ((blocked += 1)) || true ;;
    *) ((other += 1)) || true ;;
  esac
done

printf 'allowed=%d blocked=%d other=%d total=%d\n' "$allowed" "$blocked" "$other" "$request_count"

if (( blocked == 0 )); then
  echo "No 403 was observed. Wait for WAF evaluation, confirm the configured threshold, and rerun once." >&2
  exit 1
fi

echo "PASS: the bounded request sequence produced WAF blocks. Confirm the rate rule in WAF logs before closing the experiment."
