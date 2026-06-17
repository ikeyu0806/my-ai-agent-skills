#!/usr/bin/env bash
# Run a :mutate against the test customer via REST.
# Usage: gads_mutate.sh [--validate-only] <resourceCollection> '<json operations or full body>'
#   resourceCollection e.g.: campaignBudgets | campaigns | adGroups | adGroupAds | adGroupCriteria
# The JSON arg may be either a full request body ({"operations":[...]}) or just
# the operations array ([...]); a bare {"operations":...} is used as-is.
# By default this script REQUIRES test-account verification to pass first.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/_lib.sh"

validate_only="false"
skip_guard="0"
args=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --validate-only) validate_only="true" ;;
    --skip-guard)    skip_guard="1" ;;   # escape hatch; avoid unless you verified separately
    *) args+=("$1") ;;
  esac
  shift
done

collection="${args[0]:-}"
payload="${args[1]:-}"
if [ -z "$collection" ] || [ -z "$payload" ]; then
  echo "Usage: gads_mutate.sh [--validate-only] <resourceCollection> '<json>'" >&2
  exit 2
fi

gads_require GADS_DEVELOPER_TOKEN GADS_LOGIN_CUSTOMER_ID GADS_CUSTOMER_ID
gads_need_cmd curl

# Guardrail unless explicitly skipped.
if [ "$skip_guard" != "1" ]; then
  if ! bash "$here/verify_test_account.sh" >/dev/null 2>&1; then
    echo "[mutate] BLOCKED: test-account guardrail failed. Run verify_test_account.sh and resolve before mutating." >&2
    exit 1
  fi
fi

token="$(gads_access_token)"
cid="$(gads_cid "$GADS_CUSTOMER_ID")"
ver="$(gads_api_version)"
url="https://googleads.googleapis.com/${ver}/customers/${cid}/${collection}:mutate"

# Normalize payload into a full request body and inject validateOnly.
body="$(printf '%s' "$payload" | python3 -c '
import sys, json
raw = sys.stdin.read().strip()
vo = "'"$validate_only"'" == "true"
try:
    data = json.loads(raw)
except Exception as e:
    sys.stderr.write("Invalid JSON payload: %s\n" % e); sys.exit(3)
if isinstance(data, list):
    body = {"operations": data}
elif isinstance(data, dict) and "operations" in data:
    body = data
else:
    body = {"operations": [data]}
body["validateOnly"] = vo
body.setdefault("responseContentType", "MUTABLE_RESOURCE")
print(json.dumps(body))
')"

mapfile -t H < <(gads_headers "$token")
echo "[mutate] ${collection}:mutate validateOnly=${validate_only}" >&2
curl -sS -X POST "$url" \
  -H "${H[0]}" -H "${H[1]}" -H "${H[2]}" -H "${H[3]}" \
  --data "$body"
echo
