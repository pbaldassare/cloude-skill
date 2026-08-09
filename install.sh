#!/usr/bin/env bash
# Crea/aggiorna i symlink delle skill in ~/.claude/skills, rendendole disponibili
# in tutte le sessioni Claude Code (Cursor, VS Code, CLI) su questa macchina.
#
#   ./install.sh              # installa tutte le skill (skills/ + third-party/)
#   ./install.sh supabase-rls # installa solo le skill indicate
#   ./install.sh --list       # mostra cosa è installato e da dove
#   ./install.sh --prune      # rimuove i symlink orfani che puntano a questa repo

set -euo pipefail
shopt -s nullglob

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
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

link_skill() {
  local name="$1" src dest
  src="$(find_skill "$name")" || { echo "  ✗ $name — SKILL.md non trovato"; return 1; }
  dest="$TARGET_DIR/$name"

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

case "${1:-}" in
  --list)
    echo "Skill in $TARGET_DIR:"
    shopt -s nullglob
    for path in "$TARGET_DIR"/*/; do
      name="$(basename "$path")"
      if [[ -L "${path%/}" ]]; then
        echo "  $name → $(readlink "${path%/}")"
      else
        echo "  $name (cartella reale)"
      fi
    done
    exit 0
    ;;
  --prune)
    echo "Rimuovo i symlink rotti che puntano a $REPO_DIR:"
    shopt -s nullglob
    for path in "$TARGET_DIR"/*; do
      if [[ -L "$path" ]]; then
        target="$(readlink "$path")"
        if [[ "$target" == "$REPO_DIR"* && ! -e "$target" ]]; then
          rm "$path"
          echo "  - $(basename "$path")"
        fi
      fi
    done
    exit 0
    ;;
esac

mkdir -p "$TARGET_DIR"

if [[ $# -gt 0 ]]; then
  skills=("$@")
else
  mapfile -t skills < <(all_skills)
fi

if [[ ${#skills[@]} -eq 0 ]]; then
  echo "Nessuna skill da installare."
  exit 0
fi

echo "Installo in $TARGET_DIR:"
failed=0
for name in "${skills[@]}"; do
  link_skill "$name" || failed=1
done

exit $failed
