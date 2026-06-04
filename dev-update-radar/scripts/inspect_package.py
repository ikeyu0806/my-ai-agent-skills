#!/usr/bin/env python3
"""
Read-only package.json scanner for dev-update-radar.

It identifies dependencies related to watched APIs, developer tools, browsers,
and macOS-sensitive tooling. It does not access the network or modify files.
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


DEPENDENCY_FIELDS = (
    "dependencies",
    "devDependencies",
    "peerDependencies",
    "optionalDependencies",
)

LOCKFILES = (
    "package-lock.json",
    "npm-shrinkwrap.json",
    "pnpm-lock.yaml",
    "yarn.lock",
    "bun.lock",
    "bun.lockb",
)


@dataclass(frozen=True)
class Rule:
    target: str
    patterns: tuple[str, ...]
    reason: str


RULES = (
    Rule(
        "Google Ads API",
        (
            "google-ads",
            "googleads",
            "@google-ads/",
            "google-auth-library",
            "googleapis",
        ),
        "Google Ads or Google API client dependency",
    ),
    Rule(
        "Meta API",
        (
            "facebook-nodejs-business-sdk",
            "facebook-business",
            "meta-business",
            "fbgraph",
            "facebook-sdk",
            "instagram-private-api",
            "whatsapp",
        ),
        "Meta Graph, Marketing, Instagram, or WhatsApp API dependency",
    ),
    Rule(
        "Stripe API",
        (
            "stripe",
            "@stripe/",
            "react-stripe-js",
        ),
        "Stripe API, Checkout, Billing, Connect, or frontend SDK dependency",
    ),
    Rule(
        "Auth0",
        (
            "@auth0/",
            "auth0",
            "express-openid-connect",
            "jwks-rsa",
            "openid-client",
        ),
        "Auth0 or OIDC authentication dependency",
    ),
    Rule(
        "Codex",
        (
            "@openai/codex",
            "openai-codex",
        ),
        "Codex CLI or SDK dependency",
    ),
    Rule(
        "Claude Code",
        (
            "@anthropic-ai/claude-code",
            "@anthropic-ai/sdk",
        ),
        "Claude Code or Anthropic SDK dependency",
    ),
    Rule(
        "Chrome",
        (
            "playwright",
            "@playwright/",
            "puppeteer",
            "chromedriver",
            "selenium-webdriver",
            "lighthouse",
            "chrome-launcher",
            "webextension",
        ),
        "Chrome, browser automation, DevTools, or extension dependency",
    ),
    Rule(
        "macOS",
        (
            "electron",
            "electron-builder",
            "electron-forge",
            "node-gyp",
            "fsevents",
            "keytar",
            "sharp",
            "esbuild",
        ),
        "Native, desktop, signing, or macOS-sensitive dependency",
    ),
)


def load_json(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise SystemExit(f"package.json not found: {path}") from None
    except json.JSONDecodeError as exc:
        raise SystemExit(f"invalid JSON in {path}: {exc}") from exc


def find_package_json(start: Path) -> Path:
    candidate = start.resolve()
    if candidate.is_file():
        if candidate.name == "package.json":
            return candidate
        candidate = candidate.parent

    for directory in (candidate, *candidate.parents):
        package_json = directory / "package.json"
        if package_json.exists():
            return package_json
        if (directory / ".git").exists():
            break

    raise SystemExit(f"no package.json found at or above {start}")


def collect_dependencies(package_json: dict[str, Any]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for field in DEPENDENCY_FIELDS:
        deps = package_json.get(field, {})
        if not isinstance(deps, dict):
            continue
        for name, version in sorted(deps.items(), key=lambda item: item[0].lower()):
            rows.append(
                {
                    "field": field,
                    "name": str(name),
                    "version": str(version),
                }
            )
    return rows


def match_rule(package_name: str, rule: Rule) -> bool:
    lowered = package_name.lower()
    for pattern in rule.patterns:
        pattern_lower = pattern.lower()
        if pattern_lower.endswith("/"):
            if lowered.startswith(pattern_lower):
                return True
        elif lowered == pattern_lower or pattern_lower in lowered:
            return True
    return False


def classify_dependencies(dependencies: list[dict[str, str]]) -> list[dict[str, str]]:
    matches: list[dict[str, str]] = []
    seen: set[tuple[str, str, str]] = set()
    for dep in dependencies:
        for rule in RULES:
            if not match_rule(dep["name"], rule):
                continue
            key = (rule.target, dep["field"], dep["name"])
            if key in seen:
                continue
            seen.add(key)
            matches.append(
                {
                    "target": rule.target,
                    "package": dep["name"],
                    "field": dep["field"],
                    "version": dep["version"],
                    "reason": rule.reason,
                }
            )
    return matches


def infer_package_manager(project_dir: Path, package_json: dict[str, Any]) -> dict[str, Any]:
    declared = package_json.get("packageManager")
    lockfiles = [name for name in LOCKFILES if (project_dir / name).exists()]

    inferred = "unknown"
    if declared and isinstance(declared, str):
        inferred = declared.split("@", 1)[0]
    elif "pnpm-lock.yaml" in lockfiles:
        inferred = "pnpm"
    elif "yarn.lock" in lockfiles:
        inferred = "yarn"
    elif "bun.lock" in lockfiles or "bun.lockb" in lockfiles:
        inferred = "bun"
    elif "package-lock.json" in lockfiles or "npm-shrinkwrap.json" in lockfiles:
        inferred = "npm"

    return {
        "declared": declared if isinstance(declared, str) else None,
        "inferred": inferred,
        "lockfiles": lockfiles,
    }


def extract_version_hints(package_json: dict[str, Any]) -> dict[str, Any]:
    hints: dict[str, Any] = {}
    engines = package_json.get("engines")
    if isinstance(engines, dict):
        hints["engines"] = {str(k): str(v) for k, v in sorted(engines.items())}

    browserslist = package_json.get("browserslist")
    if isinstance(browserslist, (list, str, dict)):
        hints["browserslist"] = browserslist

    return hints


def markdown_table(rows: list[list[str]], headers: list[str]) -> str:
    widths = [len(header) for header in headers]
    for row in rows:
        for index, cell in enumerate(row):
            widths[index] = max(widths[index], len(cell))

    def fmt(row: list[str]) -> str:
        return "| " + " | ".join(cell.ljust(widths[index]) for index, cell in enumerate(row)) + " |"

    separator = "| " + " | ".join("-" * width for width in widths) + " |"
    return "\n".join([fmt(headers), separator, *(fmt(row) for row in rows)])


def render_markdown(report: dict[str, Any]) -> str:
    project = report["project"]
    manager = report["package_manager"]
    counts = report["dependency_counts"]
    matches = report["matches"]

    lines = [
        "# Package Update Radar Input",
        "",
        f"- Project: `{project['name']}`",
        f"- Path: `{project['path']}`",
        f"- Package manager: `{manager['declared'] or manager['inferred']}`",
        f"- Lockfiles: {', '.join(f'`{name}`' for name in manager['lockfiles']) if manager['lockfiles'] else 'none found'}",
        f"- Dependencies: {counts['total']} total"
        + "".join(f", {field}={count}" for field, count in counts["by_field"].items()),
    ]

    if report["hints"]:
        lines.extend(["", "## Version Hints"])
        for key, value in report["hints"].items():
            serialized = json.dumps(value, ensure_ascii=False, sort_keys=True)
            lines.append(f"- `{key}`: `{serialized}`")

    lines.extend(["", "## Matched Target Dependencies"])
    if matches:
        table_rows = [
            [
                match["target"],
                match["package"],
                match["field"],
                match["version"],
                match["reason"],
            ]
            for match in matches
        ]
        lines.append(markdown_table(table_rows, ["Target", "Package", "Field", "Version", "Reason"]))
    else:
        lines.append("No watched API/tool/browser/macOS dependencies matched by name.")

    lines.extend(
        [
            "",
            "## Suggested Next Checks",
            "- Browse the official sources for each matched target.",
            "- Compare package ranges with package registry metadata and changelogs.",
            "- Search the codebase for explicit API versions only after a target is matched.",
            "- Confirm whether breaking changes affect actual project usage before recommending code changes.",
        ]
    )

    return "\n".join(lines)


def build_report(path: Path) -> dict[str, Any]:
    package_path = find_package_json(path)
    project_dir = package_path.parent
    package_json = load_json(package_path)
    dependencies = collect_dependencies(package_json)
    matches = classify_dependencies(dependencies)

    by_field: dict[str, int] = {}
    for dep in dependencies:
        by_field[dep["field"]] = by_field.get(dep["field"], 0) + 1

    return {
        "project": {
            "name": str(package_json.get("name") or "(unnamed)"),
            "version": str(package_json.get("version") or ""),
            "path": str(project_dir),
            "package_json": str(package_path),
        },
        "package_manager": infer_package_manager(project_dir, package_json),
        "dependency_counts": {
            "total": len(dependencies),
            "by_field": by_field,
        },
        "hints": extract_version_hints(package_json),
        "matches": matches,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Inspect package.json for watched update targets.")
    parser.add_argument("path", nargs="?", default=".", help="Project path or package.json path")
    parser.add_argument("--json", action="store_true", help="Output JSON instead of Markdown")
    args = parser.parse_args()

    report = build_report(Path(args.path))
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        print(render_markdown(report))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except BrokenPipeError:
        try:
            sys.stdout.close()
        finally:
            raise SystemExit(1)
