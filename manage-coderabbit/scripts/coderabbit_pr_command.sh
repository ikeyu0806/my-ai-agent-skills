#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  coderabbit_pr_command.sh --command COMMAND [options]

Options:
  --command COMMAND      CodeRabbit command without the @coderabbitai prefix.
  --pr PR_OR_URL         Pull request number, URL, or branch. Defaults to current branch PR.
  --repo OWNER/REPO      GitHub repository for gh -R.
  --handle HANDLE        CodeRabbit handle. Defaults to @coderabbitai.
  --location LOCATION    auto, comment, or body. Defaults to auto.
  --dry-run              Print the planned gh operation without changing GitHub.
  --yes                  Confirm commands with broad side effects.
  --allow-unknown        Allow a command not in this script's allowlist.
  --help                 Show this help.

Examples:
  coderabbit_pr_command.sh --command "review" --dry-run
  coderabbit_pr_command.sh --command "full review" --yes
  coderabbit_pr_command.sh --command "ignore" --yes
  coderabbit_pr_command.sh --command "summary-placeholder"
USAGE
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

lower_trim() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | awk '{$1=$1; print}'
}

contains_line() {
  local needle="$1"
  local file="$2"
  grep -Fxq "$needle" "$file"
}

COMMAND=""
PR_TARGET=""
REPO=""
HANDLE="@coderabbitai"
LOCATION="auto"
DRY_RUN=0
YES=0
ALLOW_UNKNOWN=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --command)
      [ "$#" -ge 2 ] || die "--command requires a value"
      COMMAND="$2"
      shift 2
      ;;
    --pr)
      [ "$#" -ge 2 ] || die "--pr requires a value"
      PR_TARGET="$2"
      shift 2
      ;;
    --repo|-R)
      [ "$#" -ge 2 ] || die "--repo requires a value"
      REPO="$2"
      shift 2
      ;;
    --handle)
      [ "$#" -ge 2 ] || die "--handle requires a value"
      HANDLE="$2"
      shift 2
      ;;
    --location)
      [ "$#" -ge 2 ] || die "--location requires a value"
      LOCATION="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --yes|-y)
      YES=1
      shift
      ;;
    --allow-unknown)
      ALLOW_UNKNOWN=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[ -n "$COMMAND" ] || die "--command is required"
command -v gh >/dev/null 2>&1 || die "gh is not installed or not on PATH"

case "$HANDLE" in
  @*) ;;
  *) HANDLE="@${HANDLE}" ;;
esac

NORMALIZED="$(lower_trim "$COMMAND")"

case "$NORMALIZED" in
  summary-placeholder)
    CR_COMMAND="summary"
    DEFAULT_LOCATION="body"
    KNOWN=1
    RISKY=0
    ;;
  review|pause|resume|configuration|help|"rate limit")
    CR_COMMAND="$NORMALIZED"
    DEFAULT_LOCATION="comment"
    KNOWN=1
    RISKY=0
    ;;
  "full review"|"generate docstrings"|"generate unit tests"|autofix|"autofix stacked pr"|"generate sequence diagram"|approve|resolve|"generate configuration"|"emit path instructions"|"emit path-instructions")
    CR_COMMAND="$NORMALIZED"
    DEFAULT_LOCATION="comment"
    KNOWN=1
    RISKY=1
    ;;
  ignore)
    CR_COMMAND="$NORMALIZED"
    DEFAULT_LOCATION="body"
    KNOWN=1
    RISKY=1
    ;;
  *)
    CR_COMMAND="$COMMAND"
    DEFAULT_LOCATION="comment"
    KNOWN=0
    RISKY=1
    ;;
esac

if [ "$KNOWN" -eq 0 ] && [ "$ALLOW_UNKNOWN" -ne 1 ]; then
  die "unknown CodeRabbit command '$COMMAND'; verify docs and rerun with --allow-unknown"
fi

if [ "$LOCATION" = "auto" ]; then
  LOCATION="$DEFAULT_LOCATION"
