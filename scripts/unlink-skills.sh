#!/usr/bin/env bash
set -u

DRY_RUN=0
CODEX_HOME_OVERRIDE=""

usage() {
  cat <<'USAGE'
Usage: unlink-skills.sh [--dry-run] [--codex-home PATH] [--help]

Remove Codex skill symlinks created by link-skills.sh.
Only symlinks that point back to this repository are removed.

Options:
  --dry-run          Show planned actions without changing files.
  --codex-home PATH  Override CODEX_HOME. Defaults to $CODEX_HOME or $HOME/.codex.
  --help             Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --codex-home)
      shift
      if [ "$#" -eq 0 ]; then
        printf '%s\n' '--codex-home requires a path' >&2
        exit 2
      fi
      CODEX_HOME_OVERRIDE="$1"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

if [ -n "$CODEX_HOME_OVERRIDE" ]; then
  codex_home="$CODEX_HOME_OVERRIDE"
else
  codex_home="${CODEX_HOME:-$HOME/.codex}"
fi

skills_home="$codex_home/skills"
found=0

say() {
  printf '%s\n' "$*"
}

unlink_skill() {
  local src="$1"
  local name
  local dest
  local current

  name="$(basename "$src")"
  dest="$skills_home/$name"

  if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    say "[skip] $name is not linked"
    return 0
  fi

  if [ ! -L "$dest" ]; then
    say "[skip] $dest exists but is not a symlink"
    return 0
  fi

  current="$(readlink "$dest")"
  if [ "$current" != "$src" ]; then
    say "[skip] $dest points to $current, not $src"
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    say "[dry-run] rm $dest"
  else
    rm "$dest"
    say "[removed] $name"
  fi
}

for skill_dir in "$repo_root"/*; do
  if [ -d "$skill_dir" ] && [ -f "$skill_dir/SKILL.md" ]; then
    found=1
    unlink_skill "$skill_dir"
  fi
done

if [ "$found" -eq 0 ]; then
  say "No skill directories found under $repo_root"
fi
