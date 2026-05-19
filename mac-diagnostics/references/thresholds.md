# Diagnostic Thresholds

Use these as heuristics, not hard rules. Prefer evidence from multiple signals before calling something the root cause.

## Storage

- Healthy: root/data volume has more than 15% free and more than 50 GB available.
- Warning: less than 15% free or less than 50 GB available.
- Critical: less than 10% free or less than 20 GB available.
- Large cleanup candidates are only candidates. Ask before deleting anything.

## CPU

- Compare load average to logical CPU count from `sysctl hw.ncpu`.
- Sustained load above CPU count usually means the machine is saturated.
- A single process over 100% CPU on macOS can be normal for multi-threaded work, but sustained high CPU plus user-visible slowness is actionable.
- Prefer identifying the process and workload before recommending a kill.

## Memory

- `memory_pressure` reporting "Normal" is generally healthy even when free memory looks low.
- Warning signs: high swap use, compressed memory growth, or `memory_pressure` above roughly 50%.
- Critical signs: repeated app stalls, high swap, and `memory_pressure` "Warn" or "Critical".

## Battery, Power, And Thermal

- High CPU plus battery drain is usually process-driven.
- Sleep blockers in `pmset -g assertions` are only actionable if they match the user's symptom.
- Thermal pressure can explain slow CPU even when no single process looks extreme.

## Network

- DNS failures with successful router/default-route checks point to resolver or upstream DNS issues.
- Packet loss above 1-2% on a short ping is suspicious; any repeated loss to the local router is a local Wi-Fi/router issue.
- Latency to a nearby stable public host above 100 ms may be abnormal on home/office broadband, but depends on location and VPN.
- HTTP failures with DNS and ping success often point to TLS, proxy, firewall, VPN, captive portal, or service-side issues.
- `traceroute` can be noisy; do not over-interpret one blocked hop if the final destination works.

## Wi-Fi And Video Calls

- Healthy video-call Wi-Fi is usually 5 GHz or 6 GHz, `802.11ac`/`802.11ax`, RSSI stronger than about -65 dBm, SNR above about 25 dB, and stable gateway ping with no loss.
- 2.4 GHz with `802.11n` is high risk for Google Meet/Zoom dropouts in crowded environments even when short public pings show 0% loss.
- RSSI guide: stronger than -60 dBm is strong, -60 to -67 dBm is usually usable, -67 to -70 dBm is marginal for real-time calls, and weaker than -70 dBm is poor.
- SNR guide: above 35 dB is excellent, 25-35 dB is good, 20-25 dB is marginal, and below 20 dB is poor. Compute SNR as RSSI minus noise, for example `-52 - (-94) = 42 dB`.
- Transmit rate below roughly 150 Mbps on a modern Mac/router is suspicious for calls; 400+ Mbps on 5 GHz/6 GHz is generally healthy.
- DFS channels can cause brief Wi-Fi pauses or channel moves. For persistent call dropouts on 5 GHz DFS channels, test non-DFS channels 36, 40, 44, or 48 when available in the router region.
- `WPA/WPA2 Personal` or "weak security" is a router age/security clue, not by itself proof of packet loss.
- Multiple `utun*` interfaces are common on Macs. Treat them as evidence only when a matching VPN, security, or DNS proxy process is active or DNS routes through local 127.x resolvers.
