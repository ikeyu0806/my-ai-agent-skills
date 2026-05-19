#!/usr/bin/env bash
set -u

PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:${PATH:-}"

PROJECT=""
REGION=""
SERVICE=""
URL=""
SQL_INSTANCE=""
BACKEND_SERVICE=""
URL_MAP=""
FRESHNESS="2h"
LIMIT="50"
INCLUDE_INFO=0

usage() {
  cat <<'USAGE'
Usage: gcp_hosting_snapshot.sh [options]

Collect a read-only GCP hosting diagnostic snapshot for Cloud Run, external
HTTP(S) Load Balancing, Cloud Logging, and Cloud SQL PostgreSQL.

Options:
  --project PROJECT_ID       GCP project ID. Defaults to gcloud config project.
  --region REGION            Cloud Run / regional resource region.
  --service SERVICE          Cloud Run service name.
  --url URL                  Public URL or host used for LB log filtering.
  --sql-instance INSTANCE    Cloud SQL instance name.
  --backend-service NAME     Global backend service to describe and get health.
  --url-map NAME             Global URL map to describe.
  --freshness DURATION       Log freshness such as 30m, 2h, 1d. Default: 2h.
  --limit N                  Log/list limit. Default: 50. Max: 500.
  --include-info             Also fetch recent INFO Cloud Run logs.
  --help                     Show this help.

The script does not modify GCP resources and redacts Cloud Run env values when
printing service JSON. It still may reveal resource names, hostnames, IPs, and
log messages from the selected project.
USAGE
}

has() {
  command -v "$1" >/dev/null 2>&1
}

section() {
  printf '\n## %s\n' "$1"
}

note() {
  printf '\n[NOTE] %s\n' "$1"
}

run_block() {
  local title="$1"
  shift
  printf '\n### %s\n' "$title"
  printf '```text\n'
  "$@" 2>&1
  local status=$?
  if [ "$status" -ne 0 ]; then
    printf '[exit_status=%s]\n' "$status"
  fi
  printf '```\n'
}

run_redacted_json() {
  local title="$1"
  shift
  printf '\n### %s\n' "$title"
  printf '```json\n'

  local output status
  output="$("$@" 2>&1)"
  status=$?

  if [ "$status" -ne 0 ]; then
    printf '%s\n' "$output"
    printf '[exit_status=%s]\n' "$status"
    printf '```\n'
    return 0
  fi

  if has python3; then
    printf '%s' "$output" | python3 -c '
import json
import sys

SENSITIVE = (
    "authorization", "cookie", "credential", "dsn", "jwt", "key",
    "password", "private", "secret", "token",
)

def scrub_env(item):
    out = {}
    if "name" in item:
        out["name"] = item["name"]
    if "value" in item:
        out["value"] = "[REDACTED]"
    if "valueFrom" in item:
        out["valueFrom"] = scrub(item["valueFrom"])
    for key, value in item.items():
        if key not in out:
            out[key] = scrub(value)
    return out

def scrub(obj):
    if isinstance(obj, dict):
        out = {}
        for key, value in obj.items():
            lower = key.lower()
            if key == "env" and isinstance(value, list):
                out[key] = [scrub_env(entry) if isinstance(entry, dict) else scrub(entry) for entry in value]
            elif any(token in lower for token in SENSITIVE):
                out[key] = "[REDACTED]"
            else:
                out[key] = scrub(value)
        return out
    if isinstance(obj, list):
        return [scrub(item) for item in obj]
    return obj

try:
    data = json.load(sys.stdin)
except Exception as exc:
    print("[redaction_error] " + str(exc))
    sys.exit(0)

print(json.dumps(scrub(data), indent=2, sort_keys=True))
'
  else
    printf '%s\n' "$output"
    printf '[warning] python3 not found; JSON was not redacted by helper.\n'
  fi
  printf '```\n'
}

log_table_format='table(timestamp,severity,resource.type,resource.labels.service_name,resource.labels.revision_name,httpRequest.status,httpRequest.requestMethod,httpRequest.requestUrl,textPayload,jsonPayload.message,protoPayload.status.message)'

run_logs() {
  local title="$1"
  local filter="$2"
  run_block "$title" gcloud --project="$PROJECT" logging read "$filter" --freshness="$FRESHNESS" --limit="$LIMIT" --format="$log_table_format"
}

parse_url_host() {
  local raw="$1"
  if [ -z "$raw" ]; then
    printf ''
    return 0
  fi
  printf '%s' "$raw" | sed -E 's#^[a-zA-Z]+://([^/:/?#]+).*#\1#; s#^([^/:/?#]+).*#\1#'
}

