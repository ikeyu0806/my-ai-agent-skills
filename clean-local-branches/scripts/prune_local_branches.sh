#!/usr/bin/env bash

# List, then optionally delete, local branches without an open GitHub PR.
# `--apply` is deliberately required for deletion; deletion is never forced.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: prune_local_branches.sh [--apply] [--repo OWNER/REPO] [--] [branch ...]

List local branches that have no open GitHub pull request. Without --apply,
only display candidates. With --apply, delete candidates using `git branch --delete`.

Options:
  --apply                 Delete listed candidates after all PR lookups succeed.
  --repo OWNER/REPO       GitHub repository to query (otherwise infer from cwd).
  -h, --help              Show this help.

The default branch and branches checked out in any worktree are always skipped.
EOF
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

apply=false
github_repo=""
branches=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      apply=true
      ;;
    --repo)
      [[ $# -ge 2 ]] || fail "--repo requires OWNER/REPO"
      github_repo="$2"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        branches+=("$1")
        shift
      done
      break
      ;;
    -*)
      fail "Unknown option: $1"
      ;;
    *)
      branches+=("$1")
      ;;
  esac
  shift
done

require_command git
require_command gh

repository_root="$(git rev-parse --show-toplevel 2>/dev/null)" || fail "Run this command inside a Git repository."
cd "$repository_root"

if [[ -n "$github_repo" ]]; then
  default_branch="$(gh repo view --repo "$github_repo" --json defaultBranchRef --jq '.defaultBranchRef.name')" \
    || fail "Could not determine the GitHub default branch. Check gh authentication and repository access."
else
  default_branch="$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')" \
    || fail "Could not determine the GitHub default branch. Check gh authentication and repository access."
fi
[[ -n "$default_branch" && "$default_branch" != "null" ]] \
  || fail "GitHub did not return a default branch."

if [[ ${#branches[@]} -eq 0 ]]; then
  while IFS= read -r branch; do
    branches+=("$branch")
  done < <(git for-each-ref --format='%(refname:short)' refs/heads)
fi

for branch in "${branches[@]}"; do
  git show-ref --verify --quiet "refs/heads/$branch" \
    || fail "Local branch does not exist: $branch"
done

worktree_branches="$(git worktree list --porcelain | sed -n 's#^branch refs/heads/##p')"

is_checked_out() {
  local target="$1"
  local checked_out_branch

  while IFS= read -r checked_out_branch; do
    [[ "$checked_out_branch" == "$target" ]] && return 0
  done <<< "$worktree_branches"

  return 1
}

candidates=()
skipped_open_pr=0
skipped_protected=0

printf 'GitHub default branch: %s\n' "$default_branch"
printf 'Mode: %s\n\n' "$([[ "$apply" == true ]] && printf 'apply' || printf 'dry run')"

for branch in "${branches[@]}"; do
  if [[ "$branch" == "$default_branch" ]]; then
    printf 'SKIP protected default branch: %s\n' "$branch"
    skipped_protected=$((skipped_protected + 1))
    continue
  fi

  if is_checked_out "$branch"; then
    printf 'SKIP checked out in a worktree: %s\n' "$branch"
    skipped_protected=$((skipped_protected + 1))
    continue
  fi

  if [[ -n "$github_repo" ]]; then
    open_prs="$(gh pr list --repo "$github_repo" --state open --head "$branch" --limit 1 --json number,url --jq '.[] | "#\\(.number) \\(.url)"')" \
      || fail "Could not check open pull requests for $branch. No branches were deleted."
  else
    open_prs="$(gh pr list --state open --head "$branch" --limit 1 --json number,url --jq '.[] | "#\\(.number) \\(.url)"')" \
      || fail "Could not check open pull requests for $branch. No branches were deleted."
  fi

  if [[ -n "$open_prs" ]]; then
    printf 'SKIP open PR: %s (%s)\n' "$branch" "$open_prs"
    skipped_open_pr=$((skipped_open_pr + 1))
    continue
  fi

  printf 'CANDIDATE no open PR: %s\n' "$branch"
  candidates+=("$branch")
done

printf '\nSummary: %s candidate(s), %s with open PR, %s protected.\n' \
  "${#candidates[@]}" "$skipped_open_pr" "$skipped_protected"

if [[ ${#candidates[@]} -eq 0 ]]; then
  exit 0
fi

if [[ "$apply" != true ]]; then
  printf 'Dry run only. Re-run with --apply to attempt safe local deletion.\n'
  exit 0
fi

failed_deletions=0
for branch in "${candidates[@]}"; do
  if git branch --delete -- "$branch"; then
    printf 'DELETED: %s\n' "$branch"
  else
    printf 'RETAINED (not safely deletable): %s\n' "$branch" >&2
    failed_deletions=$((failed_deletions + 1))
  fi
done

if [[ "$failed_deletions" -gt 0 ]]; then
  printf '%s branch(es) were retained because git branch --delete refused them.\n' "$failed_deletions" >&2
  exit 1
fi
