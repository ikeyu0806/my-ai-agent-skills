#!/usr/bin/env bash
set -u

PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:${PATH:-}"

TARGET="meet.google.com"
RUN_TRACE=0
RUN_QUALITY=0
PING_COUNT=5

usage() {
  cat <<'USAGE'
Usage: wifi_probe.sh [target-host-or-url] [--trace] [--quality] [--count N] [--help]

Collect a read-only Wi-Fi diagnostic snapshot for video-call or unstable
wireless symptoms. The output redacts SSIDs, BSSIDs, and MAC addresses.

Options:
  --trace      Include traceroute to the target. This can be slow or noisy.
  --quality    Include macOS networkQuality. This can take 15+ seconds.
  --count N    Ping count for gateway, public IP, and target. Default: 5.
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

sanitize_wifi_output() {
  sed -E \
    -e 's/^([[:space:]]*SSID: ).*/\1<redacted>/' \
    -e 's/^([[:space:]]*BSSID: ).*/\1<redacted>/' \
    -e 's/^([[:space:]]*Current Wi-Fi Network: ).*/\1<redacted>/' \
    -e 's/^([[:space:]]*MAC Address: ).*/\1<redacted>/' \
    -e 's/(ether )[0-9a-fA-F:]+/\1<redacted>/' \
    -e 's/^([[:space:]]{12,})[^:]+:$/\1<network>:/'
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
  if [ "$status" -ne 0 ] && [ "$status" -ne 141 ]; then
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

run_sanitized_block() {
  local title="$1"
  shift
  printf '\n### %s\n' "$title"
  printf '```text\n'
  "$@" 2>&1 | sanitize_wifi_output || true
  printf '```\n'
}

run_sanitized_shell() {
  local title="$1"
  shift
  printf '\n### %s\n' "$title"
  printf '```text\n'
  bash -c "$*" 2>&1 | sanitize_wifi_output || true
  printf '```\n'
}

run_sanitized_limited_block() {
  local title="$1"
  local max_lines="$2"
  shift 2
  printf '\n### %s\n' "$title"
  printf '```text\n'
  "$@" 2>&1 | sanitize_wifi_output | head -n "$max_lines"
  local status="${PIPESTATUS[0]}"
  if [ "$status" -ne 0 ] && [ "$status" -ne 141 ]; then
    printf '[exit_status=%s]\n' "$status"
  fi
  printf '```\n'
}

find_wifi_device() {
  if has networksetup; then
    networksetup -listallhardwareports 2>/dev/null | awk '
      /Hardware Port: Wi-Fi|Hardware Port: AirPort/ {
        getline
        sub(/^Device: /, "")
        print
        exit
      }
    '
  fi
}

find_airport_tool() {
  local candidate
  for candidate in \
    "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport" \
    "/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return
    fi
  done
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

WIFI_DEVICE="$(find_wifi_device)"
AIRPORT_TOOL="$(find_airport_tool)"
DEFAULT_GATEWAY="$(route -n get default 2>/dev/null | awk '/gateway:/{print $2; exit}' || true)"

section "Snapshot"
printf 'timestamp=%s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
printf 'target=%s\n' "$TARGET"
printf 'host=%s\n' "$HOST"
printf 'url=%s\n' "$URL"
if [ -n "$WIFI_DEVICE" ]; then
  printf 'wifi_device=%s\n' "$WIFI_DEVICE"
fi
if [ -n "$DEFAULT_GATEWAY" ]; then
  printf 'default_gateway=%s\n' "$DEFAULT_GATEWAY"
fi

section "Wi-Fi Link"
if [ -n "$WIFI_DEVICE" ] && has networksetup; then
  run_sanitized_block "Wi-Fi power" networksetup -getairportpower "$WIFI_DEVICE"
  run_sanitized_block "Current network" networksetup -getairportnetwork "$WIFI_DEVICE"
fi
if [ -n "$WIFI_DEVICE" ] && has ipconfig; then
  run_block "Wi-Fi IPv4 address" ipconfig getifaddr "$WIFI_DEVICE"
fi
if [ -n "$AIRPORT_TOOL" ]; then
  run_sanitized_block "Airport link details" "$AIRPORT_TOOL" -I
fi
if has system_profiler; then
  run_sanitized_limited_block "System profiler Wi-Fi details" 260 system_profiler SPAirPortDataType
fi

section "Local Network State"
if has route; then
  run_block "Default route" route -n get default
fi
if has scutil; then
  run_shell "DNS resolvers" "scutil --dns | awk '/nameserver\\[[0-9]+\\]/{print \$3}' | sort -u"
fi
if has networksetup; then
  run_block "Network services" networksetup -listallnetworkservices
fi
if has ifconfig; then
  run_sanitized_shell "Tunnel interfaces" "ifconfig | awk '/^utun[0-9]+:/{print; getline; if (\$0 ~ /inet|inet6/) print \"  \" \$0}'"
  run_sanitized_limited_block "AWDL interface" 40 ifconfig awdl0
fi
if has ps; then
  run_shell "VPN and DNS proxy process hints" "ps -axo pid,comm | egrep -i '([w]arp|[t]ailscale|[z]scaler|[o]penvpn|[w]ireguard|[g]lobalprotect|[a]nyconnect|[c]loudflared|[n]extdns|[d]nscrypt|[m]ullvad|[p]rotonvpn|[c]isco)' || true"
fi

section "DNS"
if has dig; then
  run_block "Target A records" dig +time=2 +tries=1 +short "$HOST" A
  run_block "Target AAAA records" dig +time=2 +tries=1 +short "$HOST" AAAA
else
  run_block "Target host lookup" dscacheutil -q host -a name "$HOST"
fi

section "Reachability"
if has ping && [ -n "$DEFAULT_GATEWAY" ]; then
  run_limited_block "Ping default gateway" 40 ping -c "$PING_COUNT" -W 1000 "$DEFAULT_GATEWAY"
fi
if has ping; then
  run_limited_block "Ping public IP 8.8.8.8" 40 ping -c "$PING_COUNT" -W 1000 8.8.8.8
  run_limited_block "Ping target" 40 ping -c "$PING_COUNT" -W 1000 "$HOST"
fi
if has curl; then
  run_block "HTTP HEAD target" curl -sS -I -L --connect-timeout 5 --max-time 12 "$URL"
fi

if [ "$RUN_TRACE" -eq 1 ] && has traceroute; then
  section "Route Trace"
  run_block "Traceroute target" traceroute -m 12 -w 2 "$HOST"
fi

if [ "$RUN_QUALITY" -eq 1 ] && has networkQuality; then
  section "Network Quality"
  run_block "networkQuality" networkQuality -v
fi

section "Interpretation Notes"
cat <<'NOTES'
- This script does not change Wi-Fi, DNS, VPN, AirDrop, or router settings.
- For video-call dropouts, compare gateway ping, public-IP ping, DNS, and HTTP. Gateway loss points to local Wi-Fi/router; public-IP or target-only failure points upstream.
- Prefer 5 GHz or 6 GHz with 802.11ac/ax for Meet/Zoom. 2.4 GHz plus 802.11n is high risk in crowded homes/offices.
- DFS 5 GHz channels can briefly pause or move when radar is detected. For real-time calls, test a non-DFS 5 GHz channel such as 36, 40, 44, or 48 when the router supports it.
- Multiple utun interfaces or 127.x DNS resolvers are clues, not proof. Confirm with VPN/DNS proxy processes and the user's active apps before assigning root cause.
NOTES
