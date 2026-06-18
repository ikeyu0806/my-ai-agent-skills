#!/usr/bin/env python3
"""Locate and print relevant gitignored project-local rule files."""

from __future__ import annotations

import argparse
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


DEFAULT_RULES_DIR = Path("docs/ikeyu0806")
TEXT_SUFFIXES = {
    ".md",
    ".markdown",
    ".txt",
    ".rst",
    ".adoc",
    ".yml",
    ".yaml",
    ".json",
    ".toml",
}

CORE_NAMES = {
    "readme",
    "index",
    "overview",
    "rules",
    "local-rules",
    "project-rules",
    "guidelines",
}

CATEGORY_KEYWORDS = {
    "coding": {
        "coding",
        "code",
        "implementation",
        "implement",
        "refactor",
        "frontend",
        "backend",
        "api",
        "bug",
        "change",
        "debug",
        "feature",
        "fix",
        "style",
        "lint",
        "typescript",
        "javascript",
        "python",
        "ruby",
        "go",
    },
    "architecture": {
        "architecture",
        "architectural",
        "design",
        "domain",
        "adr",
        "system",
        "overall",
        "structure",
        "spec",
        "plan",
        "planning",
    },
    "database": {
        "database",
        "db",
        "schema",
        "migration",
        "migrate",
        "sql",
        "orm",
        "model",
        "table",
        "indexes",
        "constraint",
        "postgres",
        "mysql",
    },
    "review": {
        "review",
        "pr",
        "pull-request",
        "feedback",
        "anti-pattern",
        "antipattern",
        "rubric",
        "finding",
        "severity",
    },
    "testing": {
        "testing",
        "test",
        "tests",
        "qa",
        "e2e",
        "playwright",
        "unit",
        "integration",
        "verify",
        "verification",
    },
    "workflow": {
        "workflow",
        "process",
        "git",
        "branch",
        "commit",
        "release",
        "deploy",
        "task",
        "handoff",
    },
    "security": {
        "security",
        "secure",
        "auth",
        "authorization",
        "authentication",
        "privacy",
        "secret",
        "secrets",
        "permission",
    },
    "docs": {
        "docs",
        "documentation",
        "document",
        "readme",
        "specification",
        "manual",
        "guide",
    },
}


@dataclass(frozen=True)
class RuleFile:
    path: Path
    relpath: Path
    categories: tuple[str, ...]
    score: int


def run_git_root(cwd: Path) -> Path | None:
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=str(cwd),
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return None

    root = result.stdout.strip()
    return Path(root).resolve() if root else None


def find_repo_root(cwd: Path) -> Path:
    git_root = run_git_root(cwd)
    if git_root is not None:
        return git_root

    for candidate in (cwd, *cwd.parents):
        if (candidate / ".git").exists():
            return candidate.resolve()

    return cwd.resolve()


def tokenize(value: str) -> set[str]:
    normalized = value.lower()
    for char in "/_.:-":
        normalized = normalized.replace(char, "-")
    tokens = set()
    for part in normalized.replace("\n", " ").split():
        tokens.update(piece for piece in part.split("-") if piece)
    return tokens


def is_text_file(path: Path) -> bool:
    if path.suffix.lower() in TEXT_SUFFIXES:
        return True
    try:
        sample = path.read_bytes()[:2048]
    except OSError:
        return False
    if b"\0" in sample:
        return False
    try:
        sample.decode("utf-8")
    except UnicodeDecodeError:
        return False
    return True


def categories_for(path: Path) -> tuple[str, ...]:
    if path.stem.lower() in CORE_NAMES:
        return ("core",)

    tokens = tokenize(str(path.with_suffix("")))
    categories = []
    for category, keywords in CATEGORY_KEYWORDS.items():
        if tokens & keywords:
            categories.append(category)
    return tuple(categories)


def wanted_categories(task: str, target_files: list[str]) -> set[str]:
    tokens = tokenize(" ".join([task, *target_files]))
    wanted = set()
    for category, keywords in CATEGORY_KEYWORDS.items():
        if tokens & keywords:
            wanted.add(category)
    return wanted


def score_file(relpath: Path, categories: tuple[str, ...], wanted: set[str]) -> int:
    stem = relpath.stem.lower()
    score = 0
    if stem in CORE_NAMES:
        score += 100
    score += 20 * len(set(categories) & wanted)
    if not categories:
        score += 1
    return score


def discover_rules(root: Path, rules_dir: Path, task: str, target_files: list[str]) -> list[RuleFile]:
    absolute_rules_dir = rules_dir if rules_dir.is_absolute() else root / rules_dir
    if not absolute_rules_dir.is_dir():
        return []

    wanted = wanted_categories(task, target_files)
    rules: list[RuleFile] = []
    for path in sorted(absolute_rules_dir.rglob("*")):
        if not path.is_file():
            continue
        if any(part.startswith(".") for part in path.relative_to(absolute_rules_dir).parts):
            continue
        if not is_text_file(path):
            continue
        relpath = path.relative_to(root)
        categories = categories_for(path.relative_to(absolute_rules_dir))
        score = score_file(relpath, categories, wanted)
        if wanted and score <= 1:
            continue
        rules.append(RuleFile(path=path, relpath=relpath, categories=categories, score=score))

    return sorted(rules, key=lambda item: (-item.score, str(item.relpath)))


def print_index(root: Path, rules_dir: Path, rules: list[RuleFile]) -> None:
    print(f"repo_root: {root}")
    print(f"rules_dir: {rules_dir if rules_dir.is_absolute() else root / rules_dir}")
    if not rules:
        print("rules: none")
        return

    print("rules:")
    for rule in rules:
        categories = ",".join(rule.categories) if rule.categories else "uncategorized"
        print(f"- {rule.relpath} [{categories}]")


def print_dump(rules: list[RuleFile], max_chars: int) -> None:
    for rule in rules:
        print()
        print(f"--- {rule.relpath} ---")
        try:
            content = rule.path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            content = rule.path.read_text(errors="replace")
        except OSError as exc:
            print(f"[could not read: {exc}]")
            continue

        if len(content) > max_chars:
            print(content[:max_chars].rstrip())
            print(f"\n[truncated at {max_chars} characters]")
        else:
            print(content.rstrip())


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Locate relevant files in a project's gitignored docs/ikeyu0806 rules directory."
    )
    parser.add_argument("--root", type=Path, default=None, help="Repository root. Defaults to git root from cwd.")
    parser.add_argument(
        "--rules-dir",
        type=Path,
        default=DEFAULT_RULES_DIR,
        help="Rules directory relative to repo root, or an absolute path.",
    )
    parser.add_argument("--task", default="", help="Short description of the current task.")
    parser.add_argument(
        "--file",
        dest="target_files",
        action="append",
        default=[],
        help="Target file path. May be repeated to improve relevance matching.",
    )
    parser.add_argument("--dump", action="store_true", help="Print relevant rule contents after the index.")
    parser.add_argument("--max-chars", type=int, default=20000, help="Maximum characters to print per file.")
    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    cwd = Path.cwd()
    root = args.root.resolve() if args.root is not None else find_repo_root(cwd)
    rules = discover_rules(root, args.rules_dir, args.task, args.target_files)
    print_index(root, args.rules_dir, rules)
    if args.dump and rules:
        print_dump(rules, max(0, args.max_chars))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
