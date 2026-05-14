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
