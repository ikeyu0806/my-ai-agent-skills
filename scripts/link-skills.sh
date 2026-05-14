#!/usr/bin/env bash
set -u

DRY_RUN=0
FORCE=0
CODEX_HOME_OVERRIDE=""

usage() {
  cat <<'USAGE'
Usage: link-skills.sh [--dry-run] [--force] [--codex-home PATH] [--help]

Symlink every skill directory in this repository into Codex's skill directory.
A skill directory is a direct child of the repository root that contains SKILL.md.

Options:
  --dry-run          Show planned actions without changing files.
  --force            Replace existing symlinks that point somewhere else.
                     Real files/directories are never overwritten.
  --codex-home PATH  Override CODEX_HOME. Defaults to $CODEX_HOME or $HOME/.codex.
  --help             Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --force)
      FORCE=1
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
status=0
found=0

say() {
  printf '%s\n' "$*"
}

mkdir_if_needed() {
  if [ -d "$skills_home" ]; then
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    say "[dry-run] mkdir -p $skills_home"
  else
    mkdir -p "$skills_home"
  fi
}

link_skill() {
  local src="$1"
  local name
  local dest
  local current

  name="$(basename "$src")"
  dest="$skills_home/$name"

  if [ -L "$dest" ]; then
    current="$(readlink "$dest")"
    if [ "$current" = "$src" ]; then
      say "[ok] $name already linked"
      return 0
    fi

    if [ "$FORCE" -eq 1 ]; then
      if [ "$DRY_RUN" -eq 1 ]; then
        say "[dry-run] replace symlink $dest -> $current with $src"
      else
        rm "$dest"
        ln -s "$src" "$dest"
        say "[linked] $name -> $src"
      fi
      return 0
    fi

    say "[conflict] $dest is a symlink to $current"
    say "           rerun with --force to replace this symlink"
    status=1
    return 0
  fi

  if [ -e "$dest" ]; then
    say "[conflict] $dest already exists and is not a symlink"
    say "           move it aside manually; this script will not overwrite real files/directories"
    status=1
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    say "[dry-run] ln -s $src $dest"
  else
    ln -s "$src" "$dest"
    say "[linked] $name -> $src"
  fi
}

mkdir_if_needed

for skill_dir in "$repo_root"/*; do
  if [ -d "$skill_dir" ] && [ -f "$skill_dir/SKILL.md" ]; then
    found=1
    link_skill "$skill_dir"
  fi
done

if [ "$found" -eq 0 ]; then
  say "No skill directories found under $repo_root"
fi

exit "$status"
