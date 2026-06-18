---
name: project-local-rules
description: Use when working inside any repository on coding, refactoring, debugging, test changes, database/schema design, migrations, architecture/design docs, implementation plans, reviews, PR feedback, or task execution where project-specific or personal rules may exist in an ignored local rules directory such as docs/ikeyu0806/ or in Cursor-style .cursor/rules/*.mdc files. This skill loads relevant per-project coding, design, database, review, testing, directory-structure, and workflow rules before acting.
---

# Project Local Rules

## Overview

Use this skill as a loader for private, gitignored project rules. The rules live in the target repository, not in this global skill, so each project can carry its own local coding, design, database, review, testing, and workflow guidance.

Default search locations:

```text
docs/ikeyu0806/
.cursor/rules/
```

Users do not need to run the loader command manually. When this skill is active, Codex should perform the loading step internally before editing, reviewing, designing, or planning work in the repository.

Cursor-style `.mdc` files are supported. A project can use either flat files or a Cursor-like nested layout:

```text
docs/ikeyu0806/
  coding.md
  database_design.mdc
  .cursor/
    rules/
      directory_structure.mdc
      testing-implementation.mdc
```

## Core Workflow

1. Find the repository root from the current working directory.
2. Check whether `docs/ikeyu0806/` or `.cursor/rules/` exists under that root.
3. If neither directory exists, continue normally and mention only when the absence matters.
4. If either directory exists, inspect the index of available rule files before making code, schema, review, design, or planning decisions.
5. Load only the files relevant to the current task.
6. Apply the local rules together with the repository's existing conventions.
7. If a local rule conflicts with system/developer instructions, the user's explicit request, security constraints, or the existing codebase, surface the conflict before acting.

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

If this skill is checked out somewhere other than `~/.codex/skills`, run the script from that skill directory instead.

Manual fallback:

```bash
git rev-parse --show-toplevel
rg --files docs/ikeyu0806 .cursor/rules
```

Then read only the relevant files with `sed -n` or another normal file reader.

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
