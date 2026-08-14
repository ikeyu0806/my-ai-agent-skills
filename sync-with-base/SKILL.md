---
name: sync-with-base
description: 'Use when asked to update the current Git feature branch from the latest main, master, develop, PR base, or another base branch and resolve merge or rebase conflicts. Trigger for "sync with main", "bring in latest main", "update from base", "rebase onto main", "merge main", conflict resolution after fetching the base branch, or requests to refresh a PR branch without losing either side''s intended changes.'
---

# Sync with Base

Update the current feature branch from its latest base branch, resolve conflicts semantically, validate the result, and preserve a recoverable Git history.

## Invocation Input

Treat the following host-supplied command arguments as the user's requested base branch, remote, or strategy when present:

```text
$ARGUMENTS
```

If the host leaves the placeholder unexpanded or no value was supplied, resolve the request from the surrounding user prompt and repository context.

## Safety Contract

- Inspect the repository and working tree before mutating Git state.
- Preserve unrelated user changes. Never discard, overwrite, or auto-stash them.
- Never use `git reset --hard`, `git checkout -- <path>`, `git clean`, or plain `git push --force`.
- Do not resolve conflicts by blindly choosing `ours` or `theirs`; their meanings differ between merge and rebase.
- After successful validation, automatically push only a fast-forward update to the current branch's configured upstream. Do not create a new remote branch or push to an inferred destination.
- Require explicit approval before rewriting a published branch with `git push --force-with-lease`.
- Stop for user direction when a conflict requires a product, data, security, or architectural decision that repository evidence cannot resolve.

## Workflow

### 1. Establish Context

Run read-only checks first:

```bash
git status --short --branch
git branch --show-current
git remote -v
git log --oneline --decorate -10
git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}'
```

Confirm that the repository is not in the middle of another merge, rebase, cherry-pick, or revert. If the worktree contains tracked or untracked changes, do not start the sync and do not stash them automatically. Report the blocking paths and ask the user to commit, stash, or otherwise handle them.

Record the starting branch and commit so the result remains auditable:

```bash
git rev-parse --verify HEAD
```

Stop if HEAD is detached or the current branch is itself the selected base branch unless the user explicitly requested a different operation.

### 2. Resolve the Base and Remote

Choose the base branch in this order:

1. Use the branch explicitly named by the user or passed as an argument.
2. Use the current pull request's base branch when `gh pr view --json baseRefName` succeeds.
3. Use the remote default branch reported by `refs/remotes/<remote>/HEAD`.
4. If none can be established unambiguously, ask the user; do not guess between `main`, `master`, or `develop`.

Use an explicitly named remote when provided. Otherwise prefer the remote associated with the PR, then `origin` when it exists, then the only configured remote. Ask when multiple plausible remotes remain.

Fetch without changing the worktree:

```bash
git fetch --prune <remote>
git rev-parse --verify <remote>/<base>
```

Summarize the commits unique to each side before integrating:

```bash
git log --oneline --left-right --cherry-pick <remote>/<base>...HEAD
```

### 3. Select Merge or Rebase

Use the strategy explicitly requested by the user. Otherwise inspect `AGENTS.md`, `CLAUDE.md`, contribution docs, repository scripts, and recent history for an established policy.

When no policy is available:

- Prefer merge for a branch that is already published or shared because it does not rewrite existing commits.
- Prefer rebase for a clearly local, unpublished branch when a linear history is customary.
- Ask the user when publication state or intent is uncertain.

Run one integration strategy only:

```bash
git merge --no-edit <remote>/<base>
```

or:

```bash
git rebase <remote>/<base>
```

### 4. Resolve Conflicts

List the unresolved paths and inspect the surrounding repository context:

```bash
git status --short
git diff --name-only --diff-filter=U
git ls-files -u
```

For every conflicted path:

1. Read the conflict markers, nearby code, related tests, and both branches' relevant commits.
2. Determine the behavioral intent of the base change and the feature change.
3. Produce the smallest coherent result that preserves both compatible intents.
4. Follow repository conventions for generated files, migrations, lockfiles, renames, and delete/modify conflicts. Regenerate artifacts with the repository's normal tool when appropriate instead of hand-merging generated output.
5. Remove all conflict markers and stage only the resolved path.

During a rebase, remember that conflict-side labels can appear reversed from the feature developer's intuition. Use commit history and stage contents such as `git show :1:<path>`, `git show :2:<path>`, and `git show :3:<path>` only after confirming what each stage represents for the active operation.

Continue the active operation after each conflict set:

```bash
git merge --continue
```

or:

```bash
git rebase --continue
```

Repeat until Git reports completion. If evidence is insufficient for a safe resolution, leave the operation in progress, identify the exact decision needed, and ask the user. Abort only when the user asks or continuing would be unsafe, and report the abort command before running it.

### 5. Validate the Integrated Branch

Verify that no unmerged entries or conflict markers remain:

```bash
git diff --name-only --diff-filter=U
git status --short --branch
git diff --check <remote>/<base>...HEAD
git merge-base --is-ancestor <remote>/<base> HEAD
```

Inspect the final diff and recent history, including `git diff --stat <remote>/<base>...HEAD` and the full diff when practical. Discover and run the repository's relevant formatter, lint, typecheck, build, and tests, starting with checks closest to the conflicted files and expanding according to risk. Do not claim a clean integration when required checks fail or could not run.

### 6. Automatically Push Safe Updates

After validation, resolve the current branch's configured upstream. Automatically push only when all of the following are true:

- The current branch has an upstream that is exactly the selected remote and current branch (for example, `origin/feature/my-work`).
- The local branch contains the upstream tip, so the update is fast-forwardable.
- The integration did not rewrite an already-published branch.

Use a normal push for that safe case:

```bash
git push <remote> <current-branch>
```

If the branch lacks a matching upstream, the push would be non-fast-forward, or a rebase rewrote a published branch, do not push. Explain the reason and request explicit approval before using:

```bash
git push --force-with-lease <remote> <current-branch>
```

Never substitute `--force` for `--force-with-lease`.

## Final Report

Report:

- The current branch, resolved base ref, fetched commit, and chosen merge/rebase strategy.
- Conflicted paths and the intent preserved in each important resolution.
- Validation commands and their observed results.
- Whether the safe push succeeded, was rejected, or was withheld, including the new commit SHA when pushed.
- Any unresolved decision, skipped check, or follow-up required from the user.
