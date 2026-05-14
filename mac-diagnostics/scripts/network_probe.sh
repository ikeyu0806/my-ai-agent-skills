#!/usr/bin/env bash
set -u

PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:${PATH:-}"

TARGET="apple.com"
RUN_TRACE=0
RUN_QUALITY=0
PING_COUNT=5

usage() {
  cat <<'USAGE'
Usage: network_probe.sh [target-host-or-url] [--trace] [--quality] [--count N] [--help]

Collect a read-only network diagnostic snapshot: interface summary, default
route, DNS, ping, and HTTP reachability for a target host or URL.

Options:
  --trace      Include traceroute. This can be slow or noisy.
  --quality    Include macOS networkQuality. This can take 15+ seconds.
  --count N    Ping count. Default: 5.
  --help       Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --trace)
      RUN_TRACE=1
      ;;
    --quality)
      RUN_QUALITY=1
      ;;
    --count)
      shift
      if [ "$#" -eq 0 ]; then
        printf '%s\n' '--count requires a value' >&2
        exit 2
      fi
      PING_COUNT="$1"
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
      TARGET="$1"
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

run_limited_block() {
  local title="$1"
  local max_lines="$2"
  shift 2
  printf '\n### %s\n' "$title"
  printf '```text\n'
  "$@" 2>&1 | head -n "$max_lines"
  local status="${PIPESTATUS[0]}"
  if [ "$status" -ne 0 ]; then
    printf '[exit_status=%s]\n' "$status"
  fi
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

if [[ "$TARGET" =~ ^https?:// ]]; then
  URL="$TARGET"
  HOST="$(printf '%s' "$TARGET" | sed -E 's#^[a-zA-Z]+://([^/:]+).*#\1#')"
else
  HOST="${TARGET%%/*}"
  URL="https://${HOST}/"
fi

if [ -z "$HOST" ] || [[ "$HOST" == -* ]]; then
  printf 'Invalid target host: %s\n' "$HOST" >&2
  exit 2
fi

if ! [[ "$PING_COUNT" =~ ^[0-9]+$ ]] || [ "$PING_COUNT" -lt 1 ] || [ "$PING_COUNT" -gt 20 ]; then
  printf 'Invalid ping count: %s\n' "$PING_COUNT" >&2
  exit 2
fi

section "Snapshot"
printf 'timestamp=%s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
printf 'target=%s\n' "$TARGET"
printf 'host=%s\n' "$HOST"
printf 'url=%s\n' "$URL"

section "Local Network State"
if has scutil; then
  run_block "Network information" scutil --nwi
  run_shell "DNS resolvers" "scutil --dns | awk '/nameserver\\[[0-9]+\\]/{print \$3}' | sort -u"
fi
if has ifconfig; then
  run_shell "Interface summary" "ifconfig | awk '/^[a-z0-9]/{iface=\$1} /status: active|inet /{print iface, \$0}' | head -n 80"
fi
if has route; then
  run_block "Default route" route -n get default
fi
if has netstat; then
  run_shell "IPv4 routing table" "netstat -rn -f inet | head -n 40"
fi
if has networksetup; then
  run_block "Hardware ports" networksetup -listallhardwareports
fi

section "Target DNS"
if has dig; then
  run_block "A records" dig +time=2 +tries=1 +short "$HOST" A
  run_block "AAAA records" dig +time=2 +tries=1 +short "$HOST" AAAA
else
  run_block "dscacheutil host lookup" dscacheutil -q host -a name "$HOST"
fi

section "Reachability"
if has ping; then
  run_limited_block "Ping" 80 ping -c "$PING_COUNT" -W 1000 "$HOST"
fi
if has curl; then
  run_block "HTTP HEAD" curl -sS -I -L --connect-timeout 5 --max-time 12 "$URL"
fi

if [ "$RUN_TRACE" -eq 1 ] && has traceroute; then
  section "Route Trace"
  run_block "Traceroute" traceroute -m 12 -w 2 "$HOST"
fi

if [ "$RUN_QUALITY" -eq 1 ] && has networkQuality; then
  section "Network Quality"
  run_block "networkQuality" networkQuality -v
fi

section "Interpretation Notes"
cat <<'NOTES'
- This script does not change network settings.
- DNS success plus HTTP failure suggests proxy, TLS, firewall, VPN, captive portal, or service-side issues.
- Ping or traceroute loss can be blocked by networks; confirm with HTTP and DNS before concluding packet loss.
- If outbound probes fail in Codex but work in a browser, the sandbox may be the cause.
NOTES
