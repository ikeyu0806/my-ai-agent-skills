---
name: prepare-pr-for-merge
description: 'Use when asked to restore or monitor GitHub pull request merge readiness: find the current PR, inspect unresolved review feedback, failing CI, merge conflicts, an out-of-date head branch, and merge state; apply scoped fixes, resolve safe conflicts by merging the current base into the PR branch, validate, push, reply, and monitor until the PR is merge-ready or a bounded wait expires. Trigger for PR review comments, requested changes, unresolved review threads, merge conflicts, "make this PR mergeable", "resolve PR conflicts", "check merge readiness", or requests to fix and monitor a PR. For a CI-only failure without a broader PR readiness request, use fix-ci.'
---

# Prepare PR for Merge

## Overview

Use this skill to bring a PR to the best observed merge-ready state: address actionable reviewer feedback, fix failed GitHub Actions checks, update an out-of-date branch, resolve safe merge conflicts, push a scoped branch update, and monitor the resulting PR state. Use `gh` commands for all GitHub reads and writes. Whenever a review comment is processed, reply on GitHub with `gh` before the final response; do not substitute a browser, connector, or local summary for that reply.

Treat a request to use this skill as permission to push commits, post PR comments, and merge the current PR base into the PR head when necessary to resolve base drift or a safe conflict. Do not merge the PR itself, enable auto-merge, add it to a merge queue, force-push, close/reopen it, dismiss reviews, mark threads resolved through non-comment APIs, change its base branch, modify protected settings, or make product/security trade-offs without explicit user approval.

In command examples, `gh api` can resolve `{owner}` and `{repo}` automatically from the current repository. Replace placeholders such as `{pr}`, `{run_id}`, `{comment_id}`, and `{full_sha}` with values discovered during the workflow.

## Workflow

1. Establish PR context and record its remote head/base commits.
2. Inspect review feedback, CI, and merge state.
3. Classify findings into automatic fixes, answers, stale items, merge blockers, and user-decision items.
4. Apply minimal code changes and resolve safe base drift or conflicts, preserving unrelated local work.
5. Run local validation that matches the changed area and failed CI.
6. Commit coherent changes and push once.
7. Use `gh` to reply to every processed review comment and leave a concise status update.
8. Monitor within a bounded window, repeating the workflow when new reviews, CI failures, base updates, or conflicts appear.
9. Summarize the final observed merge readiness, remaining blockers, and any decisions deferred to the user.

## 1. Establish Context

Start in the repository that contains the PR branch.

