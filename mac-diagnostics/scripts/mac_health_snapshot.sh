#!/usr/bin/env bash
set -u

PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:${PATH:-}"

DEEP=0
NO_HOME_SCAN=0

usage() {
  cat <<'USAGE'
Usage: mac_health_snapshot.sh [--deep] [--no-home-scan] [--help]

Collect a read-only snapshot of Mac health: storage, CPU, memory, power,
thermal hints, heavy processes, and listening dev ports.

Options:
  --deep          Include a top-level home directory size scan. This can be slow.
  --no-home-scan Skip common home directory size checks.
  --help         Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --deep)
      DEEP=1
      ;;
    --no-home-scan)
      NO_HOME_SCAN=1
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

has() {
  command -v "$1" >/dev/null 2>&1
}

section() {
  printf '\n## %s\n' "$1"
}

run_block() {
  local title="$1"
  shift
  printf '\n### %s\n' "$title"
  printf '```text\n'
  "$@" 2>&1 || true
  printf '```\n'
}

run_shell() {
  local title="$1"
  shift
  printf '\n### %s\n' "$title"
  printf '```text\n'
  bash -c "$*" 2>&1 || true
  printf '```\n'
}

section "Snapshot"
printf 'timestamp=%s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
if has sw_vers; then
  sw_vers
fi
if has sysctl; then
  model="$(sysctl -n hw.model 2>/dev/null || true)"
  cpu_count="$(sysctl -n hw.ncpu 2>/dev/null || true)"
  mem_bytes="$(sysctl -n hw.memsize 2>/dev/null || printf 0)"
  if [ -n "$model" ]; then
    printf 'model=%s\n' "$model"
  fi
  if [ -n "$cpu_count" ]; then
    printf 'logical_cpu_count=%s\n' "$cpu_count"
  fi
  awk -v bytes="$mem_bytes" 'BEGIN { if (bytes > 0) printf "memory_gb=%.1f\n", bytes / 1024 / 1024 / 1024 }'
fi
if [ "${cpu_count:-}" = "" ] && has getconf; then
  fallback_cpu_count="$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)"
  if [ -n "$fallback_cpu_count" ]; then
    printf 'logical_cpu_count=%s\n' "$fallback_cpu_count"
  fi
fi

section "Storage"
if has df; then
  run_block "Mounted volume usage" df -h / /System/Volumes/Data "$HOME"
fi
if has diskutil; then
  run_shell "APFS/root volume details" "diskutil info / | grep -E 'Device Identifier|File System Personality|Volume Total Space|Free Space|APFS Container Free Space|Purgeable Space' || true"
fi

if [ "$NO_HOME_SCAN" -eq 0 ] && has du; then
  section "Common Home Directory Footprint"
  printf '```text\n'
  common_paths=(
    "$HOME/Desktop"
    "$HOME/Documents"
    "$HOME/Downloads"
    "$HOME/Library/Caches"
    "$HOME/Library/Developer"
    "$HOME/Library/Application Support"
    "$HOME/.Trash"
    "$HOME/.cache"
    "$HOME/.npm"
    "$HOME/.pnpm-store"
    "$HOME/.pyenv"
    "$HOME/.cargo"
    "$HOME/.docker"
  )
  for path in "${common_paths[@]}"; do
    if [ -e "$path" ]; then
      du -sh "$path" 2>/dev/null
    fi
  done | sort -hr
  printf '```\n'
fi

if [ "$DEEP" -eq 1 ] && has du; then
  section "Top-Level Home Directory Footprint"
  printf '```text\n'
  du -sh "$HOME"/* "$HOME"/.[!.]* 2>/dev/null | sort -hr | head -n 30
  printf '```\n'
fi

section "CPU"
if has uptime; then
  run_block "Load averages" uptime
fi
if has ps; then
  run_shell "Top CPU processes" "ps -axo pid,pcpu,pmem,stat,comm | sort -nrk 2 | head -n 16"
fi

section "Memory"
if has memory_pressure; then
  run_block "Memory pressure" memory_pressure
fi
if has vm_stat; then
  run_block "VM statistics" vm_stat
fi
if has ps; then
  run_shell "Top memory processes" "ps -axo pid,pcpu,pmem,rss,stat,comm | sort -nrk 3 | head -n 16"
fi

section "Power And Thermal"
if has pmset; then
  run_block "Battery" pmset -g batt
  run_shell "Thermal state" "pmset -g therm 2>&1 || true"
  run_shell "Power assertions" "pmset -g assertions | head -n 120"
fi

section "Listening Ports"
if has lsof; then
  run_shell "TCP listeners" "lsof -nP -iTCP -sTCP:LISTEN | head -n 60"
fi

section "Interpretation Notes"
cat <<'NOTES'
- This script does not delete files, kill processes, or change settings.
- For thresholds, interpret disk, CPU, memory, and network signals with references/thresholds.md.
- If a section reports permission errors, use the rest of the evidence before asking for elevated access.
NOTES