parse_probe_url() {
  local raw="$1"
  if [ -z "$raw" ]; then
    printf ''
    return 0
  fi
  if [[ "$raw" =~ ^https?:// ]]; then
    printf '%s' "$raw"
  else
    printf 'https://%s/' "$raw"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project)
      shift
      PROJECT="${1:-}"
      ;;
    --region)
      shift
      REGION="${1:-}"
      ;;
    --service)
      shift
      SERVICE="${1:-}"
      ;;
    --url)
      shift
      URL="${1:-}"
      ;;
    --sql-instance)
      shift
      SQL_INSTANCE="${1:-}"
      ;;
    --backend-service)
      shift
      BACKEND_SERVICE="${1:-}"
      ;;
    --url-map)
      shift
      URL_MAP="${1:-}"
      ;;
    --freshness)
      shift
      FRESHNESS="${1:-}"
      ;;
    --limit)
      shift
      LIMIT="${1:-}"
      ;;
    --include-info)
      INCLUDE_INFO=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *)
      printf 'Unexpected argument: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if ! [[ "$LIMIT" =~ ^[0-9]+$ ]] || [ "$LIMIT" -lt 1 ] || [ "$LIMIT" -gt 500 ]; then
  printf 'Invalid --limit: %s\n' "$LIMIT" >&2
  exit 2
fi

if ! has gcloud; then
  printf 'gcloud was not found on PATH. Install Google Cloud CLI or run this from an environment with gcloud.\n' >&2
  exit 127
fi

if [ -z "$PROJECT" ]; then
  PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
fi

if [ -z "$PROJECT" ] || [ "$PROJECT" = "(unset)" ]; then
  printf 'No project provided and gcloud config project is unset. Pass --project PROJECT_ID.\n' >&2
  exit 2
fi

if [ -z "$REGION" ]; then
  REGION="$(gcloud config get-value run/region 2>/dev/null || true)"
  if [ "$REGION" = "(unset)" ]; then
    REGION=""
  fi
fi

URL_HOST="$(parse_url_host "$URL")"
PROBE_URL="$(parse_probe_url "$URL")"

section "Snapshot"
printf 'timestamp=%s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
printf 'project=%s\n' "$PROJECT"
printf 'region=%s\n' "${REGION:-[not set]}"
printf 'service=%s\n' "${SERVICE:-[not set]}"
printf 'url=%s\n' "${URL:-[not set]}"
printf 'url_host=%s\n' "${URL_HOST:-[not set]}"
printf 'probe_url=%s\n' "${PROBE_URL:-[not set]}"
printf 'sql_instance=%s\n' "${SQL_INSTANCE:-[not set]}"
printf 'freshness=%s\n' "$FRESHNESS"
printf 'limit=%s\n' "$LIMIT"

section "Gcloud Context"
run_block "Active account and config" gcloud config list
run_block "Authenticated accounts" gcloud auth list --filter=status:ACTIVE --format='table(account,status)'
run_block "Project summary" gcloud projects describe "$PROJECT" --format='yaml(projectId,name,lifecycleState)'
run_block "Relevant enabled APIs" gcloud --project="$PROJECT" services list --enabled --filter='config.name:(run.googleapis.com OR logging.googleapis.com OR compute.googleapis.com OR sqladmin.googleapis.com OR cloudbuild.googleapis.com OR artifactregistry.googleapis.com)' --format='table(config.name)'

section "Cloud Run"
run_block "Cloud Run services" gcloud --project="$PROJECT" run services list --platform=managed --limit="$LIMIT"
run_block "Cloud Run domain mappings" gcloud --project="$PROJECT" run domain-mappings list --platform=managed --limit="$LIMIT"

if [ -n "$SERVICE" ]; then
  if [ -z "$REGION" ]; then
    note "Cloud Run service was provided but region is unset; pass --region to describe service and revisions."
  else
    run_redacted_json "Cloud Run service describe (env values redacted)" gcloud --project="$PROJECT" run services describe "$SERVICE" --region="$REGION" --platform=managed --format=json
    run_block "Cloud Run revisions" gcloud --project="$PROJECT" run revisions list --region="$REGION" --service="$SERVICE" --sort-by='~metadata.creationTimestamp' --limit=10
    run_block "Cloud Run service IAM policy" gcloud --project="$PROJECT" run services get-iam-policy "$SERVICE" --region="$REGION" --platform=managed --format='yaml(bindings.role,bindings.members)'
  fi
fi

section "Cloud Run Logs"
RUN_FILTER='resource.type="cloud_run_revision"'
if [ -n "$SERVICE" ]; then
  RUN_FILTER="${RUN_FILTER} AND resource.labels.service_name=\"${SERVICE}\""