fi

case "$LOCATION" in
  comment|body) ;;
  *) die "--location must be auto, comment, or body" ;;
esac

if [ "$RISKY" -eq 1 ] && [ "$YES" -ne 1 ] && [ "$DRY_RUN" -ne 1 ]; then
  die "command '$CR_COMMAND' has broad side effects; rerun with --yes after confirming intent"
fi

gh_cmd() {
  if [ -n "$REPO" ]; then
    gh -R "$REPO" "$@"
  else
    gh "$@"
  fi
}

gh_pr_view() {
  if [ -n "$PR_TARGET" ]; then
    gh_cmd pr view "$PR_TARGET" "$@"
  else
    gh_cmd pr view "$@"
  fi
}

gh_pr_comment() {
  if [ -n "$PR_TARGET" ]; then
    gh_cmd pr comment "$PR_TARGET" "$@"
  else
    gh_cmd pr comment "$@"
  fi
}

gh_pr_edit() {
  if [ -n "$PR_TARGET" ]; then
    gh_cmd pr edit "$PR_TARGET" "$@"
  else
    gh_cmd pr edit "$@"
  fi
}

if ! gh_cmd auth status >/dev/null 2>&1; then
  die "gh is not authenticated"
fi

PR_INFO="$(gh_pr_view --json number,url,state --jq '[.number, .url, .state] | @tsv' 2>/dev/null)" || die "could not resolve pull request"
IFS=$'\t' read -r PR_NUMBER PR_URL PR_STATE <<< "$PR_INFO"
BODY="${HANDLE} ${CR_COMMAND}"

if [ "$LOCATION" = "comment" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'dry_run=true\n'
    printf 'pr=%s\nurl=%s\nstate=%s\nlocation=comment\nbody=%s\n' "$PR_NUMBER" "$PR_URL" "$PR_STATE" "$BODY"
    printf 'command: gh'
    if [ -n "$REPO" ]; then
      printf ' -R %q' "$REPO"
    fi
    printf ' pr comment'
    if [ -n "$PR_TARGET" ]; then
      printf ' %q' "$PR_TARGET"
    fi
    printf ' --body %q\n' "$BODY"
    exit 0
  fi

  gh_pr_comment --body "$BODY"
  printf 'posted=true\npr=%s\nurl=%s\nlocation=comment\nbody=%s\n' "$PR_NUMBER" "$PR_URL" "$BODY"
  exit 0
fi

TMP_BODY="$(mktemp)"
trap 'rm -f "$TMP_BODY" "$TMP_BODY.new"' EXIT

gh_pr_view --json body --jq '.body // ""' > "$TMP_BODY"

if contains_line "$BODY" "$TMP_BODY"; then
  printf 'already_present=true\npr=%s\nurl=%s\nlocation=body\nbody=%s\n' "$PR_NUMBER" "$PR_URL" "$BODY"
  exit 0
fi

cp "$TMP_BODY" "$TMP_BODY.new"
if [ -s "$TMP_BODY.new" ]; then
  printf '\n\n%s\n' "$BODY" >> "$TMP_BODY.new"
else
  printf '%s\n' "$BODY" > "$TMP_BODY.new"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  printf 'dry_run=true\n'
  printf 'pr=%s\nurl=%s\nstate=%s\nlocation=body\nbody=%s\n' "$PR_NUMBER" "$PR_URL" "$PR_STATE" "$BODY"
  printf 'command: gh'
  if [ -n "$REPO" ]; then
    printf ' -R %q' "$REPO"
  fi
  printf ' pr edit'
  if [ -n "$PR_TARGET" ]; then
    printf ' %q' "$PR_TARGET"
  fi
  printf ' --body-file %q\n' "$TMP_BODY.new"
  exit 0
fi

gh_pr_edit --body-file "$TMP_BODY.new"
printf 'updated=true\npr=%s\nurl=%s\nlocation=body\nbody=%s\n' "$PR_NUMBER" "$PR_URL" "$BODY"
