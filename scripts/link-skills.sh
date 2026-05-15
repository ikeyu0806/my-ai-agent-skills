#!/usr/bin/env bash
set -u

DRY_RUN=0
FORCE=0
CODEX_HOME_OVERRIDE=""
CLAUDE_HOME_OVERRIDE=""
CURSOR_HOME_OVERRIDE=""
AGENT_ARGS=()

usage() {
  cat <<'USAGE'
Usage: link-skills.sh [--agent codex|claude|cursor|all] [--dry-run] [--force] [options]

Symlink every skill directory in this repository into one or more AI agent
skill directories. A skill directory is a direct child of the repository root
that contains SKILL.md.

Options:
  --agent NAME        Target agent: codex, claude, cursor, or all.
                      May be passed more than once. Default: codex.
  --dry-run          Show planned actions without changing files.
  --force            Replace existing symlinks that point somewhere else.
                      Real files/directories are never overwritten.
  --codex-home PATH  Override CODEX_HOME. Defaults to $CODEX_HOME or $HOME/.codex.
  --claude-home PATH Override CLAUDE_HOME. Defaults to $CLAUDE_HOME or $HOME/.claude.
  --cursor-home PATH Override CURSOR_HOME. Defaults to $CURSOR_HOME or $HOME/.cursor.
  --help             Show this help.
USAGE
}

add_agent() {
  case "$1" in
    codex|claude|cursor)
      AGENT_ARGS+=("$1")
      ;;
    all)
      AGENT_ARGS+=(codex claude cursor)
      ;;
    *)
      printf 'Unknown agent: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --agent)
      shift
      if [ "$#" -eq 0 ]; then
        printf '%s\n' '--agent requires a value' >&2
        exit 2
      fi
      add_agent "$1"
      ;;
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
    --claude-home)
      shift
      if [ "$#" -eq 0 ]; then
        printf '%s\n' '--claude-home requires a path' >&2
        exit 2
      fi
      CLAUDE_HOME_OVERRIDE="$1"
      ;;
    --cursor-home)
      shift
      if [ "$#" -eq 0 ]; then
        printf '%s\n' '--cursor-home requires a path' >&2
        exit 2
      fi
      CURSOR_HOME_OVERRIDE="$1"
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

if [ "${#AGENT_ARGS[@]}" -eq 0 ]; then
  AGENT_ARGS=(codex)
fi

selected_agents=()
seen_agents=" "
for agent in "${AGENT_ARGS[@]}"; do
  case "$seen_agents" in
    *" $agent "*) ;;
    *)
      selected_agents+=("$agent")
      seen_agents="${seen_agents}${agent} "
      ;;
  esac
done

status=0
found=0

say() {
  printf '%s\n' "$*"
}

skills_dir_for_agent() {
  local agent="$1"
  local home_dir

  case "$agent" in
    codex)
      if [ -n "$CODEX_HOME_OVERRIDE" ]; then
        home_dir="$CODEX_HOME_OVERRIDE"
      else
        home_dir="${CODEX_HOME:-$HOME/.codex}"
      fi
      printf '%s/skills\n' "$home_dir"
      ;;
    claude)
      if [ -n "$CLAUDE_HOME_OVERRIDE" ]; then
        home_dir="$CLAUDE_HOME_OVERRIDE"
      else
        home_dir="${CLAUDE_HOME:-$HOME/.claude}"
      fi
      printf '%s/skills\n' "$home_dir"
      ;;
    cursor)
      if [ -n "$CURSOR_HOME_OVERRIDE" ]; then
        home_dir="$CURSOR_HOME_OVERRIDE"
      else
        home_dir="${CURSOR_HOME:-$HOME/.cursor}"
      fi
      printf '%s/skills-cursor\n' "$home_dir"
      ;;
  esac
}

mkdir_if_needed() {
  local agent="$1"
  local skills_home="$2"

  if [ -d "$skills_home" ]; then
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    say "[dry-run][$agent] mkdir -p $skills_home"
  else
    mkdir -p "$skills_home"
  fi
}

link_skill() {
  local agent="$1"
  local skills_home="$2"
  local src="$3"
  local name
  local dest
  local current

  name="$(basename "$src")"
  dest="$skills_home/$name"

  if [ -L "$dest" ]; then
    current="$(readlink "$dest")"
    if [ "$current" = "$src" ]; then
      say "[ok][$agent] $name already linked"
      return 0
    fi

    if [ "$FORCE" -eq 1 ]; then
      if [ "$DRY_RUN" -eq 1 ]; then
        say "[dry-run][$agent] replace symlink $dest -> $current with $src"
      else
        rm "$dest"
        ln -s "$src" "$dest"
        say "[linked][$agent] $name -> $src"
      fi
      return 0
    fi

    say "[conflict][$agent] $dest is a symlink to $current"
    say "                  rerun with --force to replace this symlink"
    status=1
    return 0
  fi

  if [ -e "$dest" ]; then
    say "[conflict][$agent] $dest already exists and is not a symlink"
    say "                  move it aside manually; this script will not overwrite real files/directories"
    status=1
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    say "[dry-run][$agent] ln -s $src $dest"
  else
    ln -s "$src" "$dest"
    say "[linked][$agent] $name -> $src"
  fi
}

for agent in "${selected_agents[@]}"; do
  skills_home="$(skills_dir_for_agent "$agent")"
  mkdir_if_needed "$agent" "$skills_home"

  for skill_dir in "$repo_root"/*; do
    if [ -d "$skill_dir" ] && [ -f "$skill_dir/SKILL.md" ]; then
      found=1
      link_skill "$agent" "$skills_home" "$skill_dir"
    fi
  done
done

if [ "$found" -eq 0 ]; then
  say "No skill directories found under $repo_root"
fi

exit "$status"
