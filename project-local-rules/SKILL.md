---
name: project-local-rules
description: Use when working inside any repository on coding, refactoring, debugging, test changes, database/schema design, migrations, architecture/design docs, implementation plans, reviews, PR feedback, or task execution where project-specific or personal rules may exist in a local rules directory named ikeyu0806. This skill loads relevant per-project coding, design, database, review, testing, directory-structure, and workflow rules from Markdown or Cursor-style .mdc files before acting.
---

# Project Local Rules

## Overview

Use this skill as a loader for private, gitignored project rules. The rules live in the target repository, not in this global skill, so each project can carry its own local coding, design, database, review, testing, and workflow guidance.

Default rules directory discovery:

```text
any directory named ikeyu0806 under the repository root
```

Users do not need to run the loader command manually. When this skill is active, Codex should perform the loading step internally before editing, reviewing, designing, or planning work in the repository.

Cursor-style `.mdc` files are supported anywhere under an `ikeyu0806` rules directory:

```text
docs/ikeyu0806/
  coding.md
  directory_structure.mdc
  database_design.mdc
  testing-implementation.mdc
  backend/zod_schemas.mdc

.codex/ikeyu0806/
  review.md

rules/ikeyu0806/
  architecture.mdc
```

## Core Workflow

1. Find the repository root from the current working directory.
2. Find directories named `ikeyu0806` under that root, preferring `docs/ikeyu0806/` when present.
3. Prune expensive generated trees such as `.git`, `node_modules`, `.next`, `dist`, `build`, `coverage`, `vendor`, and virtualenv/cache directories while searching.
4. If no `ikeyu0806` directory exists, continue normally and mention only when the absence matters.
5. If any exist, inspect the index of available rule files before making code, schema, review, design, or planning decisions.
6. Load only the files relevant to the current task.
7. Apply the local rules together with the repository's existing conventions.
8. If a local rule conflicts with system/developer instructions, the user's explicit request, security constraints, or the existing codebase, surface the conflict before acting.

Use this priority order:

```text
system/developer instructions > explicit user request > project-local rules > existing repository conventions > general preference
```

## Loading Rules

Codex should prefer the bundled script from the repository root or any subdirectory:

```bash
python3 ~/.codex/skills/project-local-rules/scripts/load_project_rules.py --task "short description of the current task"
```

To print relevant rule contents:

```bash
python3 ~/.codex/skills/project-local-rules/scripts/load_project_rules.py --task "review database migration" --dump
```

When target files are known, pass them so Cursor-style `globs` can be applied:

```bash
python3 ~/.codex/skills/project-local-rules/scripts/load_project_rules.py --task "edit campaign API" --file src/app/api/campaigns/route.ts --dump
```

By default the loader searches up to 8 directory levels for directories named `ikeyu0806`. For unusually deep repositories, pass `--max-search-depth N`; for a known location, pass `--rules-dir path/to/ikeyu0806`.

If this skill is checked out somewhere other than `~/.codex/skills`, run the script from that skill directory instead.

Manual fallback:

```bash
git rev-parse --show-toplevel
find . \
  -path './.git' -prune -o \
  -path './node_modules' -prune -o \
  -type d -name ikeyu0806 -print
```

Then read only the relevant files under those directories with `rg --files`, `sed -n`, or another normal file reader.

## Rule File Conventions

Treat these names as signals, not strict requirements:

- `coding.md`, `frontend.md`, `backend.md`, `refactor.md`: implementation and coding style.
- `architecture.md`, `design.md`, `domain.md`, `adr.md`: system design and architectural decisions.
- `directory_structure.md`, `directory_structure.mdc`: file placement and project layout rules.
- `database.md`, `db.md`, `schema.md`, `migration.md`, `sql.md`, `orm.md`: data modeling, migrations, and persistence rules.
- `review.md`, `pr.md`, `anti-patterns.md`: review posture and finding standards.
- `testing.md`, `test.md`, `qa.md`, `e2e.md`: test strategy and verification rules.
- `workflow.md`, `git.md`, `commit.md`, `release.md`: personal workflow, branching, commit, and delivery rules.
- `security.md`, `auth.md`, `privacy.md`: security, authorization, and sensitive-data handling.

Always include obvious index files such as `README.md`, `index.md`, `overview.md`, or `rules.md` when present.

For `.mdc` files, respect simple Cursor frontmatter when present:

```mdc
---
globs: src/app/**/*.ts, prisma/**/*.prisma
alwaysApply: false
---
```

- Load `alwaysApply: true` files for every task.
- Load files whose `globs` match the target files.
- If no frontmatter exists, infer relevance from the file name and path.

## Behavior Rules

- Do not paste private local rules into the final answer unless the user asks for them or a short quote is needed to explain a decision.
- Do not treat gitignored guidance as permission to ignore repository tests, CI, security requirements, or explicit user instructions.
- When editing code, prefer the repository's established implementation patterns after applying any loaded local rules.
- When reviewing code, report findings grounded in the target diff or file; use local review rules only to calibrate severity and scope.
- When rules are ambiguous, make the smallest reasonable interpretation and continue. Ask the user only if the ambiguity could cause meaningful rework or risk.
