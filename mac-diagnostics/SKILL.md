---
name: mac-diagnostics
description: Use when asked to diagnose this Mac's health, storage, CPU, memory, battery, thermal state, heavy processes, listening ports, DNS, routing, Wi-Fi band/channel/DFS/interference, VPN or DNS proxy clues, Google Meet/Zoom call dropouts, slow internet, localhost issues, or general network troubleshooting. This skill gathers read-only system and network snapshots, interprets symptoms, and recommends safe next actions without deleting files or changing settings unless the user explicitly approves.
---

# Mac Diagnostics

## Overview

Use this skill to inspect Mac resource pressure, Wi-Fi quality, and network issues with repeatable, read-only diagnostics. Prefer the bundled scripts over ad hoc command sequences so output is consistent and easy to compare across runs.

## Safety Rules

- Do not delete files, clear caches, kill processes, change DNS, renew DHCP, toggle Wi-Fi, reboot, or run `sudo` unless the user explicitly asks and approves the specific action.
- Start with narrow, read-only checks. Treat cleanup, process termination, and network reconfiguration as follow-up recommendations.
- Avoid broad full-home scans unless the user asks for storage forensics or accepts that it may be slow and reveal filenames.
- If probes fail because the current AI agent sandbox blocks `route`, `networksetup`, `ps`, `dig`, `ping`, or outbound access with errors such as `Operation not permitted` or `AuthorizationCreate() failed`, explain that limitation and request escalation only when the missing evidence is necessary.
- Summarize sensitive local details instead of pasting unnecessary paths, hostnames, or process arguments.

## Diagnostic Workflow

1. Identify the symptom: system slow, storage low, memory pressure, battery drain, heat/fans, internet slow, DNS failing, localhost not reachable, or a specific site/service unreachable.
2. Resolve scripts relative to this skill directory. In this checkout, run local machine health diagnostics with:

```bash
bash mac-diagnostics/scripts/mac_health_snapshot.sh
```

3. For storage-heavy investigations, run the deeper scan only when appropriate:

```bash
bash mac-diagnostics/scripts/mac_health_snapshot.sh --deep
```

4. For network diagnostics, run a targeted probe. Use the domain, host, or URL mentioned by the user when available:

```bash
bash mac-diagnostics/scripts/network_probe.sh apple.com
```

5. For Wi-Fi instability, slow wireless, or video-call symptoms such as Google Meet or Zoom audio dropouts, run the Wi-Fi-specific probe. Use the affected service as the target when known:

```bash
bash mac-diagnostics/scripts/wifi_probe.sh meet.google.com
```

6. Add slower network checks only when basic DNS, ping, and HTTP checks do not explain the issue:

```bash
bash mac-diagnostics/scripts/network_probe.sh example.com --trace --quality
bash mac-diagnostics/scripts/wifi_probe.sh meet.google.com --quality
```

7. If the user provides Option-key Wi-Fi menu screenshots or `system_profiler SPAirPortDataType` output, interpret those before asking for more commands. Extract band, PHY mode, channel, channel width, RSSI/noise, transmit rate, security mode, DFS indicator, nearby channel crowding, DNS resolvers, and tunnel interfaces.
8. Interpret the evidence before recommending actions. Separate confirmed findings from plausible causes.

## Wi-Fi And Video Calls

For Meet/Zoom instability, assess the path in this order:

1. **Wi-Fi link**: prefer 5 GHz or 6 GHz with `802.11ac`/`802.11ax`; treat 2.4 GHz plus `802.11n` as high risk for real-time calls, especially when nearby networks share channels 1, 6, or 11.
2. **Signal quality**: compare RSSI and noise. Strong signal does not rule out interference; use SNR, transmit rate, channel width, and gateway ping together.
3. **Channel behavior**: DFS channels can pause or move after radar detection. If calls drop briefly on 5 GHz DFS channels, recommend testing a non-DFS 5 GHz channel such as 36, 40, 44, or 48 in the router settings.
4. **Local vs upstream**: packet loss or spikes to the default gateway suggest local Wi-Fi/router trouble. Gateway is clean but public IP or target fails suggests ISP, DNS, proxy, VPN, firewall, or service-specific trouble.
5. **Network extensions**: `utun*` interfaces and `127.x` DNS resolvers are clues for VPN, DNS proxy, Private Relay, security software, or local resolvers. Confirm with process hints before naming them as the cause.
6. **Apple AWDL/AirDrop**: active `awdl0` can contribute to periodic Wi-Fi contention on some setups. Recommend AirDrop off as a reversible experiment, not a proven root cause.

Prefer this recommendation order for call dropouts: switch to 5/6 GHz, avoid DFS for tests, disable VPN/DNS proxy experiments with user approval, turn AirDrop receiving off, remove nearby USB 3 hubs or docks, restart browser, then consider router firmware/settings or replacing weak ISP-provided Wi-Fi.

## Output Pattern

Use this structure when reporting results:

- **Status**: one sentence with the most likely cause or "no clear issue found".
- **Findings**: 2-6 bullets with evidence from the command output.
- **Recommended next actions**: safe actions first; ask before destructive or externally visible actions.
- **Residual risk**: mention sandbox limits, missing permissions, or checks that were not run.

## Reference

Read `references/thresholds.md` when interpreting ambiguous CPU, memory, disk, Wi-Fi, or network results.