fi
run_logs "Cloud Run warnings/errors and 4xx/5xx" "${RUN_FILTER} AND (severity>=WARNING OR httpRequest.status>=400)"
run_logs "Cloud Run auth/OIDC keyword logs" "${RUN_FILTER} AND (\"auth0\" OR \"oauth\" OR \"oidc\" OR \"jwks\" OR \"jwt\" OR \"audience\" OR \"issuer\" OR \"callback\" OR \"unauthorized\" OR \"forbidden\")"
if [ "$INCLUDE_INFO" -eq 1 ]; then
  run_logs "Cloud Run recent logs including INFO" "$RUN_FILTER"
fi

section "Load Balancer"
if [ -n "$PROBE_URL" ] && has curl; then
  run_block "Public URL HTTP HEAD" curl -sS -I -L --connect-timeout 5 --max-time 15 "$PROBE_URL"
fi
run_block "Global forwarding rules" gcloud --project="$PROJECT" compute forwarding-rules list --global --limit="$LIMIT"
run_block "Target HTTPS proxies" gcloud --project="$PROJECT" compute target-https-proxies list --limit="$LIMIT"
run_block "URL maps" gcloud --project="$PROJECT" compute url-maps list --limit="$LIMIT"
run_block "Global backend services" gcloud --project="$PROJECT" compute backend-services list --global --limit="$LIMIT"
run_block "Network endpoint groups" gcloud --project="$PROJECT" compute network-endpoint-groups list --limit="$LIMIT"
run_block "SSL certificates" gcloud --project="$PROJECT" compute ssl-certificates list --limit="$LIMIT"
run_block "Certificate Manager certificates" gcloud --project="$PROJECT" certificate-manager certificates list --limit="$LIMIT"
run_block "Certificate Manager maps" gcloud --project="$PROJECT" certificate-manager maps list --limit="$LIMIT"
run_block "Cloud Armor security policies" gcloud --project="$PROJECT" compute security-policies list --limit="$LIMIT"

if [ -n "$URL_MAP" ]; then
  run_block "URL map describe" gcloud --project="$PROJECT" compute url-maps describe "$URL_MAP" --global
fi

if [ -n "$BACKEND_SERVICE" ]; then
  run_block "Backend service describe" gcloud --project="$PROJECT" compute backend-services describe "$BACKEND_SERVICE" --global
  run_block "Backend service health" gcloud --project="$PROJECT" compute backend-services get-health "$BACKEND_SERVICE" --global
fi

section "Load Balancer Logs"
LB_FILTER='resource.type="http_load_balancer" AND httpRequest.status>=400'
if [ -n "$URL_HOST" ]; then
  LB_FILTER="${LB_FILTER} AND httpRequest.requestUrl:\"${URL_HOST}\""
fi
run_logs "HTTP(S) load balancer 4xx/5xx" "$LB_FILTER"

section "Cloud SQL PostgreSQL"
run_block "Cloud SQL instances" gcloud --project="$PROJECT" sql instances list

if [ -n "$SQL_INSTANCE" ]; then
  run_redacted_json "Cloud SQL instance describe" gcloud --project="$PROJECT" sql instances describe "$SQL_INSTANCE" --format=json
  run_block "Cloud SQL recent operations" gcloud --project="$PROJECT" sql operations list --instance="$SQL_INSTANCE" --limit=20 --sort-by='~startTime'
  run_block "Cloud SQL backups" gcloud --project="$PROJECT" sql backups list --instance="$SQL_INSTANCE" --limit=10

  SQL_FILTER="resource.type=\"cloudsql_database\" AND resource.labels.database_id=\"${PROJECT}:${SQL_INSTANCE}\" AND (severity>=WARNING OR \"FATAL\" OR \"ERROR\" OR \"too many connections\" OR \"deadlock\" OR \"timeout\")"
  run_logs "Cloud SQL warnings/errors" "$SQL_FILTER"
fi

section "Interpretation Notes"
cat <<'NOTES'
- A Cloud Run latestCreatedRevision that differs from latestReadyRevision often points to deploy/startup failure.
- LB 404 usually points to host/path rule mismatch. LB 502/503/504 points to backend, serverless NEG, timeout, or upstream application failure.
- Cloud Run 401/403 with Auth0/OIDC keywords usually needs issuer/audience/callback/cookie-domain checks before infrastructure changes.
- Cloud SQL connection errors can come from max connections, private IP/VPC connector path, IAM/proxy auth, TLS, or database-level locks.
- The script is read-only, but log output can contain sensitive application messages. Summarize carefully.
NOTES
