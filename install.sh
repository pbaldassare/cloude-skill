#!/usr/bin/env bash
# Crea/aggiorna i symlink delle skill in ~/.claude/skills e ~/.cursor/skills,
# rendendole disponibili in Claude Code e Cursor Agent su questa macchina.
#
#   ./install.sh              # installa tutte le skill (skills/ + third-party/)
#   ./install.sh supabase-rls # installa solo le skill indicate
#   ./install.sh --list       # mostra cosa è installato e da dove
#   ./install.sh --prune      # rimuove i symlink orfani che puntano a questa repo

set -euo pipefail
shopt -s nullglob

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
CURSOR_DIR="${CURSOR_SKILLS_DIR:-$HOME/.cursor/skills}"
TARGET_DIRS=("$CLAUDE_DIR" "$CURSOR_DIR")
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

link_skill_into() {
  local name="$1" src="$2" target_dir="$3" dest
  dest="$target_dir/$name"

  if [[ -L "$dest" ]]; then
    local current
    current="$(readlink "$dest")"
    if [[ "$current" == "$src" ]]; then
      echo "  = $name (già collegata)"
      return 0
    fi
    echo "  ↻ $name (era: $current)"
    rm "$dest"
  elif [[ -e "$dest" ]]; then
    echo "  ✗ $name — esiste già come file/cartella reale, non lo tocco: $dest"
    return 1
  fi

  ln -s "$src" "$dest"
  echo "  + $name → $src"
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
      if [[ "$target" == "$REPO_DIR"* && ! -e "$target" ]]; then
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
    list_dir "$CLAUDE_DIR"
    echo
    list_dir "$CURSOR_DIR"
    exit 0
    ;;
  --prune)
    prune_dir "$CLAUDE_DIR"
    echo
    prune_dir "$CURSOR_DIR"
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
