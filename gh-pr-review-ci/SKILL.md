---
name: gh-pr-review-ci
description: 'Use when asked to handle GitHub pull request review feedback or failing PR CI with the gh CLI: find the current PR, inspect unresolved review comments and review summaries, classify and fix actionable comments, diagnose failed GitHub Actions checks, run relevant local validation, commit, push, and reply on the PR. Trigger for PR review comments, requested changes, unresolved review threads, "handle PR reviews", "address review feedback", failing GitHub CI, red PR checks, GitHub Actions failures, or requests to fix a PR and report back.'
---

# GH PR Review CI

## Overview

Use this skill to turn a PR back to a reviewable state: address actionable reviewer feedback, fix failing GitHub Actions checks, push a scoped branch update, and leave clear replies or PR comments. Prefer `gh` commands for all GitHub reads and writes.

Treat a request to use this skill as permission to push commits and post PR comments for the current PR. Still ask before force-pushing, closing/reopening a PR, dismissing reviews, marking threads resolved through non-comment APIs, changing base branches, modifying protected settings, or making product/security trade-offs.

In command examples, `gh api` can resolve `{owner}` and `{repo}` automatically from the current repository. Replace placeholders such as `{pr}`, `{run_id}`, `{comment_id}`, and `{full_sha}` with values discovered during the workflow.

## Workflow

1. Establish PR context.
2. Inspect review feedback and CI state.
3. Classify findings into automatic fixes, answers, stale items, and user-decision items.
4. Apply minimal code changes, preserving unrelated local work.
5. Run local validation that matches the changed area and failed CI.
6. Commit coherent changes and push once.
7. Reply to review comments and leave a concise CI/status update.
8. Summarize what changed, what passed, what is still pending, and any items deferred to the user.

## 1. Establish Context

Start in the repository that contains the PR branch.

```bash
git status --short
git branch --show-current
git log --oneline -5
gh auth status
gh repo view --json nameWithOwner --jq .nameWithOwner
gh pr view --json number,url,headRefName,baseRefName,headRefOid,author,reviewDecision,state
```

If the user provided a PR number or URL, use it. Otherwise use the PR for the current branch:

```bash
gh pr view --json number --jq .number
```

Stop and tell the user if no PR exists for the branch, `gh` is not authenticated, or the branch is detached. Do not guess the PR number.

Before editing, inspect local changes. Never discard or overwrite changes you did not make. If unrelated changes exist, leave them alone. If a reviewer or CI fix requires touching a file with existing local changes, read the diff first and work with it.

```bash
git diff --stat
git diff -- path/to/file
```

## 2. Collect Review Feedback

Collect both inline review threads and top-level PR comments/reviews. Inline threads are the primary source for code comments; review summaries often contain requested changes that are not attached to a line.

Preferred thread-level query:

```bash
gh api graphql -F owner='{owner}' -F name='{repo}' -F number='{pr}' -f query='
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewDecision
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          path
          line
          originalLine
          diffSide
          isOutdated
          comments(first: 50) {
            nodes {
              databaseId
              url
              body
              createdAt
              author { login }
            }
          }
        }
      }
    }
  }
}'
```

If the PR has more than 100 review threads or more than 50 comments in a thread, paginate the GraphQL query or fall back to the paginated REST comments query.

Fallback REST query for inline review comments:

```bash
gh api repos/{owner}/{repo}/pulls/{pr}/comments --paginate
```

Collect review summaries and top-level PR comments:

```bash
gh pr view {pr} --json reviews,comments,latestReviews,reviewDecision,url
```

Resolve identities for filtering:

```bash
gh pr view {pr} --json author --jq .author.login
gh api user --jq .login
```

Skip feedback that does not need action:

- Threads where `isResolved` is true.
- Comments containing `<!-- <review_comment_addressed> -->`.
- Threads where you already replied after the latest reviewer comment and no newer reviewer comment exists.
- Threads where the PR author already replied with the addressed marker or explicitly confirmed the issue is resolved.
- Bot comments that only report generated metadata and do not request a code or explanation change.

Group unresolved feedback by file path. Read each target file once and address all comments for that file together.

## 3. Collect CI Failures

Always check CI, even if the user only mentioned reviews.

```bash
gh pr checks {pr} --json bucket,completedAt,description,event,link,name,startedAt,state,workflow
```

Classify checks by `bucket`:

- `fail` or `cancel`: investigate.
- `pending`: wait only when useful; otherwise report as pending.
- `pass`, `skipping`: no action unless the reviewer called it out.

Map failing checks to workflow runs. Prefer exact check links when available; otherwise list runs for the PR head branch and head SHA.

```bash
git rev-parse HEAD
gh run list --branch "$(git branch --show-current)" --commit "$(git rev-parse HEAD)" --json databaseId,name,workflowName,headSha,status,conclusion,url -L 50
gh run view {run_id} --json databaseId,url,workflowName,jobs,status,conclusion
gh run view {run_id} --log-failed
```

