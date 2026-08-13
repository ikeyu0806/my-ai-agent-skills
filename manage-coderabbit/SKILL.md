---
name: manage-coderabbit
description: 'Use when asked to send, post, trigger, or manage CodeRabbit commands on the current GitHub pull request. Trigger for requests such as "ask CodeRabbit to review this PR", "run CodeRabbit full review", "pause/resume CodeRabbit", "autofix with CodeRabbit", "resolve CodeRabbit comments", "show CodeRabbit config", or Japanese requests like "現在のブランチのPRにCodeRabbitへ指示して", "coderabbitにレビュー依頼して", "CodeRabbitコマンドをPRに投げて".'
---

# Manage CodeRabbit

## Overview

Use this skill to operate CodeRabbit by posting the right `@coderabbitai` command to the PR comment stream or inserting the right placeholder/control text into the PR body with `gh`.

Prefer the bundled helper script for deterministic placement and safety checks:

```bash
bash manage-coderabbit/scripts/coderabbit_pr_command.sh --command "review" --dry-run
bash manage-coderabbit/scripts/coderabbit_pr_command.sh --command "review"
```

Read `references/coderabbit-commands.md` when choosing a command, handling a command not listed here, or deciding whether the command belongs in a PR comment or the PR body.

## Workflow

1. Establish local and GitHub context.
2. Map the user's intent to a CodeRabbit command and location.
3. Confirm before commands with broad side effects.
4. Post or insert the command with `gh`.
5. Verify and report the PR URL and command used.

## 1. Establish Context

Start in the repository that owns the current branch.

```bash
git status --short
git branch --show-current
gh auth status
gh pr view --json number,url,headRefName,state,title
```

Stop and report the blocker if `gh` is not authenticated, no PR exists for the current branch, or the branch is detached. Do not guess a PR number.

If the user supplied a PR number or URL, pass it to the helper with `--pr`.

```bash
bash manage-coderabbit/scripts/coderabbit_pr_command.sh --pr 123 --command "full review" --dry-run
```

## 2. Choose Command

Common PR comment commands:

- `review`: request an incremental review of new changes.
- `full review`: request a complete PR review from scratch.
- `pause`: pause automatic review activity on the PR.
- `resume`: resume automatic review activity.
- `configuration`: ask CodeRabbit to show current configuration.
- `help`: ask CodeRabbit to list available commands.
- `generate docstrings`: ask CodeRabbit to generate docstrings.
- `generate unit tests`: ask CodeRabbit to generate unit tests.
- `generate sequence diagram`: ask CodeRabbit to generate a sequence diagram.
- `autofix`: ask CodeRabbit to apply unresolved review fixes on the current branch.
- `autofix stacked pr`: ask CodeRabbit to open a stacked PR with fixes.
- `approve`: ask CodeRabbit to resolve its threads and approve when configured.
- `resolve`: ask CodeRabbit to resolve all CodeRabbit review comments.
- `generate configuration`: ask CodeRabbit to create or show `.coderabbit.yaml`.
- `emit path instructions`: ask CodeRabbit to open a PR with suggested path instructions.

PR body controls/placeholders:

- `ignore`: insert `@coderabbitai ignore` into the PR description to disable reviews for that PR.
- `summary-placeholder`: insert `@coderabbitai summary` into the PR description where CodeRabbit should place its summary.

Issue-only command:

- `plan`: use on issues, not the current branch's PR. For GitHub issues, post with `gh issue comment ISSUE --body "@coderabbitai plan"` after confirming the issue target.

## 3. Confirm Risky Commands

Ask for explicit confirmation before posting or inserting commands that can make persistent changes, consume meaningful review allowance, resolve threads, or create commits/PRs.

Confirm before:

- `full review`
- `ignore`
- `resolve`
- `approve`
- `autofix`
- `autofix stacked pr`
- `generate docstrings`
- `generate unit tests`
- `generate configuration`
- `emit path instructions`

When the user already gave an unambiguous instruction such as "run CodeRabbit autofix on this PR", treat that as confirmation and pass `--yes` to the helper.

## 4. Execute With Helper

Dry-run first when the command changes PR body, has broad side effects, or the wording/location is ambiguous.

```bash
bash manage-coderabbit/scripts/coderabbit_pr_command.sh --command "full review" --dry-run
bash manage-coderabbit/scripts/coderabbit_pr_command.sh --command "full review" --yes
```

Use the helper's automatic location for normal commands:

```bash
bash manage-coderabbit/scripts/coderabbit_pr_command.sh --command "pause"
bash manage-coderabbit/scripts/coderabbit_pr_command.sh --command "resume"
bash manage-coderabbit/scripts/coderabbit_pr_command.sh --command "configuration"
```

For PR body insertion:

```bash
bash manage-coderabbit/scripts/coderabbit_pr_command.sh --command "ignore" --yes
bash manage-coderabbit/scripts/coderabbit_pr_command.sh --command "summary-placeholder"
```

If CodeRabbit documentation has changed and a command is not in the helper allowlist, verify the official docs and then use:

```bash
bash manage-coderabbit/scripts/coderabbit_pr_command.sh --command "new command" --allow-unknown --dry-run
```

## 5. Manual Fallback

When the helper is unavailable, use `gh` directly.

Post a PR comment:

```bash
gh pr comment --body "@coderabbitai review"
```

Append a PR-body control safely:

```bash
gh pr view --json body --jq '.body // ""' > /tmp/pr-body.md
printf '\n\n@coderabbitai ignore\n' >> /tmp/pr-body.md
gh pr edit --body-file /tmp/pr-body.md
```

Use `gh pr view --comments` or `gh pr view --json body,comments,url` afterward to verify the command is visible.

## 6. Final Response

Report:

- PR number or URL.
- Exact CodeRabbit command posted or inserted.
- Location: PR comment or PR body.
- Whether it was a dry run or actually sent.
- Any command that was skipped because confirmation or a target was missing.

Keep the response concise and do not paste full PR bodies or unrelated comments.
