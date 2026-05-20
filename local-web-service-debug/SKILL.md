---
name: local-web-service-debug
description: Use when asked to debug, inspect, or triage locally developed web services, especially Docker Compose apps with frontend/browser errors, API failures, PostgreSQL or MySQL state, worker/queue issues, localhost problems, failing health checks, migrations, logs, or end-to-end reproduction. This skill emphasizes read-only evidence gathering from Compose logs, Playwright browser probes, HTTP checks, and bounded database inspection before recommending changes.
---

# Local Web Service Debug

## Overview

Use this skill to debug local or development web services with a repeatable, evidence-first workflow. It is intended for Docker Compose based apps, but the browser and database parts are useful for non-Compose apps too.

Prefer the bundled scripts for the first pass:

```bash
bash local-web-service-debug/scripts/local_web_debug_snapshot.sh \
  --url http://localhost:3000 \
  --service web \
  --db-service db \
  --db-kind postgres \
  --db-user postgres \
  --db-name app
```

```bash
node local-web-service-debug/scripts/browser_probe.mjs \
  --url http://localhost:3000 \
  --wait-ms 3000
```

## Safety Rules

- Start with read-only checks: logs, process state, HTTP responses, browser console/network events, and bounded `SELECT` queries.
- Do not run destructive Docker commands such as `compose down -v`, `volume prune`, `system prune`, image removal, or database resets unless the user explicitly approves the exact action.
- Do not run write queries, migrations, seed scripts, queue drains, cache flushes, or admin actions against a database unless the user explicitly asks and accepts the blast radius.
- Do not print secrets. Redact passwords, tokens, cookies, authorization headers, connection strings, JWTs, API keys, and private env var values.
- Ask before using production or shared staging databases. Keep queries read-only and bounded with `LIMIT`.
- Avoid browser actions that can create, update, delete, send, purchase, or notify unless the user explicitly approves that interaction.

## Triage Workflow

1. Identify the target: URL, Compose project directory, app/frontend/API/worker/db service names, failing user flow, expected behavior, and when it last worked.
2. Run the Compose snapshot script from the target repository root. Use `--service` for the app/frontend/worker services involved and `--db-service` only when database state matters.
3. Run the browser probe against the failing URL to collect console errors, `pageerror`, failed requests, `4xx/5xx` responses, storage/cookie names, timing, and a screenshot.
4. Add `curl -i -L` checks for health endpoints, API routes, callback URLs, and static assets when the browser probe shows HTTP failures.
5. Inspect the database only after the symptom points there: connection errors, migration failures, lock waits, missing data, slow requests, or worker backlog.
6. Read `references/signals.md` for symptom-specific interpretation. Read `references/postgres.md` before writing custom PostgreSQL queries.
7. Separate confirmed evidence from hypotheses. Recommend the smallest next check or fix that follows from the evidence.

## Docker Compose Checks

The snapshot script collects Compose service inventory, container status, recent logs, images, volumes, networks, process lists, and `docker stats --no-stream` without changing resources.

Useful targeted commands when the bundled script is too broad:

```bash
docker compose ps -a
docker compose logs --no-color --timestamps --tail 200 --since 30m SERVICE
docker compose top SERVICE
docker compose exec -T SERVICE sh -lc 'printenv | sed -E "s/=.*/=[REDACTED]/" | sort'
docker compose exec -T SERVICE sh -lc 'curl -i http://localhost:PORT/health'
docker stats --no-stream
```

Use `docker compose config --services`, `--volumes`, `--networks`, `--profiles`, and `--images` instead of full `docker compose config` when secrets may be interpolated into the config.

## Browser Checks

The browser probe uses Playwright when the target repository has `playwright` or `@playwright/test` installed. It defaults to headless Chromium and writes artifacts to `/private/tmp` or `/tmp`.

```bash
node local-web-service-debug/scripts/browser_probe.mjs --url http://localhost:3000
node local-web-service-debug/scripts/browser_probe.mjs --url http://localhost:3000/login --storage-state .auth/user.json
node local-web-service-debug/scripts/browser_probe.mjs --url http://localhost:3000 --trace --har --wait-for text="Dashboard"
```

Collect browser evidence in this order:

- `pageerror` and console `error` / `warning`.
- Failed requests and `4xx/5xx` responses.
- First failing API route, status code, and request method.
- Current URL after redirects, page title, and screenshot.
- Cookie names/domains and storage keys only; values stay redacted by default.

## Database Checks

For PostgreSQL, prefer the bundled snapshot script with `--db-kind postgres`, then load `references/postgres.md` for more targeted read-only queries.

For MySQL, use the script for basic version/process/status checks, then inspect service logs and application connection errors before adding custom SQL.

Common database failure modes:

- App cannot connect: wrong host, port, network, credentials, database name, TLS mode, or startup order.
- Requests hang: connection pool exhaustion, lock waits, long transactions, slow queries, or missing indexes.
- Data looks wrong: migrations not applied, seed data missing, wrong database, stale local volume, or schema drift.
- Worker backlog: queue table growth, stuck advisory locks, failed jobs, or worker container crash loops.

## Output Pattern

Report results in this order:

- **Status**: most likely failing layer, or "not isolated yet".
- **Evidence**: concise facts from Compose, browser, HTTP, and database output.
- **Likely cause**: distinguish confirmed root cause from plausible hypothesis.
- **Next actions**: smallest safe checks or code changes first; ask before destructive or externally visible actions.
- **Gaps**: missing service names, missing credentials, blocked Playwright install, unavailable DB tools, or sandbox limits.
