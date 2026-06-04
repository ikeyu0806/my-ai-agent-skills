---
name: dev-update-radar
description: Use when asked to collect, summarize, monitor, or assess update information for developer APIs, platforms, tools, OS/browser releases, or an npm project. Covers Google Ads API, Meta Graph/Marketing APIs, Stripe API, Auth0, Codex, Claude Code, Ghostty, Chrome, macOS, and package.json-driven dependency impact checks. The skill emphasizes current official sources, dated evidence, breaking changes, deprecations, security updates, migration deadlines, and project-specific action items.
---

# Dev Update Radar

## Overview

Use this skill to gather current update information for APIs, developer tools, browsers, operating systems, and npm projects. Treat this as an evidence workflow: browse current official sources, inspect local project files when available, and classify impact before recommending action.

## Core Rules

- Do not rely on model memory for "latest", "recent", version numbers, deprecation dates, security advisories, prices, limits, or product availability.
- Prefer official vendor sources. Use third-party sources only to discover leads, then verify against official docs, changelogs, release notes, status pages, security advisories, or repositories.
- Include concrete dates for releases, deprecations, sunsets, end-of-life milestones, and security fixes.
- Separate confirmed evidence from inference. If a source is ambiguous or blocked, say what was checked and what remains uncertain.
- Do not print secrets from local files. Read dependency names, versions, package manager metadata, lockfile presence, and relevant non-secret config only.

## Quick Start

For a general update sweep:

1. Read `references/sources.md` and choose only the sections relevant to the user request.
2. Browse the current official sources for each selected target.
3. Read `references/impact-rubric.md` before assigning severity.
4. Report critical changes first, then action items, watch items, and source gaps.

For an npm project:

```bash
python3 dev-update-radar/scripts/inspect_package.py .
```

Then use the script output to focus browsing on matching dependencies and platforms. Read `references/package-managers.md` before running networked package-manager commands such as `npm outdated`.

## Workflow

1. Identify scope:
   - Targets: Google Ads API, Meta API, Stripe API, Auth0, Codex, Claude Code, Ghostty, Chrome, macOS, npm dependencies, or a subset.
   - Time window: latest, since a date, weekly digest, monthly digest, or since the installed/package version.
   - Project context: current directory, package manager, deployed API versions, SDK packages, browser support, OS assumptions.
2. Inspect local project context when relevant:
   - Run `inspect_package.py` from the repository root or pass the project path.
   - Read `package.json`, lockfile presence, `engines`, and package manager declaration.
   - If API versions are configured elsewhere, search narrowly for non-secret version constants such as `Stripe-Version`, Google Ads `vXX`, Graph API `vXX.X`, Auth0 SDK names, or browser targets.
3. Gather updates:
   - Browse official sources from `references/sources.md`.
   - For package dependencies, compare installed ranges with npm metadata, changelog links, GitHub releases, and vendor docs.
   - For APIs, check both release notes and deprecation/sunset or migration pages.
   - For Chrome and macOS, check release notes and security/deprecation channels separately.
4. Classify impact using `references/impact-rubric.md`.
5. Produce a dated report with concrete next actions.

## Output Pattern

Use this order:

- **Critical**: security fixes, active exploitation, hard sunset/EOL inside 60 days, breaking change already effective, auth/payment/ad delivery outage risk.
- **Action Needed**: migration required, major SDK upgrade, API version upgrade, behavior change needing tests, policy or permission review.
- **Watch**: preview/beta features, future deprecations beyond 60 days, docs-only changes, low-risk minor releases.
- **Package Impact**: dependency matches from `package.json`, installed/range version, latest known version, relevant changelog or migration notes.
- **No Action**: checked sources with no relevant changes for the requested scope.
- **Sources Checked**: official URLs with access date and any blocked or inconclusive sources.

Keep recommendations specific:

- Name the affected package, API version, endpoint, browser feature, OS version, or CLI.
- State why it matters to this project.
- Give the smallest next action, such as "upgrade Google Ads API v20 usage before YYYY-MM-DD", "test webhook payloads under Stripe API YYYY-MM-DD.codename", or "pin Chrome CI image until Playwright baseline is updated".

## Recurring Runs

If the user asks to monitor, watch, remind, or run this periodically, create an automation instead of embedding schedule logic in the skill. The automation prompt should invoke this skill, specify the target list, and request a dated impact report.
