---
name: gcp-hosting-debug
description: Use when asked to debug, inspect, or triage Google Cloud hosted web services using Cloud Run, external HTTP(S) Load Balancing, serverless NEGs, Cloud Logging, Cloud SQL PostgreSQL, OAuth/OIDC/Auth0 authentication, custom domains, TLS, or production/staging hosting incidents. This skill emphasizes read-only gcloud diagnostics, safe log filtering, secret redaction, and generic service troubleshooting without being tied to a specific GCP project.
---

# GCP Hosting Debug

## Overview

Use this skill to debug GCP-hosted services with a repeatable, read-only workflow. Prefer the bundled snapshot script for first-pass evidence, then run targeted `gcloud`, `curl`, or read-only PostgreSQL checks based on the symptom.

## Safety Rules

- Start with read-only checks. Do not deploy, update traffic, modify IAM, edit load balancers, rotate secrets, restart databases, delete revisions, or change Cloud SQL settings unless the user explicitly approves the exact action.
- Do not print secret values. Redact Cloud Run environment variable values, Auth0 client secrets, database passwords, cookies, authorization headers, JWTs, refresh tokens, and connection strings.
- Use `--project` explicitly once the target project is known. If `gcloud config get-value project` differs from the requested project, call that out before proceeding.
- Treat production logs and database metadata as sensitive. Summarize only the rows needed to explain the issue.
- Ask before running `psql` queries against production. Keep queries read-only, bounded with `LIMIT`, and avoid selecting user PII unless the user specifically asks.
- If permissions block a check, report the missing role or API surface rather than guessing from incomplete evidence.

## Quick Start

Resolve the script path relative to this skill directory. In this checkout:

```bash
bash gcp-hosting-debug/scripts/gcp_hosting_snapshot.sh \
  --project PROJECT_ID \
  --region REGION \
  --service CLOUD_RUN_SERVICE \
  --url https://example.com \
  --sql-instance CLOUD_SQL_INSTANCE \
  --freshness 2h
```

When only the project is known, start broad:

```bash
bash gcp-hosting-debug/scripts/gcp_hosting_snapshot.sh --project PROJECT_ID --freshness 4h
```

When debugging only logs for a service:

```bash
bash gcp-hosting-debug/scripts/gcp_hosting_snapshot.sh \
  --project PROJECT_ID --region REGION --service SERVICE --freshness 30m --limit 100
```

## Triage Workflow

1. Identify the target: project ID, region, Cloud Run service, external URL or host, Cloud SQL instance, environment, approximate deploy time, and symptom such as 404, 401/403, 500, 502/503/504, slow responses, failed callback, or database errors.
2. Confirm `gcloud` context:

```bash
gcloud auth list
gcloud config list
```

3. Run the snapshot script with the known identifiers. It gathers Cloud Run service/revision state, recent Cloud Run logs, load balancer inventory/logs, Cloud SQL state/logs, and project API hints without changing resources.
4. Read `references/signals.md` when interpreting ambiguous Cloud Run, LB, OAuth/Auth0, or PostgreSQL findings.
5. Narrow by layer:
   - **Client/domain/TLS**: use `curl -I -L https://host/path`, certificate checks, and LB request logs.
   - **Load balancer/serverless NEG**: check URL maps, backend services, NEG target service, and `http_load_balancer` status patterns.
   - **Cloud Run**: check revision readiness, traffic split, startup/container errors, concurrency/timeouts, service account, VPC connector, Cloud SQL annotations, and recent deployment time.
   - **Auth0/OIDC**: check issuer, audience, callback URL, cookie domain, JWKS/cache, redirect URI, and 401/403 log messages without exposing secrets.
   - **Cloud SQL/PostgreSQL**: check instance state, operations, database logs, connection exhaustion, lock waits, TLS/private IP/proxy path, and read-only Postgres stats if approved.
6. Separate confirmed evidence from plausible causes. Do not recommend config changes until the relevant layer has supporting logs or state.

## Targeted Commands

Use these when the snapshot points to a layer that needs more detail.

**Cloud Run service and revisions**

```bash
gcloud run services describe SERVICE --project PROJECT_ID --region REGION --platform managed \
  --format='yaml(metadata.name,status.url,status.conditions,status.traffic,status.latestReadyRevisionName,status.latestCreatedRevisionName,spec.template.metadata.annotations,spec.template.spec.serviceAccountName,spec.template.spec.containerConcurrency,spec.template.spec.timeoutSeconds,spec.template.spec.containers[].image,spec.template.spec.containers[].ports,spec.template.spec.containers[].resources)'
gcloud run revisions list --project PROJECT_ID --region REGION --service SERVICE --sort-by="~metadata.creationTimestamp"
gcloud run services get-iam-policy SERVICE --project PROJECT_ID --region REGION --platform managed
```

**Cloud Run logs**

```bash
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="SERVICE" AND (severity>=WARNING OR httpRequest.status>=400)' \
  --project PROJECT_ID --freshness 2h --limit 100
```

**Load balancer and serverless NEG**

```bash
gcloud compute forwarding-rules list --project PROJECT_ID --global
gcloud compute target-https-proxies list --project PROJECT_ID
gcloud compute url-maps list --project PROJECT_ID
gcloud compute backend-services list --project PROJECT_ID --global
gcloud compute network-endpoint-groups list --project PROJECT_ID --regions REGION
gcloud certificate-manager certificates list --project PROJECT_ID
gcloud compute security-policies list --project PROJECT_ID
```

**Load balancer request logs**

```bash
gcloud logging read 'resource.type="http_load_balancer" AND httpRequest.status>=400 AND httpRequest.requestUrl:"example.com"' \
  --project PROJECT_ID --freshness 2h --limit 100
```

**Cloud SQL PostgreSQL**

```bash
gcloud sql instances describe INSTANCE --project PROJECT_ID
gcloud sql operations list --project PROJECT_ID --instance INSTANCE --limit 20 --sort-by="~startTime"
gcloud logging read 'resource.type="cloudsql_database" AND resource.labels.database_id="PROJECT_ID:INSTANCE" AND severity>=WARNING' \
  --project PROJECT_ID --freshness 2h --limit 100
```

## OAuth/Auth0 Checks

Auth0 tenant logs are not available through `gcloud`. Use GCP logs to identify application-side symptoms, then inspect Auth0 Dashboard/API/CLI only if the user has access.

Check these without printing secrets:

- Cloud Run env var names for issuer, audience, domain, callback URL, client ID, and secret references.
- Auth0 allowed callback/logout/web origins against the deployed URL and custom domain.
- Application logs for `invalid_grant`, `invalid_token`, `audience`, `issuer`, `jwks`, `callback`, `state`, `nonce`, `cookie`, `unauthorized`, and `forbidden`.
- Clock skew, changed custom domain, stale JWKS cache, and mismatched staging/production tenant variables.

## Output Pattern

Report results in this order:

- **Status**: the most likely failing layer or "no clear fault isolated yet".
- **Evidence**: concise bullets with command output facts, timestamps, status codes, revision names, or Cloud SQL operation states.
- **Likely cause**: distinguish confirmed root cause from plausible hypothesis.
- **Next actions**: smallest safe checks first; ask before mutations or production database queries.
- **Gaps**: missing permissions, missing logs, unknown project/region/service, or sandbox limits.
