---
name: create-review-pr
description: Use when the user wants to open a non-draft, ready-for-review GitHub pull request from the current working branch, including requests such as "create a review-ready PR", "open PR", "ready for review", "non-draft PR", "PRを作成して", "レビュー可能なプルリクを作って", or "/create-review-pr". Inspects the branch diff, writes an accurate title and description, validates the branch, pushes it, and creates an open PR. Do not use for draft PRs or for responding to feedback on an existing PR.
---

# Create Review-Ready PR

Create one polished, non-draft PR from the current branch. Treat the PR title and body as review artifacts: derive both from the actual diff and commits, not from guesses.

## Invocation

Accept an optional base branch, title, and language hint. Use a supplied title verbatim; otherwise generate a concise, imperative title in the user's language. Use the language of the request by default.

```text
/create-review-pr
/create-review-pr --base develop
/create-review-pr --title "fix: prevent duplicate webhook delivery"
/create-review-pr --lang ja
```

Use the repository default branch as the base when none is supplied. Tell the user which base was selected. Do not create a PR when the requested target is known to be different; ask for `--base` instead.

## Workflow

### 1. Establish context

Announce that this skill will create a ready-for-review PR. Then run these checks in the repository that owns the current branch:

```bash
git rev-parse --show-toplevel
git status --short
git branch --show-current
git log --oneline --decorate -20
gh auth status
gh repo view --json nameWithOwner,defaultBranchRef
```

Stop and report the blocker if the checkout is detached, the branch is the base branch, `gh` is unavailable or unauthenticated, or the repository has no GitHub remote. Never guess a PR number.

First check for an existing open PR for the current branch:

```bash
gh pr list --head "$(git branch --show-current)" --state open --json number,url,title,isDraft
```

If one exists, report its URL and do not create a duplicate. Hand off to the PR-update or review workflow only when the user explicitly asks to update it.

### 2. Make the branch safe to review

Read applicable repository instructions and PR conventions before making any commit or writing the body. In particular, inspect `AGENTS.md`, `CODEX.md`, `CONTRIBUTING.md`, and any pull-request template that exists under `.github/`.

Determine `base` from `--base` when supplied; otherwise use `defaultBranchRef.name` returned by `gh repo view`. Fetch the base ref without discarding local work, then inspect the full proposed PR:

```bash
git fetch origin "$base"
git diff --check "origin/$base...HEAD"
git log --oneline "origin/$base..HEAD"
git diff --stat "origin/$base...HEAD"
git diff "origin/$base...HEAD"
```

Read the whole diff. Stop for user direction if it contains scope creep, debug residue, apparent secrets, credentials, private endpoints, or changes whose relationship to the PR is unclear.

For uncommitted changes, inspect them separately with `git diff` and `git diff --cached`. If all changes are clearly in scope and form one coherent commit, commit them with the repository's observed commit-message convention. If their scope is unclear or they require multiple commits, ask the user before staging anything. Never stage unrelated changes merely to make the tree clean.

Run the relevant local checks described by repository documentation and pull-request CI workflows. Prefer the exact `pull_request` workflow commands; otherwise use the project's documented lint, typecheck, test, and build commands appropriate to the changed area. Always run `git diff --check`. Record every command and result.

Do not create a review-ready PR while required checks fail. Report the failure and fix it only when the user has asked to fix it or the fix is an unambiguous, in-scope correction.

### 3. Write the title and description

Base the title and description on `origin/$base...HEAD`, the commit list, and the actual validation results.

- Keep a generated title concise, specific, and imperative; preserve a relevant conventional prefix such as `feat:`, `fix:`, `refactor:`, or `docs:` when the repository uses one.
- Avoid generic titles such as `updates`, `changes`, `WIP`, or a restatement of a ticket number without intent.
- Follow the repository PR template exactly when present; fill every applicable section and use `N/A` only where genuinely not applicable.
- Without a template, write this body in the selected language:

  ```markdown
  ## Summary

  - <the user-visible outcome>
  - <the important implementation or behavior change>

  ## Changes

  - <concrete change grouped by area>

  ## Validation

  - `<command>` — passed

  ## Review notes

  - <important risk, migration, rollout, or reviewer focus; omit this section when none applies>
  ```

Do not claim tests passed when they were not run. Do not invent issue IDs, screenshots, migrations, performance results, or rollout instructions. Keep the body focused enough that a reviewer can understand the intent and verify the change without replaying the whole diff.

### 4. Push and create the PR

Push the branch without force-pushing:

```bash
git push -u origin HEAD
```

If the push is rejected as non-fast-forward, stop and report it. Do not rebase or force-push unless the user explicitly asks.

Write the final body to a uniquely created temporary file, then create the PR with explicit arguments. Omit `--draft`: `gh pr create` creates an open, review-ready PR by default.

```bash
gh pr create \
  --base "$base" \
  --head "$(git branch --show-current)" \
  --title "$title" \
  --body-file "$body_file"
```

Immediately verify the result:

```bash
gh pr view --json number,url,title,state,isDraft,baseRefName,headRefName,mergeStateStatus
gh pr checks --json name,state,link 2>/dev/null || true
```

The completion condition is `state: OPEN` and `isDraft: false`. Report the PR URL, title, base branch, validation results, and any still-pending remote checks. Do not wait for CI unless the user asks; initial checks are normally pending immediately after opening a PR.
