---
name: review-anti-patterns
description: Use when asked to review code, pull requests, diffs, schema changes, migrations, SQL, ORM models, or design documents for coding anti-patterns, code smells, database/table design anti-patterns, SQL anti-patterns, maintainability risks, or Japanese requests such as "アンチパターンをチェック", "コードレビュー", "DB設計レビュー", or "テーブル設計レビュー".
---

# Review Anti-Patterns

## Overview

Use this skill to perform an evidence-based review for coding and database anti-patterns. Report only findings that are grounded in the target artifact, with file/line references when available.

Use the bundled references as checklists:

- `references/coding-anti-patterns.md`: naming, control flow, error handling, tests, object design, controller/use-case boundaries, and maintainability smells.
- `references/database-anti-patterns.md`: table design, constraints, types, SQL query risks, security, performance, and operational design smells.

## Review Workflow

1. Identify the review target: current diff, PR, explicit files, schema/migration files, SQL, ORM models, or design docs.
2. Inspect existing project conventions before flagging style issues. Treat a pattern as a finding only when it creates ambiguity, fragility, security risk, correctness risk, or meaningful maintenance cost.
3. Load only the relevant reference file:
   - Load `coding-anti-patterns.md` for application code, tests, controllers, services, or general architecture.
   - Load `database-anti-patterns.md` for migrations, schema definitions, SQL queries, ORM relations, persistence models, indexes, constraints, and data handling.
   - Load both when the change crosses application and persistence boundaries.
4. Search deliberately for likely signals rather than relying on memory:
   - Naming and structure: vague names, numbered variables, oversized functions/classes, duplicate logic, hardcoded settings, fat controllers, excessive arguments.
   - Error and control flow: swallowed exceptions, vague errors, deep nesting, long if/else chains, ignored return values.
   - Tests: missing tests for changed behavior, vague test names, state-dependent tests, broad assertions that hide the real behavior.
   - Database design: missing foreign keys, EAV/metadata tables, polymorphic associations, overused NULL/TEXT/ENUM/FLOAT, comma-separated values, timestamp-split tables.
   - SQL/query behavior: `SELECT *`, string-built SQL, `ORDER BY RAND()`, leading-wildcard `LIKE`, ambiguous `GROUP BY`, N+1 queries, long unreadable queries.
5. For each possible issue, check whether there is a legitimate local reason. Do not force-normalize schemas or split code when the current context makes the trade-off explicit and acceptable.
6. Produce a review-style answer:
   - Findings first, ordered by severity.
   - Include path and line number when available.
   - Explain the specific risk and a concrete fix.
   - Mention when no actionable anti-patterns were found.
   - Include residual test or design gaps only after findings.

## Severity Guidance

- **High**: security exposure, data corruption risk, missing integrity constraints for persisted relationships, SQL injection, plaintext passwords, money/precision errors, or production-scale query hazards.
- **Medium**: maintainability or correctness risks likely to cause bugs, such as fat controllers, missing error handling, N+1 queries, polymorphic associations without constraints, or major normalization issues.
- **Low**: localized readability, naming, duplication, hardcoding, or test clarity issues that are real but unlikely to break behavior immediately.

## Output Rules

- Prefer concise review findings over broad checklists.
- Do not report a generic anti-pattern without pointing to the exact code, schema, query, or design decision.
- Avoid nitpicks that are purely stylistic unless the repository already enforces the convention or the name/structure obscures domain meaning.
- When reviewing Japanese source material or user requests, answer in Japanese unless the surrounding project/request is in English.
