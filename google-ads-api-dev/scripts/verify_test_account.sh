#!/usr/bin/env bash
# GUARDRAIL: confirm the target customer is a Google Ads TEST account.
# Exits 0 only if customer.test_account == true. Run before any mutate.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/_lib.sh"

gads_require GADS_DEVELOPER_TOKEN GADS_LOGIN_CUSTOMER_ID GADS_CUSTOMER_ID
gads_need_cmd curl

out="$(bash "$here/gads_search.sh" \
  "SELECT customer.id, customer.descriptive_name, customer.test_account, customer.manager FROM customer")"

echo "$out"

is_test="$(printf '%s' "$out" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
except Exception:
    print("error"); sys.exit(0)
results = data.get("results") or []
if not results:
    print("error"); sys.exit(0)
cust = results[0].get("customer", {})
print("true" if cust.get("testAccount") is True else "false")
' 2>/dev/null || echo error)"

case "$is_test" in
  true)  echo "[guardrail] OK: customer.test_account = true — mutate is allowed."; exit 0 ;;
  false) echo "[guardrail] BLOCKED: customer.test_account is NOT true. Do NOT mutate." >&2; exit 1 ;;
  *)     echo "[guardrail] BLOCKED: could not confirm test_account (auth/parse error). Do NOT mutate." >&2; exit 1 ;;
esac
