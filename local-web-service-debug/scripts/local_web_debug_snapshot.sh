#!/usr/bin/env bash
set -u

PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:${PATH:-}"

PROJECT=""
TAIL="200"
SINCE="30m"
DB_SERVICE=""
DB_KIND="auto"
DB_USER=""
DB_NAME=""
MYSQL_USER=""
MYSQL_DATABASE=""
MYSQL_PASSWORD_ENV=""
POSTGRES_URL_ENV=""
SKIP_LOGS=0
SKIP_STATS=0

COMPOSE_FILES=()
SERVICES=()
URLS=()

usage() {
  cat <<'USAGE'
Usage: local_web_debug_snapshot.sh [options]

Collect a read-only local web service diagnostic snapshot for Docker Compose,
HTTP endpoints, and optional PostgreSQL/MySQL database state.

Options:
  --compose-file FILE       Compose file to pass with -f. Can be repeated.
  --project NAME            Compose project name to pass with -p.
  --service NAME            Service to focus logs/top output on. Can be repeated.
  --url URL                 HTTP URL to probe with curl. Can be repeated.
  --tail N                  Log lines per service. Default: 200.
  --since DURATION          Compose log freshness such as 10m, 30m, 2h. Default: 30m.
  --db-service NAME         Compose service that has psql or mysql installed.
  --db-kind KIND            auto, postgres, or mysql. Default: auto.
  --db-user USER            Database user for PostgreSQL or MySQL.
  --db-name NAME            Database name for PostgreSQL, also used for MySQL if --mysql-database is omitted.
  --postgres-url-env NAME   Environment variable containing a PostgreSQL connection string for local psql.
  --mysql-user USER         MySQL user. Defaults to --db-user when omitted.
  --mysql-database NAME     MySQL database. Defaults to --db-name when omitted.
  --mysql-password-env NAME Environment variable containing the MySQL password.
  --skip-logs               Skip docker compose logs.
  --skip-stats              Skip docker stats.
  --help                    Show this help.

The script does not modify Docker resources or database data. It avoids printing
full Compose config and does not print connection strings or password values.
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

while [ "$#" -gt 0 ]; do
  case "$1" in
    --compose-file|-f)
      shift
      COMPOSE_FILES+=("${1:-}")
      ;;
    --project|-p)
      shift
      PROJECT="${1:-}"
      ;;
    --service)
      shift
      SERVICES+=("${1:-}")
      ;;
    --url)
      shift
      URLS+=("${1:-}")
      ;;
    --tail)
      shift
      TAIL="${1:-}"
      ;;
    --since)
      shift
      SINCE="${1:-}"
      ;;
    --db-service)
      shift
      DB_SERVICE="${1:-}"
      ;;
    --db-kind)
      shift
      DB_KIND="${1:-}"
      ;;
    --db-user)
      shift
      DB_USER="${1:-}"
      ;;
    --db-name)
      shift
      DB_NAME="${1:-}"
      ;;
    --postgres-url-env)
      shift
      POSTGRES_URL_ENV="${1:-}"
      ;;
    --mysql-user)
      shift
      MYSQL_USER="${1:-}"
      ;;
    --mysql-database)
      shift
      MYSQL_DATABASE="${1:-}"
      ;;
    --mysql-password-env)
      shift
      MYSQL_PASSWORD_ENV="${1:-}"
      ;;
    --skip-logs)
      SKIP_LOGS=1
      ;;
    --skip-stats)
      SKIP_STATS=1
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

if ! [[ "$TAIL" =~ ^[0-9]+$ ]] || [ "$TAIL" -lt 1 ] || [ "$TAIL" -gt 5000 ]; then
  printf 'Invalid --tail: %s\n' "$TAIL" >&2
  exit 2
fi

case "$DB_KIND" in
  auto|postgres|mysql) ;;
  *)
    printf 'Invalid --db-kind: %s\n' "$DB_KIND" >&2
    exit 2
    ;;
esac

compose_base=(docker compose)
for file in "${COMPOSE_FILES[@]}"; do
  if [ -n "$file" ]; then
    compose_base+=(-f "$file")
  fi
done
if [ -n "$PROJECT" ]; then
  compose_base+=(-p "$PROJECT")
fi

run_compose() {
  local title="$1"
  shift
  run_block "$title" "${compose_base[@]}" "$@"
}

run_compose_for_services() {
  local title="$1"
  shift
  if [ "${#SERVICES[@]}" -gt 0 ]; then
    run_block "$title" "${compose_base[@]}" "$@" "${SERVICES[@]}"
  else
    run_block "$title" "${compose_base[@]}" "$@"
  fi
}

