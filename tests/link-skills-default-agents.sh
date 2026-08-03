#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/link-skills-default-agents.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

output="$(
  bash "$repo_root/scripts/link-skills.sh" \
    --dry-run \
    --codex-home "$test_root/codex" \
    --claude-home "$test_root/claude" \
    --cursor-home "$test_root/cursor"
)"

assert_contains() {
  local expected="$1"

  if ! grep -Fqx "$expected" <<<"$output"; then
    printf 'Expected output was missing: %s\n' "$expected" >&2
    printf '%s\n' "$output" >&2
    exit 1
  fi
}

assert_contains "[dry-run][codex] mkdir -p $test_root/codex/skills"
assert_contains "[dry-run][claude] mkdir -p $test_root/claude/skills"
assert_contains "[dry-run][cursor] mkdir -p $test_root/cursor/skills-cursor"
