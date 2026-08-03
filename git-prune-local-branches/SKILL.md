---
name: git-prune-local-branches
description: Safely find and remove unused local Git branches with no open GitHub pull request, using `gh`. Use when asked to clean up, delete, prune, or audit local branches while preserving branches with open PRs, the repository default branch, and branches checked out in any worktree.
---

# Git Prune Local Branches

Use this skill from the target Git repository. Require `git`, authenticated `gh`, and access to the repository's GitHub pull requests.

## Workflow

1. Run the bundled script without `--apply` to show a dry-run. It queries `gh pr list --state open --head <branch>` for every eligible local branch.
2. Review skipped branches and deletion candidates with the user. Abort if GitHub access fails; do not infer that a failed query means there is no PR.
3. Run the same command with `--apply` only after the user has asked to delete the displayed candidates.
4. Report deleted branches and branches retained because Git refuses to delete an unmerged branch.

```bash
bash /path/to/git-prune-local-branches/scripts/prune_local_branches.sh
bash /path/to/git-prune-local-branches/scripts/prune_local_branches.sh --apply
```

Pass branch names to limit the scope, or `--repo OWNER/REPO` when the pull-request repository cannot be inferred from the current directory:

```bash
bash /path/to/git-prune-local-branches/scripts/prune_local_branches.sh feature/old-experiment
bash /path/to/git-prune-local-branches/scripts/prune_local_branches.sh --repo acme/widgets --apply feature/old-experiment
```

## Safety Rules

- Keep dry-run as the default. Treat `--apply` as the explicit delete confirmation.
- Never delete the GitHub default branch or a branch checked out in any linked worktree.
- Never delete a branch when a matching open PR exists.
- Use only `git branch --delete`; do not use `-D` or `--force`. A no-PR branch that is unmerged remains intact and is reported.
- Do not delete anything if any GitHub PR lookup fails. Resolve authentication, network, or repository-selection errors first.
- Do not use `git remote prune`, delete remote branches, or alter pull requests as part of this skill.
