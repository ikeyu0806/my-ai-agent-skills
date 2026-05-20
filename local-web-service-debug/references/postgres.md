# PostgreSQL Debug Reference

Use these queries for local or development PostgreSQL debugging. Keep production/shared environments read-only, bounded, and approved by the user before connecting.

## Connection Identity

```sql
select
  now() as checked_at,
  version() as version,
  current_database() as database,
  current_user as user,
  inet_server_addr() as server_addr,
  inet_server_port() as server_port;
```

## Active Sessions

Use this when requests hang, the app reports pool exhaustion, or the service is slow.

```sql
select
  pid,
  usename,
  datname,
  application_name,
  client_addr,
  state,
  wait_event_type,
  wait_event,
  now() - xact_start as xact_age,
  now() - query_start as query_age,
  left(query, 240) as query
from pg_stat_activity
where pid <> pg_backend_pid()
order by query_start nulls last
limit 50;
```

Signals:

- Many `idle in transaction` rows: app code opened a transaction and did not close it.
- Many active rows waiting on `Lock`: inspect blocking queries.
- Connection count near pool/database limit: lower app pool size, close leaked clients, or raise limits after confirming cause.

## Blocking Locks

```sql
select
  blocked.pid as blocked_pid,
  blocked.usename as blocked_user,
  now() - blocked.query_start as blocked_age,
  left(blocked.query, 180) as blocked_query,
  blocking.pid as blocking_pid,
  blocking.usename as blocking_user,
  now() - blocking.query_start as blocking_age,
  left(blocking.query, 180) as blocking_query
from pg_catalog.pg_locks blocked_locks
join pg_catalog.pg_stat_activity blocked
  on blocked.pid = blocked_locks.pid
join pg_catalog.pg_locks blocking_locks
  on blocking_locks.locktype = blocked_locks.locktype
 and blocking_locks.database is not distinct from blocked_locks.database
 and blocking_locks.relation is not distinct from blocked_locks.relation
 and blocking_locks.page is not distinct from blocked_locks.page
 and blocking_locks.tuple is not distinct from blocked_locks.tuple
 and blocking_locks.virtualxid is not distinct from blocked_locks.virtualxid
 and blocking_locks.transactionid is not distinct from blocked_locks.transactionid
 and blocking_locks.classid is not distinct from blocked_locks.classid
 and blocking_locks.objid is not distinct from blocked_locks.objid
 and blocking_locks.objsubid is not distinct from blocked_locks.objsubid
 and blocking_locks.pid <> blocked_locks.pid
join pg_catalog.pg_stat_activity blocking
  on blocking.pid = blocking_locks.pid
where not blocked_locks.granted
  and blocking_locks.granted
order by blocked.query_start nulls last
limit 50;
```

## Table Sizes

```sql
select
  schemaname,
  relname,
  pg_size_pretty(pg_total_relation_size(format('%I.%I', schemaname, relname)::regclass)) as total_size,
  pg_size_pretty(pg_relation_size(format('%I.%I', schemaname, relname)::regclass)) as table_size,
  n_live_tup,
  n_dead_tup
from pg_stat_user_tables
order by pg_total_relation_size(format('%I.%I', schemaname, relname)::regclass) desc
limit 30;
```

## Migration State

Adapt table names to the framework:

```sql
select * from _prisma_migrations order by finished_at desc nulls first, started_at desc limit 20;
select * from schema_migrations order by version desc limit 20;
select * from knex_migrations order by migration_time desc limit 20;
select * from django_migrations order by applied desc limit 20;
```

If the migration table does not exist, list likely migration tables:

```sql
select table_schema, table_name
from information_schema.tables
where table_schema not in ('pg_catalog', 'information_schema')
  and table_name ilike '%migration%'
order by table_schema, table_name
limit 50;
```

## Index And Sequential Scan Signals

```sql
select
  schemaname,
  relname,
  seq_scan,
  seq_tup_read,
  idx_scan,
  n_live_tup
from pg_stat_user_tables
where n_live_tup > 1000
order by seq_tup_read desc
limit 30;
```

High sequential reads are not always bad. Confirm with the specific slow query and `EXPLAIN (ANALYZE, BUFFERS)` only when it is safe to execute on the target data volume.

## Connection Limits

```sql
select count(*) as current_connections from pg_stat_activity;

select
  datname,
  numbackends,
  xact_commit,
  xact_rollback,
  blks_read,
  blks_hit,
  deadlocks
from pg_stat_database
where datname = current_database();

show max_connections;
```

## Extension Availability

```sql
select extname, extversion from pg_extension order by extname;
```

If an app fails at startup with missing function/operator errors, compare extensions against migrations and local setup docs.
