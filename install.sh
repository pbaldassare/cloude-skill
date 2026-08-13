#!/usr/bin/env bash
# Crea/aggiorna i symlink delle skill in:
#   ~/.claude/skills          Claude Code, tutte le sessioni di questa macchina
#   ~/.cursor/skills          Cursor Agent, tutte le sessioni di questa macchina
#   .claude/skills            questa repo (aprire o aggiungere in workspace)
#   .cursor/skills            questa repo (aprire o aggiungere in workspace)
#
#   ./install.sh              # installa tutte le skill (skills/ + third-party/)
#   ./install.sh supabase-rls # installa solo le skill indicate
#   ./install.sh --list       # mostra cosa è installato e dove punta
#   ./install.sh --prune      # rimuove i symlink orfani che puntano a questa repo

set -euo pipefail
shopt -s nullglob

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
CURSOR_DIR="${CURSOR_SKILLS_DIR:-$HOME/.cursor/skills}"
REPO_CLAUDE="$REPO_DIR/.claude/skills"
REPO_CURSOR="$REPO_DIR/.cursor/skills"
HOME_DIRS=("$CLAUDE_DIR" "$CURSOR_DIR")
REPO_DIRS=("$REPO_CLAUDE" "$REPO_CURSOR")
TARGET_DIRS=("${HOME_DIRS[@]}" "${REPO_DIRS[@]}")
SOURCE_DIRS=("$REPO_DIR/skills" "$REPO_DIR/third-party")

find_skill() {
  local name="$1" dir
  for dir in "${SOURCE_DIRS[@]}"; do
    if [[ -f "$dir/$name/SKILL.md" ]]; then
      printf '%s\n' "$dir/$name"
      return 0
    fi
  done
  return 1
}

all_skills() {
  local dir path
  for dir in "${SOURCE_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    for path in "$dir"/*/; do
      [[ -f "${path}SKILL.md" ]] && basename "$path"
    done
  done
}

# Path relativo da .claude/skills o .cursor/skills verso la cartella della skill.
repo_link_src() {
  local src="$1"
  case "$src" in
    "$REPO_DIR/skills/"*) printf '../../skills/%s\n' "$(basename "$src")" ;;
    "$REPO_DIR/third-party/"*) printf '../../third-party/%s\n' "$(basename "$src")" ;;
    *) printf '%s\n' "$src" ;;
  esac
}

link_skill_into() {
  local name="$1" src="$2" target_dir="$3" dest link_src
  dest="$target_dir/$name"
  if [[ "$target_dir" == "$REPO_DIR/"* ]]; then
    link_src="$(repo_link_src "$src")"
  else
    link_src="$src"
  fi

  if [[ -L "$dest" ]]; then
    local current
    current="$(readlink "$dest")"
    if [[ "$current" == "$link_src" ]]; then
      echo "  = $name (già collegata)"
      return 0
    fi
    echo "  ↻ $name (era: $current)"
    rm "$dest"
  elif [[ -e "$dest" ]]; then
    echo "  ✗ $name — esiste già come file/cartella reale, non lo tocco: $dest"
    return 1
  fi

  ln -s "$link_src" "$dest"
  echo "  + $name → $link_src"
}

link_skill() {
  local name="$1" src target_dir failed=0
  src="$(find_skill "$name")" || { echo "  ✗ $name — SKILL.md non trovato"; return 1; }
  for target_dir in "${TARGET_DIRS[@]}"; do
    mkdir -p "$target_dir"
    echo "  [$target_dir]"
    link_skill_into "$name" "$src" "$target_dir" || failed=1
  done
  return "$failed"
}

list_dir() {
  local target_dir="$1" path name
  echo "Skill in $target_dir:"
  if [[ ! -d "$target_dir" ]]; then
    echo "  (directory assente)"
    return 0
  fi
  local found=0
  for path in "$target_dir"/*/; do
    found=1
    name="$(basename "$path")"
    if [[ -L "${path%/}" ]]; then
      echo "  $name → $(readlink "${path%/}")"
    else
      echo "  $name (cartella reale)"
    fi
  done
  if [[ "$found" -eq 0 ]]; then
    echo "  (vuota)"
  fi
}

prune_dir() {
  local target_dir="$1" path target
  echo "Rimuovo i symlink rotti che puntano a $REPO_DIR da $target_dir:"
  if [[ ! -d "$target_dir" ]]; then
    echo "  (directory assente)"
    return 0
  fi
  local removed=0
  for path in "$target_dir"/*; do
    if [[ -L "$path" ]]; then
      target="$(readlink "$path")"
      local resolved="$target"
      if [[ "$target" != /* ]]; then
        resolved="$(cd "$(dirname "$path")" && pwd)/$target"
      fi
      if [[ "$resolved" == "$REPO_DIR"* && ! -e "$path" ]]; then
        rm "$path"
        echo "  - $(basename "$path")"
        removed=1
      fi
    fi
  done
  if [[ "$removed" -eq 0 ]]; then
    echo "  (nessuno)"
  fi
}

case "${1:-}" in
  --list)
    for dir in "${TARGET_DIRS[@]}"; do
      list_dir "$dir"
      echo
    done
    exit 0
    ;;
  --prune)
    for dir in "${TARGET_DIRS[@]}"; do
      prune_dir "$dir"
      echo
    done
    exit 0
    ;;
esac

if [[ $# -gt 0 ]]; then
  skills=("$@")
else
  mapfile -t skills < <(all_skills)
fi

if [[ ${#skills[@]} -eq 0 ]]; then
  echo "Nessuna skill da installare."
  exit 0
fi

echo "Installo in ${TARGET_DIRS[*]}:"
failed=0
for name in "${skills[@]}"; do
  echo "$name"
  link_skill "$name" || failed=1
done

exit "$failed"
