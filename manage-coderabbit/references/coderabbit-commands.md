# CodeRabbit Command Reference

This reference is based on the CodeRabbit public command documentation checked on 2026-06-16. If a user asks for a command that is missing here, check the current official docs before posting with `--allow-unknown`.

Official reference:

- https://docs.coderabbit.ai/reference/review-commands
- https://docs.coderabbit.ai/plan

## PR Comment Commands

Post these as top-level pull request comments with `gh pr comment --body "@coderabbitai ..."` unless the user explicitly needs another supported surface.

| Command | Use |
| --- | --- |
| `review` | Incremental review of new changes. |
| `full review` | Complete review of all files from scratch. |
| `pause` | Temporarily stop automatic reviews on this PR. |
| `resume` | Restart reviews after a pause. |
| `generate docstrings` | Generate docstrings for functions/classes in the PR. Requires corresponding configuration. |
| `generate unit tests` | Generate unit tests for code in the PR. Requires corresponding configuration. |
| `autofix` | Apply fixes for unresolved CodeRabbit findings, usually on the current branch. |
| `autofix stacked pr` | Apply fixes in a new stacked PR against the current branch. |
| `generate sequence diagram` | Generate a sequence diagram for PR history/changes. |
| `approve` | Resolve unresolved CodeRabbit threads and submit CodeRabbit approval when configured. |
| `resolve` | Mark all CodeRabbit review comments as resolved. |
| `configuration` | Display current CodeRabbit configuration. |
| `generate configuration` | Create/export a `.coderabbit.yaml` configuration. May open or update a PR. |
| `emit path instructions` | Open a PR with suggested path instructions when available. |
| `help` | Show the current command reference. |
| `rate limit` | Ask CodeRabbit for remaining review allowance. Mentioned in pricing/rate-limit docs. |

## PR Body Controls

Use `gh pr edit --body-file` after preserving the existing PR body.

| Control | Use |
| --- | --- |
| `@coderabbitai ignore` | Permanently disable automatic reviews for this PR until removed from the PR description. |
| `@coderabbitai summary` | Placeholder in the PR description where CodeRabbit should place the high-level summary. |

The public command table has described `summary` as a PR comment in some places, while the detailed section describes it as a PR-body placeholder. Prefer PR-body insertion when the user asks to control summary placement. If the user asks to regenerate a summary and the repository already uses comment-based summary commands, post it as a comment after confirming intent.

## Issue Command

`@coderabbitai plan` is for issues, not current-branch PR operation. For GitHub issues:

```bash
gh issue comment ISSUE_NUMBER --body "@coderabbitai plan"
```

Confirm the issue number or URL before posting.

## Risk Notes

- `review` and `full review` can consume review allowance.
- `resolve` resolves all CodeRabbit comments; verify the feedback is actually handled.
- `approve` is top-level PR comment only and depends on CodeRabbit configuration.
- `autofix` may create commits on the current branch; inspect resulting changes before claiming completion.
- `generate configuration` and `emit path instructions` can create or update PRs.
- `ignore` persists until the marker is removed from the PR body.
