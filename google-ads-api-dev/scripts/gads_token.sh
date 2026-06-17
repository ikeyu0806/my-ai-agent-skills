#!/usr/bin/env bash
# Mint a short-lived Google Ads OAuth2 access token from the refresh token.
# Prints the token to stdout. REDACT it when sharing output.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

gads_require GADS_DEVELOPER_TOKEN GADS_CLIENT_ID GADS_CLIENT_SECRET GADS_REFRESH_TOKEN
token="$(gads_access_token)"
printf '%s\n' "$token"