print_header() {
  printf '# Local Web Service Debug Snapshot\n'
  printf '\n- cwd: %s\n' "$(pwd)"
  printf -- '- checked_at: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- services: %s\n' "${SERVICES[*]:-(all)}"
  printf -- '- urls: %s\n' "${URLS[*]:-(none)}"
  printf -- '- log_since: %s\n' "$SINCE"
  printf -- '- log_tail: %s\n' "$TAIL"
  if [ -n "$DB_SERVICE" ]; then
    printf -- '- db_service: %s\n' "$DB_SERVICE"
  fi
  if [ -n "$POSTGRES_URL_ENV" ]; then
    printf -- '- postgres_url_env: %s (value not printed)\n' "$POSTGRES_URL_ENV"
  fi
}

print_header

section "Tool availability"
if has docker; then
  run_block "Docker version" docker version --format 'Client={{.Client.Version}} Server={{.Server.Version}}'
else
  note "docker command not found on PATH."
  exit 127
fi

if docker compose version >/dev/null 2>&1; then
  run_block "Docker Compose version" docker compose version
else
  note "docker compose is unavailable or Docker is not running."
fi

if has curl; then
  run_block "curl version" curl --version
else
  note "curl command not found on PATH; HTTP probes will be skipped."
fi

section "Compose inventory"
run_compose "Compose projects" ls -a
run_compose "Compose services" config --services
run_compose "Compose profiles" config --profiles
run_compose "Compose images" config --images
run_compose "Compose volumes" config --volumes
run_compose "Compose networks" config --networks
run_compose "Compose containers" ps -a

if [ "${#SERVICES[@]}" -gt 0 ]; then
  run_compose_for_services "Compose process tree for selected services" top
else
  run_compose "Compose process tree" top
fi

if [ "$SKIP_STATS" -eq 0 ]; then
  section "Container resources"
  container_ids="$("${compose_base[@]}" ps -q 2>/dev/null || true)"
  if [ -n "$container_ids" ]; then
    printf '\n### docker stats --no-stream\n'
    printf '```text\n'
    # Intentionally split container ids returned by docker compose ps -q.
    docker stats --no-stream $container_ids 2>&1
    status=$?
    if [ "$status" -ne 0 ]; then
      printf '[exit_status=%s]\n' "$status"
    fi
    printf '```\n'
  else
    note "No Compose container IDs found for docker stats."
  fi
fi

if [ "$SKIP_LOGS" -eq 0 ]; then
  section "Recent Compose logs"
  if [ "${#SERVICES[@]}" -gt 0 ]; then
    run_block "Logs for selected services" "${compose_base[@]}" logs --no-color --timestamps --tail "$TAIL" --since "$SINCE" "${SERVICES[@]}"
  else
    run_block "Logs for all services" "${compose_base[@]}" logs --no-color --timestamps --tail "$TAIL" --since "$SINCE"
  fi
fi

if [ "${#URLS[@]}" -gt 0 ] && has curl; then
  section "HTTP probes"
  for url in "${URLS[@]}"; do
    run_block "HTTP probe: $url" curl -sS -L --max-time 20 --connect-timeout 5 -D - -o /dev/null -w '\nurl_effective=%{url_effective}\nhttp_code=%{http_code}\ncontent_type=%{content_type}\ntime_namelookup=%{time_namelookup}\ntime_connect=%{time_connect}\ntime_starttransfer=%{time_starttransfer}\ntime_total=%{time_total}\nredirects=%{num_redirects}\n' "$url"
  done
fi

detect_db_kind() {
  if [ "$DB_KIND" != "auto" ]; then
    printf '%s' "$DB_KIND"
    return 0
  fi

  if [ -n "$DB_SERVICE" ]; then
    if "${compose_base[@]}" exec -T "$DB_SERVICE" sh -lc 'command -v psql >/dev/null 2>&1' >/dev/null 2>&1; then
      printf 'postgres'
      return 0
    fi
    if "${compose_base[@]}" exec -T "$DB_SERVICE" sh -lc 'command -v mysql >/dev/null 2>&1' >/dev/null 2>&1; then
      printf 'mysql'
      return 0
    fi
  fi

  if [ -n "$POSTGRES_URL_ENV" ]; then
    printf 'postgres'
    return 0
  fi

  printf 'unknown'
}

