# GCP Hosting Debug Signals

Use this reference after collecting a snapshot. Keep conclusions tied to timestamps, status codes, revision names, and resource names from the evidence.

## Cloud Run

Common signals:

- `latestCreatedRevisionName` differs from `latestReadyRevisionName`: the newest deployment probably failed readiness/startup.
- Service conditions contain `Ready=False`, `ConfigurationsReady=False`, or `RoutesReady=False`: inspect the condition message and the newest revision logs.
- Traffic split does not point to the expected revision: users may still be hitting an older image or rollback.
- `Container failed to start`, port errors, or health check failures: verify the app listens on `$PORT`, starts within timeout, and image architecture/runtime is correct.
- 500s with app stack traces: application bug or dependency failure, not load balancer routing.
- 503s from Cloud Run with little app logging: cold start timeout, startup failure, concurrency/resource exhaustion, min instances, VPC connector, or platform/backend reachability issue.
- Timeouts near the configured request timeout: slow downstream calls, database locks, or missing timeout handling.

Check Cloud Run config without exposing secrets:

```bash
gcloud run services describe SERVICE --project PROJECT_ID --region REGION --platform managed --format json
```

Redact `env[].value`, `secretKeyRef`, JWTs, DSNs, and authorization strings before sharing output.

## External HTTP(S) Load Balancing

Common signals:

- 404 from load balancer: host rule/path matcher mismatch, URL map default backend, missing custom domain path, or request reaching a different LB.
- 502: backend closed connection, invalid response, serverless NEG/backend issue, TLS/proxy mismatch, or application crash during request.
- 503: backend unavailable, no healthy/reachable backend, serverless NEG misconfiguration, or Cloud Run service not ready.
- 504: backend timeout; compare LB logs with Cloud Run request duration and app logs.
- Certificate active but browser fails: check DNS points to the LB IP, certificate SANs include the host, and managed cert status is active.
- Works on `run.app` but fails on custom domain: focus on LB URL map, host rules, certificate, Cloud Armor, CDN, and custom-domain-specific app config.
- 403 only through the custom domain: check Cloud Armor security policies, IAP, app-level host checks, and Auth0 allowed origins.

Useful inventory commands:

```bash
gcloud compute forwarding-rules list --project PROJECT_ID --global
gcloud compute url-maps describe URL_MAP --project PROJECT_ID --global
gcloud compute backend-services describe BACKEND --project PROJECT_ID --global
gcloud compute network-endpoint-groups list --project PROJECT_ID --regions REGION
gcloud certificate-manager certificates list --project PROJECT_ID
gcloud compute security-policies list --project PROJECT_ID
```

## OAuth, OIDC, And Auth0

Auth failures often look like infrastructure problems because the callback goes through the same LB and Cloud Run service.

Check:

- Auth0 allowed callback URLs, logout URLs, and web origins exactly match the deployed scheme, host, and path.
- App issuer/domain uses the same Auth0 tenant as the client ID.
- API audience expected by the app matches the token audience.
- Cookie domain and secure/same-site settings work for the custom domain.
- Staging and production env vars are not crossed.
- JWKS cache refresh handles key rotation.
- Redirect URI uses HTTPS and the externally visible host, not the internal `run.app` URL unless intended.

Search app logs for:

```text
auth0 oauth oidc jwt jwks audience issuer callback redirect_uri state nonce cookie unauthorized forbidden invalid_grant invalid_token
```

Do not print client secrets, refresh tokens, full ID/access tokens, cookies, or authorization headers. Token headers/claims can be decoded locally only after redacting subject, email, and custom PII claims.

## Cloud SQL PostgreSQL

GCP-level signals:

- Cloud SQL instance `RUNNABLE` with recent failed operations: inspect operation error details.
- Restart/failover/maintenance near incident time: correlate with application 500/503 and connection logs.
- Private IP instance with Cloud Run: verify Serverless VPC Access connector or Direct VPC egress, network, and firewall path.
- Public IP instance: verify authorized networks, Cloud SQL connector/proxy/IAM auth, and TLS requirements.
- Database logs mention `too many connections`: inspect app connection pool size, Cloud Run max instances/concurrency, and Postgres `max_connections`.
- Logs mention `deadlock detected`, `canceling statement due to statement timeout`, or lock waits: inspect database activity before changing infrastructure.

Read-only `psql` snippets, after user approval:

```sql
select now(), version();
select count(*) as connections, state from pg_stat_activity group by state order by connections desc;
select pid, usename, application_name, client_addr, state, wait_event_type, wait_event, now() - query_start as age
from pg_stat_activity
where state <> 'idle'
order by age desc
limit 20;
select locktype, mode, granted, count(*) from pg_locks group by locktype, mode, granted order by count desc;
```

Avoid selecting application tables unless the user explicitly asks and the data sensitivity is understood.

## Log Filters

Cloud Run warnings and HTTP failures:

```text
resource.type="cloud_run_revision"
AND resource.labels.service_name="SERVICE"
AND (severity>=WARNING OR httpRequest.status>=400)
```

Load balancer failures for a host:

```text
resource.type="http_load_balancer"
AND httpRequest.status>=400
AND httpRequest.requestUrl:"example.com"
```

Cloud SQL PostgreSQL errors:

```text
resource.type="cloudsql_database"
AND resource.labels.database_id="PROJECT_ID:INSTANCE"
AND (severity>=WARNING OR "FATAL" OR "ERROR" OR "too many connections" OR "deadlock" OR "timeout")
```

Auth/OIDC keywords:

```text
"auth0" OR "oauth" OR "oidc" OR "jwks" OR "jwt" OR "audience" OR "issuer" OR "callback" OR "unauthorized" OR "forbidden"
```
