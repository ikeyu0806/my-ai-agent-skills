---
name: project-local-rules
description: Use when working inside any repository on coding, refactoring, debugging, test changes, database/schema design, migrations, architecture/design docs, implementation plans, reviews, PR feedback, or task execution where project-specific or personal rules may exist in an ignored local rules directory such as docs/ikeyu0806/. This skill loads relevant per-project coding, design, database, review, testing, and workflow rules before acting.
---

# Project Local Rules

## Overview

Use this skill as a loader for private, gitignored project rules. The rules live in the target repository, not in this global skill, so each project can carry its own local coding, design, database, review, testing, and workflow guidance.

Default rules directory:

```text
docs/ikeyu0806/
```

## Core Workflow

1. Find the repository root from the current working directory.
2. Check whether `docs/ikeyu0806/` exists under that root.
3. If the directory does not exist, continue normally and mention only when the absence matters.
4. If it exists, inspect the index of available rule files before making code, schema, review, design, or planning decisions.
5. Load only the files relevant to the current task.
6. Apply the local rules together with the repository's existing conventions.
7. If a local rule conflicts with system/developer instructions, the user's explicit request, security constraints, or the existing codebase, surface the conflict before acting.

Use this priority order:

```text
system/developer instructions > explicit user request > project-local rules > existing repository conventions > general preference
```

## Loading Rules

Prefer the bundled script from the repository root or any subdirectory:

```bash
python3 ~/.codex/skills/project-local-rules/scripts/load_project_rules.py --task "short description of the current task"
```

To print relevant rule contents:

```bash
python3 ~/.codex/skills/project-local-rules/scripts/load_project_rules.py --task "review database migration" --dump
```

If this skill is checked out somewhere other than `~/.codex/skills`, run the script from that skill directory instead.

Manual fallback:

```bash
git rev-parse --show-toplevel
rg --files docs/ikeyu0806
```

Then read only the relevant files with `sed -n` or another normal file reader.

## Rule File Conventions

Treat these names as signals, not strict requirements:

- `coding.md`, `frontend.md`, `backend.md`, `refactor.md`: implementation and coding style.
- `architecture.md`, `design.md`, `domain.md`, `adr.md`: system design and architectural decisions.
- `database.md`, `db.md`, `schema.md`, `migration.md`, `sql.md`, `orm.md`: data modeling, migrations, and persistence rules.
- `review.md`, `pr.md`, `anti-patterns.md`: review posture and finding standards.
- `testing.md`, `test.md`, `qa.md`, `e2e.md`: test strategy and verification rules.
- `workflow.md`, `git.md`, `commit.md`, `release.md`: personal workflow, branching, commit, and delivery rules.
- `security.md`, `auth.md`, `privacy.md`: security, authorization, and sensitive-data handling.

Always include obvious index files such as `README.md`, `index.md`, `overview.md`, or `rules.md` when present.

## Behavior Rules

- Do not paste private local rules into the final answer unless the user asks for them or a short quote is needed to explain a decision.
- Do not treat gitignored guidance as permission to ignore repository tests, CI, security requirements, or explicit user instructions.
- When editing code, prefer the repository's established implementation patterns after applying any loaded local rules.
- When reviewing code, report findings grounded in the target diff or file; use local review rules only to calibrate severity and scope.
- When rules are ambiguous, make the smallest reasonable interpretation and continue. Ask the user only if the ambiguity could cause meaningful rework or risk.
