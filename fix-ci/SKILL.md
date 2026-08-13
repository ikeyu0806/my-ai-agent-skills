---
name: fix-ci
description: 'Use when asked to detect, diagnose, or fix failing GitHub CI or GitHub Actions checks with the gh CLI. Trigger for red CI, failed PR checks, GitHub Actions failures, broken workflows, "fix CI", "why did CI fail", or requests to inspect gh logs, identify the failing command/test/job, make local code fixes, validate, commit, push, and report status.'
---

# Fix CI

## Purpose

Use this skill to diagnose failing GitHub Actions checks with `gh`, identify the smallest root-cause fix, apply it locally, validate it, and report the updated PR or run status.

Treat a request to fix CI as permission to inspect GitHub with `gh` and edit local files. Push commits only when the user asks for CI to be fixed on the PR/branch or explicitly asks to push. Ask before force-pushing, rerunning expensive workflows repeatedly, changing protected branch settings, rotating secrets, modifying production infrastructure, or making security/product trade-offs.

Never paste secrets, tokens, full environment dumps, private URLs, or sensitive log payloads into final answers or PR comments.

## Workflow

1. Establish repository, branch, PR, and authentication context.
2. Collect failing checks and map each failed check to the Actions run/job.
3. Read failed log context until the failed command, test, file, or service is clear.
4. Classify the failure and choose the smallest appropriate fix.
5. Reproduce locally when possible, then edit code using existing project patterns.
6. Run targeted local validation.
7. Commit and push if requested or required for the PR CI to rerun.
8. Re-check GitHub status and summarize failures fixed, validation, and remaining pending or failed checks.

## 1. Establish Context

Start in the repository that owns the CI run.

```bash
git status --short
git branch --show-current
git log --oneline -5
gh auth status
gh repo view --json nameWithOwner --jq .nameWithOwner
```

If the user provided a PR number, PR URL, run URL, or run ID, use it. Otherwise prefer the PR for the current branch:

```bash
gh pr view --json number,url,headRefName,baseRefName,headRefOid,state
```

If there is no PR, inspect workflow runs for the current branch and commit:

```bash
gh run list --branch "$(git branch --show-current)" --commit "$(git rev-parse HEAD)" --json databaseId,name,workflowName,headSha,status,conclusion,url -L 30
```

Stop and tell the user if `gh` is not authenticated, the repository remote cannot be resolved, or there is no identifiable PR/run to inspect. Do not guess run IDs or PR numbers.

Before editing, inspect local changes. Never discard or overwrite changes you did not make.

```bash
git diff --stat
git diff -- path/to/file
```

## 2. Collect CI State

For PR checks:

```bash
gh pr checks {pr} --json bucket,completedAt,description,event,link,name,startedAt,state,workflow
```

Investigate checks with `bucket` values `fail` or `cancel`. Treat `pending` as unresolved unless there is an older failed run for the same head SHA. Ignore `pass` and `skipping` unless the user called them out.

Map failed checks to workflow runs. Prefer exact links from `gh pr checks`; otherwise list runs for the PR head branch and head SHA:

```bash
gh run list --branch "{head_branch}" --commit "{head_sha}" --json databaseId,name,workflowName,headSha,status,conclusion,url -L 50
gh run view {run_id} --json databaseId,url,workflowName,jobs,status,conclusion
```

For non-PR failures, start from the provided run ID/URL or the latest failed run:

```bash
gh run list --json databaseId,name,workflowName,headBranch,headSha,status,conclusion,url,createdAt -L 30
```

## 3. Inspect Logs

Read only enough log context to identify the failure source.

```bash
gh run view {run_id} --log-failed
```

If the failed output is too broad, inspect jobs first and then a specific job:

```bash
gh run view {run_id} --json jobs --jq '.jobs[] | {databaseId,name,status,conclusion,startedAt,completedAt,url}'
gh run view {run_id} --job {job_id} --log
```

When logs point to workflow configuration, read the relevant workflow file:

```bash
rg --files .github/workflows
sed -n '1,220p' .github/workflows/{workflow}.yml
```

When logs reveal a command, prefer reproducing that command locally. If the command depends on CI-only services or secrets, inspect configuration and code paths instead of fabricating credentials.

## 4. Classify Failure

| Failure type | Action |
| --- | --- |
| Test, lint, typecheck, build, or formatting failure | Reproduce locally, fix root cause, rerun the failing command. |
| Snapshot or generated artifact drift | Check repo convention, regenerate only the required artifacts, and include them if the repo commits them. |
| Dependency or lockfile mismatch | Use the repo's package manager and lockfile policy; do not hand-edit lockfiles unless that is the established pattern. |
| Workflow YAML/config error | Fix the workflow or referenced script with the smallest compatible change. |
| Missing secret, permission, quota, external outage, or runner issue | Do not invent a code fix. Explain the evidence and ask for the required operational action. |
| Flaky or cancelled run | Rerun only when evidence supports it and rerun is the smallest correct action. |

Security-sensitive failures need extra care. Do not weaken authentication, authorization, tenant isolation, input validation, secret handling, logging safety, signing, dependency integrity, or payment controls just to make CI pass.

## 5. Apply Fix

Use normal codebase practices:

- Read nearby source, tests, package scripts, Makefiles, and workflow files before editing.
- Prefer existing project patterns over new abstractions.
- Keep edits scoped to the failing check's root cause.
- Preserve unrelated local work.
- If a file already has local edits, read the diff before touching it and work with those changes.
- If multiple failed checks share one root cause, make one coherent fix.

Common command sources:

```bash
rg '"scripts"' package.json
rg --files -g 'package.json' -g 'pnpm-lock.yaml' -g 'yarn.lock' -g 'package-lock.json'
rg --files -g 'Makefile' -g 'justfile' -g 'Taskfile.yml'
```

## 6. Validate

Run the smallest meaningful validation set:

- The exact command that failed in CI, when reproducible.
- A narrower test command for the failing test file or package, when available.
- Typecheck, lint, build, or formatter checks for touched areas.
- `git diff --check` before committing.

If local validation cannot reproduce CI because of unavailable secrets, cloud services, paid services, or runner-only setup, say that explicitly and validate everything that can be checked locally.

## 7. Commit, Push, and Re-check

When the user wants the PR/branch fixed, commit only the relevant files and push.

```bash
git status --short
git add path/to/changed-files
git commit -m "fix: resolve CI failure"
git push
```

If push fails due to non-fast-forward updates, stop and report the situation. Do not force-push without explicit approval.

After pushing, re-check PR CI:

```bash
gh pr checks {pr} --json bucket,name,state,workflow,link,completedAt
gh pr checks {pr} --watch --fail-fast
```

Do not wait indefinitely. If checks are still running after a reasonable wait, report them as pending with links.

For infrastructure-only or flaky failures where rerun is appropriate:

```bash
gh run rerun {run_id} --failed
```

Prefer new CI triggered by a pushed fix over rerunning an old failed run.

## 8. Final Response

Report:

- PR/run and branch inspected.
- Failed checks found and root cause for each important failure.
- Files changed and commit hash, if committed.
- Local validation commands and results.
- Current GitHub check state after fix, including pending or still-failing checks.
- Any operational action or user decision still needed.

Keep the final answer concise. Include PR, run, commit, and failed/pending check links when available.
