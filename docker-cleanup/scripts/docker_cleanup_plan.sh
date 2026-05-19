#!/usr/bin/env bash
set -u

PROFILE="inspect"
UNTIL="24h"
KEEP_BUILD_CACHE="10GB"
EXECUTE=0
INCLUDE_VOLUMES=0
ALL_VOLUMES=0

usage() {
  cat <<'USAGE'
Usage: docker_cleanup_plan.sh [options]

Inspect Docker usage and print a cleanup plan. Destructive commands are only
run when --execute is provided.

Options:
  --profile NAME          inspect, safe, standard, or aggressive. Default: inspect.
  --until DURATION        Age filter for prune commands. Default: 24h.
  --keep-build-cache SIZE Storage to preserve for docker builder prune. Default: 10GB.
  --include-volumes       Include docker volume prune in standard/aggressive profiles.
  --all-volumes           Include named unused volumes too, using docker volume prune -a.
  --execute               Run destructive commands after printing them.
  --help                  Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --profile)
      shift
      if [ "$#" -eq 0 ]; then
        printf '%s\n' '--profile requires a value' >&2
        exit 2
      fi
      PROFILE="$1"
      ;;
    --until)
      shift
      if [ "$#" -eq 0 ]; then
        printf '%s\n' '--until requires a value' >&2
        exit 2
      fi
      UNTIL="$1"
      ;;
    --keep-build-cache)
      shift
      if [ "$#" -eq 0 ]; then
        printf '%s\n' '--keep-build-cache requires a value' >&2
        exit 2
      fi
      KEEP_BUILD_CACHE="$1"
      ;;
    --include-volumes)
      INCLUDE_VOLUMES=1
      ;;
    --all-volumes)
      INCLUDE_VOLUMES=1
      ALL_VOLUMES=1
      ;;
    --execute)
      EXECUTE=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

case "$PROFILE" in
  inspect|safe|standard|aggressive) ;;
  *)
    printf 'Unknown profile: %s\n\n' "$PROFILE" >&2
    usage >&2
    exit 2
    ;;
esac

print_cmd() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
}

run_readonly() {
  print_cmd "$@"
  "$@" || printf '[warn] command failed: %s\n' "$*" >&2
}

plan_or_run() {
  print_cmd "$@"
  if [ "$EXECUTE" -eq 1 ]; then
    "$@"
  fi
}

section() {
  printf '\n## %s\n' "$1"
}

if ! command -v docker >/dev/null 2>&1; then
  printf '%s\n' 'docker command not found in PATH' >&2
  exit 127
fi

section "Docker availability"
run_readonly docker version --format 'Client={{.Client.Version}} Server={{.Server.Version}}'

section "Usage overview"
run_readonly docker system df -v

section "Containers"
run_readonly docker ps -a --size --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}\t{{.Image}}'

section "Volumes"
run_readonly docker volume ls

section "Networks"
run_readonly docker network ls

section "Build cache"
if docker builder du >/dev/null 2>&1; then
  run_readonly docker builder du
else
  printf '%s\n' '[warn] docker builder du is unavailable or failed'
fi

if docker buildx version >/dev/null 2>&1; then
  run_readonly docker buildx du
fi

if [ "$PROFILE" = "inspect" ]; then
  exit 0
fi

section "Cleanup plan"
printf 'profile=%s until=%s include_volumes=%s all_volumes=%s execute=%s\n' \
  "$PROFILE" "$UNTIL" "$INCLUDE_VOLUMES" "$ALL_VOLUMES" "$EXECUTE"

case "$PROFILE" in
  safe)
    plan_or_run docker container prune -f --filter "until=$UNTIL"
    plan_or_run docker network prune -f --filter "until=$UNTIL"
    plan_or_run docker image prune -f --filter "until=$UNTIL"
    plan_or_run docker builder prune -f --filter "until=$UNTIL" --keep-storage "$KEEP_BUILD_CACHE"
    ;;
  standard)
    plan_or_run docker system prune -f --filter "until=$UNTIL"
    plan_or_run docker builder prune -f --filter "until=$UNTIL" --keep-storage "$KEEP_BUILD_CACHE"
    ;;
  aggressive)
    plan_or_run docker system prune -a -f --filter "until=$UNTIL"
    plan_or_run docker builder prune -a -f --filter "until=$UNTIL" --keep-storage "$KEEP_BUILD_CACHE"
    ;;
esac

if [ "$INCLUDE_VOLUMES" -eq 1 ]; then
  if [ "$ALL_VOLUMES" -eq 1 ]; then
    plan_or_run docker volume prune -a -f
  else
    plan_or_run docker volume prune -f
  fi
fi

if [ "$EXECUTE" -eq 0 ]; then
  printf '\n%s\n' 'Dry run only. Re-run with --execute after the cleanup scope is approved.'
fi