For CI failures, inspect only enough log context to identify the failing command, file, test, or service. Do not paste secrets, tokens, environment dumps, or private log payloads into PR comments or final summaries.

If a check failure is infrastructure-only, flaky, cancelled by a newer commit, or unrelated to the PR changes, do not invent a code fix. Explain the evidence and rerun failed jobs only when rerun is the smallest correct action:

```bash
gh run rerun {run_id} --failed
```

After pushing a fix, prefer the new CI run triggered by the push over rerunning the old failed run.

## 4. Classify Work

Classify each review comment and CI failure before editing.

| Category | Action |
| --- | --- |
| Clear code change | Apply the smallest correct fix. |
| Clear test, lint, type, build, or formatting failure | Reproduce locally when possible, fix root cause, and rerun the local command. |
| Question only | Reply with a direct explanation; no code change unless the answer reveals a bug. |
| Outdated comment | Verify current code; reply explaining why it no longer applies. |
| Ambiguous or architectural request | Defer to the user with context and a recommendation. |
| Security-sensitive request | Defer to the user unless it clearly strengthens security. |

Never auto-apply reviewer requests that weaken authentication, authorization, tenant isolation, RLS, input validation, secret handling, logging safety, or payment/security controls. Never add hardcoded credentials or dynamic code execution to satisfy a review comment or CI failure.

## 5. Apply Fixes

Use normal codebase editing practices:

- Read nearby code and existing tests before changing behavior.
- Prefer existing project patterns and scripts.
- Keep edits scoped to the reviewer concern or CI root cause.
- If a comment references old code, decide whether the underlying concern still applies to current code.
- When a CI failure points to generated artifacts, check the repository convention before regenerating or committing them.
- If multiple comments touch the same file, fix them together.
- If CI and reviews point to the same root cause, make one coherent fix.

Commit grouping:

- Use one commit per coherent fix or per touched file group.
- Use messages like `fix: handle review feedback for <area>` or `fix: resolve <workflow> CI failure`.
- Do not include unrelated local changes.
- Push once after all local commits are ready.

```bash
git diff --check
git status --short
git add path/to/changed-files
git commit -m "fix: concise summary"
git push
```

If push fails due to non-fast-forward updates, stop and report the situation. Do not force-push unless the user explicitly approves it.

## 6. Validate

Run the smallest meaningful local validation set:

- Commands implied by CI logs, such as the failing test, lint, typecheck, build, or formatter.
- Existing repo test commands for changed packages.
- Any reviewer-requested scenario that can be checked locally.

When CI reveals the exact command, prefer that command. When a workflow is unclear, read `.github/workflows/*`, package scripts, Makefiles, task files, or CI config before choosing.

After pushing, check PR status again:

```bash
gh pr checks {pr} --json bucket,name,state,workflow,link,completedAt
gh pr checks {pr} --watch --fail-fast
```

Do not wait indefinitely. If checks are still running after a reasonable wait, report them as pending with links.

## 7. Reply on GitHub

Reply to every processed inline review comment. Use the thread reply endpoint and reply to the latest relevant comment in the thread.

```bash
gh api repos/{owner}/{repo}/pulls/{pr}/comments/{comment_id}/replies -F body=@- <<'REPLY_BODY'
Fixed: https://github.com/{owner}/{repo}/pull/{pr}/commits/{full_sha}

Briefly explain what changed and why.

<!-- <review_comment_addressed> -->
REPLY_BODY
```

For top-level PR comments or CI summaries, post an issue comment:

```bash
gh api repos/{owner}/{repo}/issues/{pr}/comments -F body=@- <<'COMMENT_BODY'
CI update:
- Fixed: https://github.com/{owner}/{repo}/pull/{pr}/commits/{full_sha}
- Local validation: `command`
- PR checks: pending/pass/fail with the important workflow names
COMMENT_BODY
```

Reply language must match the original reviewer comment when practical. Keep replies concise and factual.

Reply patterns:

- Fixed: include commit link, concise explanation, and `<!-- <review_comment_addressed> -->`.
- No code change: explain why the current code is intentional or already handles the concern.
- Outdated: explain what changed and why the concern no longer applies.
- Deferred: state that the item needs PR author/product/security decision; include the trade-off.
- CI fixed: summarize the failed check, root cause, commit, local validation, and current PR check state.

If a reply API call returns 403 or 404, keep going and include the failed reply in the final summary with the comment URL.

## 8. Final Response

Report:

- PR number and branch.
- Review comments processed, skipped, fixed, answered, outdated, and deferred.
- CI failures found and how each was handled.
- Commits pushed with hashes.
- Local validation commands and results.
- PR check state after push.
- Any reply/comment failures.
- Any decisions still needed from the user.

Keep the final answer focused. Include links to the PR, commits, unresolved review comments, and failed or pending checks when available.
