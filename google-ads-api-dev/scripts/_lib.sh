#!/usr/bin/env bash
# Shared helpers for google-ads-api-dev scripts. Source this; do not run directly.
set -u

# Optionally load a google-ads.env from cwd or the skill dir without echoing it.
_gads_load_env() {
  local f
  for f in "./google-ads.env" "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/google-ads.env"; do
    if [ -f "$f" ]; then
      set -a
      # shellcheck disable=SC1090
      . "$f"
      set +a
      break
    fi
  done
}

gads_require() {
  local missing=0 v
  for v in "$@"; do
    if [ -z "${!v:-}" ]; then
      printf 'Missing required env: %s\n' "$v" >&2
      missing=1
    fi
  done
  [ "$missing" -eq 0 ] || return 1
}

gads_api_version() { printf '%s' "${GADS_API_VERSION:-v23}"; }

# Strip dashes/spaces from a customer id.
gads_cid() { printf '%s' "$1" | tr -d '- '; }

gads_need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { printf 'Required command not found: %s\n' "$1" >&2; return 1; }
}

# Mint an access token from the refresh token. Prints ONLY the token (no secrets).
gads_access_token() {
  gads_need_cmd curl || return 1
  gads_require GADS_CLIENT_ID GADS_CLIENT_SECRET GADS_REFRESH_TOKEN || return 1
  local resp token
  resp="$(curl -sS https://oauth2.googleapis.com/token \
    -d client_id="$GADS_CLIENT_ID" \
    -d client_secret="$GADS_CLIENT_SECRET" \
    -d refresh_token="$GADS_REFRESH_TOKEN" \
    -d grant_type=refresh_token)" || { printf 'Token request failed\n' >&2; return 1; }
  if command -v python3 >/dev/null 2>&1; then
    token="$(printf '%s' "$resp" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null)"
  else
    token="$(printf '%s' "$resp" | sed -n 's/.*"access_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  fi
  if [ -z "$token" ]; then
    printf 'Could not obtain access token. OAuth error (secrets redacted):\n' >&2
    printf '%s\n' "$resp" | sed -E 's/("(access_token|id_token)"[[:space:]]*:[[:space:]]*")[^"]*/\1***/g' >&2
    return 1
  fi
  printf '%s' "$token"
}

# Common curl headers for the Google Ads REST API. Usage: gads_headers <access_token>
# Emits repeated -H args on stdout, one per line (read with mapfile).
gads_headers() {
  local token="$1"
  printf '%s\n' \
    "Authorization: Bearer ${token}" \
    "developer-token: ${GADS_DEVELOPER_TOKEN}" \
    "login-customer-id: $(gads_cid "${GADS_LOGIN_CUSTOMER_ID}")" \
    "Content-Type: application/json"
}

_gads_load_env
