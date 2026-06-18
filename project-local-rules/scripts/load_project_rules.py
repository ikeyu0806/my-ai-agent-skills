#!/usr/bin/env python3
"""Locate and print relevant gitignored project-local rule files."""

from __future__ import annotations

import argparse
import subprocess
import sys
from dataclasses import dataclass
from fnmatch import fnmatch
from pathlib import Path


DEFAULT_RULES_DIRS = (Path("docs/ikeyu0806"), Path(".cursor/rules"))
TEXT_SUFFIXES = {
    ".md",
    ".markdown",
    ".txt",
    ".rst",
    ".adoc",
    ".mdc",
    ".yml",
    ".yaml",
    ".json",
    ".toml",
}
SKIP_DIR_NAMES = {".git", ".venv", "__pycache__", "node_modules", "dist", "build"}

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
        "file",
        "folder",
        "directory",
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
        "directory",
        "folder",
        "layout",
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
    globs: tuple[str, ...]
    always_apply: bool
    glob_match: bool
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


def is_always_name(path: Path) -> bool:
    stem = path.stem.lower()
    if stem in CORE_NAMES:
        return True
    tokens = tokenize(stem)
    return {"directory", "structure"}.issubset(tokens) or {"folder", "structure"}.issubset(tokens)


def categories_for(path: Path) -> tuple[str, ...]:
    if is_always_name(path):
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


def clean_frontmatter_value(value: str) -> str:
    return value.strip().strip("'\"")


def parse_globs(value: str) -> list[str]:
    cleaned = value.strip()
    if not cleaned:
        return []
    if cleaned.startswith("[") and cleaned.endswith("]"):
        cleaned = cleaned[1:-1]
    return [clean_frontmatter_value(item) for item in cleaned.split(",") if clean_frontmatter_value(item)]


def parse_cursor_frontmatter(path: Path) -> tuple[bool, tuple[str, ...]]:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return False, ()

    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return False, ()

    always_apply = False
    globs: list[str] = []
    current_key = ""
    for line in lines[1:]:
        stripped = line.strip()
        if stripped == "---":
            break
        if not stripped or stripped.startswith("#"):
            continue
        if stripped.startswith("-") and current_key == "globs":
            item = clean_frontmatter_value(stripped[1:])
            if item:
                globs.append(item)
            continue
        if ":" not in stripped:
            continue
        key, value = stripped.split(":", 1)
        current_key = key.strip()
        value = value.strip()
        if current_key == "alwaysApply":
            always_apply = value.lower() in {"true", "yes", "1", "on"}
        elif current_key == "globs":
            globs.extend(parse_globs(value))

    return always_apply, tuple(dict.fromkeys(globs))


def pattern_matches(target_file: str, pattern: str) -> bool:
    target = target_file.replace("\\", "/").lstrip("./")
    normalized_pattern = pattern.replace("\\", "/").lstrip("./")
    return fnmatch(target, normalized_pattern) or fnmatch("/" + target, normalized_pattern)


def any_glob_matches(target_files: list[str], globs: tuple[str, ...]) -> bool:
    if not target_files or not globs:
        return False
    return any(pattern_matches(target, pattern) for target in target_files for pattern in globs)


def normalize_target_files(root: Path, target_files: list[str]) -> list[str]:
    normalized = []
    for target_file in target_files:
        target_path = Path(target_file)
        if not target_path.is_absolute():
            normalized.append(target_file)
            continue
        try:
            normalized.append(str(target_path.resolve().relative_to(root)))
        except ValueError:
            normalized.append(target_file)
    return normalized


def score_file(
    relpath: Path,
    categories: tuple[str, ...],
    wanted: set[str],
    always_apply: bool,
    glob_match: bool,
) -> int:
    score = 0
    if is_always_name(relpath):
        score += 100
    if always_apply:
        score += 90
    if glob_match:
        score += 80
    score += 20 * len(set(categories) & wanted)
    if not categories:
        score += 1
    return score


def should_skip(path: Path) -> bool:
    return any(part in SKIP_DIR_NAMES for part in path.parts)


def discover_rules_in_dir(
    root: Path,
    rules_dir: Path,
    task: str,
    target_files: list[str],
    include_all: bool,
) -> list[RuleFile]:
    absolute_rules_dir = rules_dir if rules_dir.is_absolute() else root / rules_dir
    if not absolute_rules_dir.is_dir():
        return []

    normalized_target_files = normalize_target_files(root, target_files)
    wanted = wanted_categories(task, normalized_target_files)
    rules: list[RuleFile] = []
    for path in sorted(absolute_rules_dir.rglob("*")):
        if not path.is_file():
            continue
        if should_skip(path.relative_to(absolute_rules_dir)):
            continue
        if not is_text_file(path):
            continue
        relpath = path.relative_to(root)
        categories = categories_for(path.relative_to(absolute_rules_dir))
        always_apply, globs = parse_cursor_frontmatter(path)
        glob_match = any_glob_matches(normalized_target_files, globs)
        score = score_file(relpath, categories, wanted, always_apply, glob_match)
        if not include_all and wanted and score <= 1:
            continue
        rules.append(
            RuleFile(
                path=path,
                relpath=relpath,
                categories=categories,
                globs=globs,
                always_apply=always_apply,
                glob_match=glob_match,
                score=score,
            )
        )

    return sorted(rules, key=lambda item: (-item.score, str(item.relpath)))


def discover_rules(
    root: Path,
    rules_dirs: list[Path],
    task: str,
    target_files: list[str],
    include_all: bool,
) -> list[RuleFile]:
    rules: list[RuleFile] = []
    seen: set[Path] = set()
    for rules_dir in rules_dirs:
        for rule in discover_rules_in_dir(root, rules_dir, task, target_files, include_all):
            key = rule.path.resolve()
            if key in seen:
                continue
            seen.add(key)
            rules.append(rule)
    return sorted(rules, key=lambda item: (-item.score, str(item.relpath)))


def print_index(root: Path, rules_dirs: list[Path], rules: list[RuleFile]) -> None:
    print(f"repo_root: {root}")
    print("rules_dirs:")
    for rules_dir in rules_dirs:
        print(f"- {rules_dir if rules_dir.is_absolute() else root / rules_dir}")
    if not rules:
        print("rules: none")
        return

    print("rules:")
    for rule in rules:
        categories = ",".join(rule.categories) if rule.categories else "uncategorized"
        flags = []
        if rule.always_apply:
            flags.append("alwaysApply")
        if rule.glob_match:
            flags.append("globMatch")
        if rule.globs:
            flags.append("globs=" + ",".join(rule.globs))
        suffix = f" ({'; '.join(flags)})" if flags else ""
        print(f"- {rule.relpath} [{categories}]{suffix}")


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
        action="append",
        default=None,
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
    parser.add_argument("--all", action="store_true", help="Show all text rules, regardless of task relevance.")
    parser.add_argument("--max-chars", type=int, default=20000, help="Maximum characters to print per file.")
    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    cwd = Path.cwd()
    root = args.root.resolve() if args.root is not None else find_repo_root(cwd)
    rules_dirs = args.rules_dir if args.rules_dir is not None else list(DEFAULT_RULES_DIRS)
    rules = discover_rules(root, rules_dirs, args.task, args.target_files, args.all)
    print_index(root, rules_dirs, rules)
    if args.dump and rules:
        print_dump(rules, max(0, args.max_chars))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