run_postgres_queries() {
  local query_kind="$1"
  local -a psql_base=()

  if [ "$query_kind" = "compose" ]; then
    psql_base=("${compose_base[@]}" exec -T "$DB_SERVICE" psql -X -v ON_ERROR_STOP=0 -P pager=off)
  else
    if ! has psql; then
      note "psql command not found on PATH; skipping PostgreSQL URL probes."
      return 0
    fi
    local conn="${!POSTGRES_URL_ENV:-}"
    if [ -z "$conn" ]; then
      note "Environment variable $POSTGRES_URL_ENV is empty; skipping PostgreSQL URL probes."
      return 0
    fi
    psql_base=(psql -X -v ON_ERROR_STOP=0 -P pager=off)
  fi

  if [ -n "$DB_USER" ]; then
    psql_base+=(-U "$DB_USER")
  fi
  if [ -n "$DB_NAME" ]; then
    psql_base+=(-d "$DB_NAME")
  fi
  if [ "$query_kind" != "compose" ]; then
    psql_base+=("$conn")
  fi

  run_block "PostgreSQL identity" "${psql_base[@]}" -c "select now() as checked_at, version() as version, current_database() as database, current_user as user;"
  run_block "PostgreSQL active sessions" "${psql_base[@]}" -c "select pid, usename, datname, application_name, client_addr, state, wait_event_type, wait_event, now() - xact_start as xact_age, now() - query_start as query_age, left(query, 160) as query from pg_stat_activity where pid <> pg_backend_pid() order by query_start nulls last limit 30;"
  run_block "PostgreSQL locks summary" "${psql_base[@]}" -c "select locktype, mode, granted, count(*) as count from pg_locks group by locktype, mode, granted order by count desc, locktype, mode limit 30;"
  run_block "PostgreSQL table sizes" "${psql_base[@]}" -c "select schemaname, relname, pg_size_pretty(pg_total_relation_size(format('%I.%I', schemaname, relname)::regclass)) as total_size, n_live_tup, n_dead_tup from pg_stat_user_tables order by pg_total_relation_size(format('%I.%I', schemaname, relname)::regclass) desc limit 20;"
  run_block "PostgreSQL migration tables" "${psql_base[@]}" -c "select table_schema, table_name from information_schema.tables where table_schema not in ('pg_catalog', 'information_schema') and table_name ilike '%migration%' order by table_schema, table_name limit 30;"
}

run_mysql_queries() {
  local -a mysql_base=("${compose_base[@]}" exec -T "$DB_SERVICE")
  local mysql_user="${MYSQL_USER:-$DB_USER}"
  local mysql_db="${MYSQL_DATABASE:-$DB_NAME}"

  if [ -n "$MYSQL_PASSWORD_ENV" ]; then
    local mysql_password="${!MYSQL_PASSWORD_ENV:-}"
    if [ -n "$mysql_password" ]; then
      mysql_base+=(env "MYSQL_PWD=$mysql_password")
    else
      note "Environment variable $MYSQL_PASSWORD_ENV is empty; running mysql without MYSQL_PWD."
    fi
  fi

  mysql_base+=(mysql --batch --table)
  if [ -n "$mysql_user" ]; then
    mysql_base+=(-u "$mysql_user")
  fi
  if [ -n "$mysql_db" ]; then
    mysql_base+=("$mysql_db")
  fi

  run_block "MySQL identity" "${mysql_base[@]}" -e "select now() as checked_at, version() as version, database() as db, user() as user;"
  run_block "MySQL processlist" "${mysql_base[@]}" -e "show full processlist;"
  run_block "MySQL status highlights" "${mysql_base[@]}" -e "show global status where Variable_name in ('Threads_connected','Threads_running','Connections','Aborted_connects','Slow_queries','Innodb_row_lock_waits','Innodb_row_lock_time');"
  run_block "MySQL table sizes" "${mysql_base[@]}" -e "select table_schema, table_name, round((data_length + index_length) / 1024 / 1024, 2) as total_mb, table_rows from information_schema.tables where table_schema not in ('mysql','performance_schema','information_schema','sys') order by data_length + index_length desc limit 20;"
}

if [ -n "$DB_SERVICE" ] || [ -n "$POSTGRES_URL_ENV" ]; then
  section "Database snapshot"
  detected_db_kind="$(detect_db_kind)"
  printf '\n[NOTE] detected_db_kind=%s\n' "$detected_db_kind"

  case "$detected_db_kind" in
    postgres)
      if [ -n "$DB_SERVICE" ]; then
        run_postgres_queries compose
      else
        run_postgres_queries url
      fi
      ;;
    mysql)
      if [ -n "$DB_SERVICE" ]; then
        run_mysql_queries
      else
        note "MySQL probes require --db-service."
      fi
      ;;
    *)
      note "Could not detect psql or mysql. Pass --db-kind postgres/mysql and ensure the client exists in --db-service."
      ;;
  esac
fi

section "Interpretation hints"
cat <<'HINTS'
- Container exited or restarting: inspect that service's newest logs before changing code.
- HTTP probe fails on host but succeeds inside Compose network: check port publishing, proxy routing, or localhost binding.
- Browser 4xx/5xx plus app log exception: use the first failing request path and timestamp as the correlation key.
- Many PostgreSQL sessions waiting on Lock or idle in transaction: inspect blocking queries before restarting services.
- Database identity does not match the expected app DB: check Compose env, volumes, and connection strings with secret values redacted.
HINTS
