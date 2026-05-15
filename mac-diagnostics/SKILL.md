---
name: mac-diagnostics
description: Use when asked to diagnose this Mac's health, storage, CPU, memory, battery, thermal state, heavy processes, listening ports, DNS, routing, Wi-Fi, connectivity, slow internet, localhost issues, or general network troubleshooting. This skill gathers read-only system and network snapshots, interprets symptoms, and recommends safe next actions without deleting files or changing settings unless the user explicitly approves.
---

# Mac Diagnostics

## Overview

Use this skill to inspect Mac resource pressure and network issues with repeatable, read-only diagnostics. Prefer the bundled scripts over ad hoc command sequences so output is consistent and easy to compare across runs.

## Safety Rules

- Do not delete files, clear caches, kill processes, change DNS, renew DHCP, toggle Wi-Fi, reboot, or run `sudo` unless the user explicitly asks and approves the specific action.
- Start with narrow, read-only checks. Treat cleanup, process termination, and network reconfiguration as follow-up recommendations.
- Avoid broad full-home scans unless the user asks for storage forensics or accepts that it may be slow and reveal filenames.
- If network probes fail because the current AI agent sandbox blocks outbound access, explain that limitation and request escalation only when the probe is necessary.
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

5. Add slower network checks only when basic DNS, ping, and HTTP checks do not explain the issue:

```bash
bash mac-diagnostics/scripts/network_probe.sh example.com --trace --quality
```

6. Interpret the evidence before recommending actions. Separate confirmed findings from plausible causes.

## Output Pattern

Use this structure when reporting results:

- **Status**: one sentence with the most likely cause or "no clear issue found".
- **Findings**: 2-6 bullets with evidence from the command output.
- **Recommended next actions**: safe actions first; ask before destructive or externally visible actions.
- **Residual risk**: mention sandbox limits, missing permissions, or checks that were not run.

## Reference

Read `references/thresholds.md` when interpreting ambiguous CPU, memory, disk, or network results.