```bash
git status --short
git branch --show-current
git log --oneline -5
gh auth status
gh repo view --json nameWithOwner --jq .nameWithOwner
gh pr view --json number,url,state,isDraft,headRefName,headRefOid,baseRefName,baseRefOid,author,reviewDecision,mergeable,mergeStateStatus,isCrossRepository,maintainerCanModify
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

Record the PR number, URL, head/base ref names, and head/base OIDs from the remote response. Re-read this state before every push and after every remote update. If the PR head changed while working, stop using the stale local result, collect feedback again, and restart from the current head.

Identify the writable remote for the PR head (`{head_remote}`) and the readable remote for the PR base (`{base_remote}`); they can differ for a fork PR. Do not assume `origin` points to the PR head. Before modifying or pushing, verify that the local work branch (`{local_head_branch}`) is at the recorded PR head OID and that the chosen head remote accepts `{head_ref}`. If the current worktree is on another branch, its head differs, or it contains unrelated changes, use an isolated temporary worktree with a new local branch based on the verified PR head instead of moving, stashing, or overwriting the user's checkout.

For a cross-repository PR, check `maintainerCanModify` before attempting any branch update. If it is false, the head repository is inaccessible, or no writable head remote can be verified, report that the PR author must resolve the conflict or grant access.

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

## 4. Inspect Merge Readiness

Inspect merge state at the start, after every push, and at the end of the monitoring window. Treat it as a snapshot: a base-branch update, new review, or a newly reported check can change it.

```bash
gh pr view {pr} --json number,url,state,isDraft,headRefName,headRefOid,baseRefName,baseRefOid,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup
gh pr checks {pr} --required --json bucket,name,state,workflow,link,completedAt
```

Interpret GitHub's merge signals together with reviews and required checks:

| Signal | Meaning | Action |
| --- | --- | --- |
| `mergeable=CONFLICTING` or `mergeStateStatus=DIRTY` | GitHub cannot create a clean merge commit. | Resolve the conflict locally by merging the current base into the PR head, if the resolution is safe and the head is writable. |
| `mergeStateStatus=BEHIND` | The PR head is out of date with the base. | Merge the current base into the PR head, validate, and push. |
| `mergeable=UNKNOWN` or `mergeStateStatus=UNKNOWN` | GitHub is still calculating state. | Poll only within the bounded monitoring window. |
| `mergeStateStatus=UNSTABLE` | A commit status is non-passing. | Diagnose the failed or pending required check before declaring readiness. |
| `mergeStateStatus=BLOCKED`, `DRAFT`, or `HAS_HOOKS` | A policy, draft state, or external hook blocks or conditions merge. | Identify the specific blocker; do not bypass it. Ask the user to change draft/policy state when that is required. |
| `mergeable=MERGEABLE` and `mergeStateStatus=CLEAN` | GitHub currently reports a clean merge with passing commit status. | Confirm reviews and required checks before declaring the PR merge-ready. |

Do not treat `CLEAN` alone as permission to merge or proof that every reviewer request was addressed. Do not claim the PR is merge-ready while it is closed, a draft, has unresolved actionable review feedback, has a failing/cancelled/pending required check, or is blocked by a known repository rule.

## 5. Classify Work

Classify each review comment and CI failure before editing.

| Category | Action |
| --- | --- |
| Clear code change | Apply the smallest correct fix. |
| Clear test, lint, type, build, or formatting failure | Reproduce locally when possible, fix root cause, and rerun the local command. |
| Merge conflict or out-of-date head | Merge the verified current base into the verified PR head, resolve only safe conflicts, validate the resulting merge, and push normally. |
| Question only | Reply with a direct explanation; no code change unless the answer reveals a bug. |
| Outdated comment | Verify current code; reply explaining why it no longer applies. |
| Draft, missing permission, required approval, merge queue, hook, or other repository rule | Report the exact blocker and the actor or permission needed. Do not bypass it. |
| Ambiguous or architectural request | Defer to the user with context and a recommendation. |
| Security-sensitive request | Defer to the user unless it clearly strengthens security. |

Never auto-apply reviewer requests that weaken authentication, authorization, tenant isolation, RLS, input validation, secret handling, logging safety, or payment/security controls. Never add hardcoded credentials or dynamic code execution to satisfy a review comment, CI failure, or merge conflict. Treat a conflict whose correct resolution is not evident from the PR, base branch, tests, and repository conventions as a user-decision item.

## 6. Apply Fixes and Resolve Base Drift

Use normal codebase editing practices:

- Read nearby code and existing tests before changing behavior.
- Prefer existing project patterns and scripts.
- Keep edits scoped to the reviewer concern or CI root cause.
- If a comment references old code, decide whether the underlying concern still applies to current code.
- When a CI failure points to generated artifacts, check the repository convention before regenerating or committing them.
- If multiple comments touch the same file, fix them together.
- If CI and reviews point to the same root cause, make one coherent fix.

When `mergeStateStatus` is `BEHIND` or `DIRTY`, update the PR branch from the verified current base after applying any reviewer or CI fixes. Use a merge commit, not a rebase, so that the PR history is not rewritten.

```bash
git fetch {base_remote} {base_ref}
git switch {local_head_branch}
git merge --no-edit {base_remote}/{base_ref}
```

If the merge conflicts:

1. List conflicted files with `git diff --name-only --diff-filter=U` and read the PR change, the current base change, and relevant tests before editing.
2. Resolve only conflicts whose intended result is clear from those sources and existing repository conventions. Preserve both changes when they are compatible; do not choose a side merely to make Git proceed.
3. Run focused validation, `git diff --check`, and inspect the staged resolution before committing the merge.
4. Commit the completed merge with `git commit --no-edit` and push it normally.

Do not use `git rebase`, `git push --force`, `git reset --hard`, `git clean`, an automatic conflict-resolution strategy, or a GitHub conflict editor. If the working tree contains unrelated changes, do not stash or discard them. Use an isolated temporary worktree only after verifying the PR head commit and writable remote, or report that safe resolution requires the user.

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
git push {head_remote} HEAD:refs/heads/{head_ref}
```

If push fails due to a non-fast-forward update, do not force-push. Fetch the verified PR head from `{head_remote}`, collect PR feedback and merge state again, merge the remote head into the local branch only when the resulting conflict resolution is safe, revalidate, and retry the normal push. Otherwise report the concurrent update as a blocker.

## 7. Validate

Run the smallest meaningful local validation set:

