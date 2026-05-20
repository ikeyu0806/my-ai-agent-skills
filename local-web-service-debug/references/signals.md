# Local Web Service Debug Signals

Use this as a symptom-to-evidence map after the first snapshot. Do not treat any single signal as proof without matching logs or runtime state.

## Page Does Not Load

Likely layers:

- Dev server is not listening or bound to a different port.
- Reverse proxy routes to the wrong service/port.
- Frontend build failed but container stayed running.
- Browser is stuck on an auth redirect loop.

Checks:

- `docker compose ps -a` for missing ports, unhealthy containers, restarts, and exited services.
- `docker compose logs --since 30m frontend web proxy` for build/runtime errors.
- `curl -i -L http://localhost:PORT/` from the host.
- `docker compose exec -T proxy sh -lc 'curl -i http://SERVICE:PORT/'` to separate host-port issues from container-network issues.
- Browser probe current URL, response statuses, console errors, and screenshot.

## API Returns 500

Likely layers:

- Application exception.
- Database connection or migration problem.
- Missing env var or wrong secret reference.
- Backend cannot reach a dependent service.

Checks:

- App logs around the timestamp and request path.
- Browser probe first failing API route and status.
- `curl -i` the exact API route.
- DB service logs and `pg_stat_activity` if the app logs mention database timeouts or SQL errors.
- Redacted env var names, not values, for missing config.

## API Returns 401 Or 403

Likely layers:

- User is unauthenticated or session cookie is not sent.
- Cookie domain, `SameSite`, `Secure`, or callback URL mismatch.
- OIDC/Auth0 issuer, audience, client ID, or redirect URI mismatch.
- CSRF token missing or stale.

Checks:

- Browser cookie names/domains and current URL after redirects.
- Response status for login, callback, session, and protected API routes.
- App logs for `unauthorized`, `forbidden`, `csrf`, `state`, `nonce`, `audience`, `issuer`, or `callback`.
- Compare local URL scheme/host/port against auth provider allowed origins and callback URLs.

## CORS Or Preflight Failure

Likely layers:

- API does not allow the frontend origin.
- Proxy strips `OPTIONS` or CORS headers.
- Credentials mode conflicts with wildcard origins.

Checks:

- Browser console error and failed `OPTIONS` request.
- `curl -i -X OPTIONS` with `Origin` and `Access-Control-Request-Method` headers.
- API/proxy logs for `OPTIONS` route handling.
- Confirm `Access-Control-Allow-Origin`, `Access-Control-Allow-Credentials`, and allowed headers.

## Request Hangs Or Is Slow

Likely layers:

- DB lock wait, slow query, or connection pool exhaustion.
- Upstream service timeout.
- Worker/job dependency not processing.
- CPU or memory pressure in a container.

Checks:

- Browser timing and first slow request.
- App logs for timeout, retry, pool, or upstream errors.
- `docker stats --no-stream`.
- PostgreSQL `pg_stat_activity`, blocking locks, and connection counts.
- Worker logs and queue/backlog tables if applicable.

## WebSocket Or SSE Fails

Likely layers:

- Proxy does not support upgrade/streaming.
- Wrong public URL or protocol.
- Auth token/cookie not sent on the stream request.
- Server process restarts and drops connections.

Checks:

- Browser console and network failed request details.
- Reverse proxy logs and config for upgrade headers and buffering.
- App logs for connection accepted/closed.
- Container restart count.

## Static Assets 404 Or MIME Errors

Likely layers:

- Build output path mismatch.
- Proxy/static server points to the wrong directory.
- Asset prefix/base path mismatch.
- Old HTML references new assets or vice versa.

Checks:

- Browser failed asset URLs and MIME console errors.
- `curl -I` the failing asset.
- Frontend build logs.
- Container filesystem listing of the expected asset directory.
- Framework base path, asset prefix, and public URL config.

## Database Looks Empty Or Wrong

Likely layers:

- App points at a different database than expected.
- Named Docker volume contains stale state.
- Migrations or seeds did not run.
- Test/dev/prod env variables are mixed.

Checks:

- PostgreSQL connection identity query.
- Migration table latest rows.
- Expected table counts with `limit`ed, non-PII queries.
- Compose volume labels and service env var names.
- App startup logs showing database host/name after redaction.

## Worker Or Queue Issues

Likely layers:

- Worker container exited or is crash-looping.
- Queue/broker service unavailable.
- Jobs fail repeatedly because app and worker env differ.
- Advisory lock or singleton worker lock is stuck.

Checks:

- `docker compose ps -a worker queue redis`.
- Worker logs and restart count.
- Queue table or Redis queue length, if known.
- DB lock/advisory lock checks for PostgreSQL-backed workers.
- Compare redacted env var names between app and worker services.
