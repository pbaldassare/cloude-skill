#!/usr/bin/env bash
# Rende le skill di questa repo disponibili a Claude Code e Cursor su qualsiasi
# macchina, partendo da GitHub. Idempotente: rieseguirlo aggiorna e basta.
#
#   # prima volta su una macchina nuova (non serve aver clonato niente):
#   curl -fsSL https://raw.githubusercontent.com/pbaldassare/cloude-skill/HEAD/bootstrap.sh | bash
#
#   ./bootstrap.sh              # clona/aggiorna + collega in ~/.claude e ~/.cursor
#   ./bootstrap.sh --update     # solo git pull, senza toccare i symlink
#   ./bootstrap.sh --project .  # collega le skill dentro un progetto specifico
#   ./bootstrap.sh --where      # stampa dove vive il clone e si ferma
#
# Variabili: CLOUDE_SKILL_HOME (dove vive il clone), CLOUDE_SKILL_REPO,
# CLOUDE_SKILL_REF (branch/tag da usare; default = branch di default del remote).

set -euo pipefail

REPO_URL="${CLOUDE_SKILL_REPO:-https://github.com/pbaldassare/cloude-skill.git}"
HOME_DIR="${CLOUDE_SKILL_HOME:-$HOME/.local/share/cloude-skill}"
REF="${CLOUDE_SKILL_REF:-}"

say() { printf '%s\n' "$*"; }
die() { printf 'errore: %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || die "git non trovato nel PATH"

# Se lo script gira da dentro un clone già esistente, usa quello invece di
# clonarne un altro: evita di avere due copie che divergono.
script_repo=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  candidate="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -d "$candidate/.git" && -f "$candidate/install.sh" ]]; then
    script_repo="$candidate"
  fi
fi
[[ -n "$script_repo" ]] && HOME_DIR="$script_repo"

sync_repo() {
  if [[ -d "$HOME_DIR/.git" ]]; then
    say "Aggiorno $HOME_DIR"
    git -C "$HOME_DIR" fetch --quiet origin
    local branch
    branch="${REF:-$(git -C "$HOME_DIR" rev-parse --abbrev-ref HEAD)}"
    if ! git -C "$HOME_DIR" merge --ff-only "origin/$branch" --quiet 2>/dev/null; then
      say "  ! non riesco a fare fast-forward su origin/$branch (modifiche locali?)"
      say "  ! il clone resta com'è; risolvi a mano in $HOME_DIR"
    fi
  else
    say "Clono $REPO_URL in $HOME_DIR"
    mkdir -p "$(dirname "$HOME_DIR")"
    if [[ -n "$REF" ]]; then
      git clone --quiet --branch "$REF" "$REPO_URL" "$HOME_DIR"
    else
      git clone --quiet "$REPO_URL" "$HOME_DIR"
    fi
  fi
}

case "${1:-}" in
  --where)
    printf '%s\n' "$HOME_DIR"
    exit 0
    ;;
  --update)
    sync_repo
    say "Fatto. Per ricollegare i symlink: $HOME_DIR/install.sh"
    exit 0
    ;;
  --project)
    target="${2:-.}"
    [[ -d "$target" ]] || die "progetto non trovato: $target"
    target="$(cd "$target" && pwd)"
    sync_repo
    say "Collego le skill dentro $target"
    CLAUDE_SKILLS_DIR="$target/.claude/skills" \
    CURSOR_SKILLS_DIR="$target/.cursor/skills" \
      "$HOME_DIR/install.sh"
    say
    say "Nota: sono symlink verso $HOME_DIR."
    say "Se il progetto deve essere autonomo (altra macchina, collaboratori, CI),"
    say "copia le cartelle invece di collegarle."
    exit 0
    ;;
  "")
    ;;
  *)
    die "opzione sconosciuta: $1"
    ;;
esac

sync_repo
"$HOME_DIR/install.sh"
say
say "Skill installate da $HOME_DIR"
say "Per aggiornarle in futuro: $HOME_DIR/bootstrap.sh"