- Commands implied by CI logs, such as the failing test, lint, typecheck, build, or formatter.
- Existing repo test commands for changed packages.
- Any reviewer-requested scenario that can be checked locally.

When CI reveals the exact command, prefer that command. When a workflow is unclear, read `.github/workflows/*`, package scripts, Makefiles, task files, or CI config before choosing.

After pushing, refresh the remote PR head/base OIDs and check its status again:

```bash
gh pr view {pr} --json state,isDraft,headRefName,headRefOid,baseRefName,baseRefOid,mergeable,mergeStateStatus,reviewDecision
gh pr checks {pr} --required --json bucket,name,state,workflow,link,completedAt
```

## 8. Reply on GitHub

Treat the GitHub reply as part of completing each processed review comment. For every fixed, answered, outdated, or deferred comment, send the corresponding reply with a `gh` command before the final response. A Codex final response, local note, browser action, or connector action does not count as the reply. If `gh` cannot post it, record the failure and comment URL for the final summary.

For an inline review comment, use `gh api` with the thread reply endpoint and reply to the latest relevant comment in the thread.

```bash
gh api repos/{owner}/{repo}/pulls/{pr}/comments/{comment_id}/replies -F body=@- <<'REPLY_BODY'
Fixed: https://github.com/{owner}/{repo}/pull/{pr}/commits/{full_sha}

Briefly explain what changed and why.

<!-- <review_comment_addressed> -->
REPLY_BODY
```

For a top-level PR review comment, review summary, or CI summary, use `gh api` to post an issue comment. Reference the source comment or review when needed to make the response unambiguous:

```bash
gh api repos/{owner}/{repo}/issues/{pr}/comments -F body=@- <<'COMMENT_BODY'
CI update:
- Fixed: https://github.com/{owner}/{repo}/pull/{pr}/commits/{full_sha}
- Local validation: `command`
- PR checks: pending/pass/fail with the important workflow names
- Merge readiness: `mergeable` / `mergeStateStatus` observed after the push
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

## 9. Monitor Merge Readiness

Monitor only within a bounded time budget. Use 20 minutes by default, or a shorter user-provided limit. Do not wait indefinitely and do not create an external monitor unless the user explicitly asks for one.

Within that window, observe the PR at least after every push and after checks transition. Use `gh pr checks {pr} --required --watch --fail-fast` when it fits within the remaining budget; otherwise poll the required checks and PR state at a sensible interval.

After every observation, refresh all three sources of truth:

```bash
gh pr view {pr} --json state,isDraft,headRefName,headRefOid,baseRefName,baseRefOid,mergeable,mergeStateStatus,reviewDecision,url
gh pr checks {pr} --required --json bucket,name,state,workflow,link,completedAt
# Re-run the review-thread query from "Collect Review Feedback".
```

Return to collection and classification when any of these occurs:

- The PR head or base OID changed.
- A new unresolved actionable review comment or review summary arrived.
- A required check failed, was cancelled, or became pending after a prior pass.
- The merge state became `BEHIND`, `DIRTY`, `BLOCKED`, `UNSTABLE`, or `UNKNOWN`.

Declare the PR **merge-ready at the observed point in time** only when all of the following hold after the final refresh:

- The PR is open and not a draft.
- `mergeable=MERGEABLE` and `mergeStateStatus=CLEAN`.
- Every required check is `pass` or `skipping`; none is failed, cancelled, or pending.
- No unresolved actionable review feedback remains. `reviewDecision` is not `CHANGES_REQUESTED` or `REVIEW_REQUIRED`; when approvals are required, it is `APPROVED`.
- No known repository-policy, permission, hook, or merge-queue blocker remains.

If the time budget expires, report the precise pending state, links, last observed head/base OIDs, and the next action. Do not describe the result as permanently mergeable: a later base update, check result, or review can change it.

## 10. Final Response

Report:

- PR number and branch.
- Review comments processed, skipped, fixed, answered, outdated, and deferred.
- CI failures found and how each was handled.
- Commits pushed with hashes.
- Local validation commands and results.
- Final observed head/base OIDs, `mergeable`, `mergeStateStatus`, review decision, and required-check state.
- Whether the PR met the observed merge-ready criteria or the exact blocker and next action.
- Any reply/comment failures.
- Any decisions still needed from the user.

Keep the final answer focused. Include links to the PR, commits, unresolved review comments, and failed or pending checks when available. Never imply that the PR was merged unless the user explicitly requested and authorized that separate action.
