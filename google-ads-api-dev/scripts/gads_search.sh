#!/usr/bin/env bash
# Run a GAQL query against the test customer via REST googleAds:search.
# Usage: gads_search.sh "SELECT campaign.id, campaign.name FROM campaign" [--stream]
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

query="${1:-}"
mode="search"
[ "${2:-}" = "--stream" ] && mode="searchStream"
if [ -z "$query" ]; then
  echo "Usage: gads_search.sh \"<GAQL>\" [--stream]" >&2
  exit 2
fi

gads_require GADS_DEVELOPER_TOKEN GADS_LOGIN_CUSTOMER_ID GADS_CUSTOMER_ID
gads_need_cmd curl
token="$(gads_access_token)"
cid="$(gads_cid "$GADS_CUSTOMER_ID")"
ver="$(gads_api_version)"

mapfile -t H < <(gads_headers "$token")
url="https://googleads.googleapis.com/${ver}/customers/${cid}/googleAds:${mode}"

body="$(printf '{"query":%s}' "$(printf '%s' "$query" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$query")")"

curl -sS -X POST "$url" \
  -H "${H[0]}" -H "${H[1]}" -H "${H[2]}" -H "${H[3]}" \
  --data "$body"
echo
