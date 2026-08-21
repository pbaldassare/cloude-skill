#!/usr/bin/env bash
# SessionStart hook: rende le skill di cloude-skill disponibili all'agent anche
# dove non esiste ~/.claude/skills — sessioni remote di Claude Code sul web,
# container CI, macchine appena create.
#
# Copiare questo file in <progetto>/.claude/hooks/session-start.sh e registrarlo
# in <progetto>/.claude/settings.json (lo fa setup-project.sh).
#
# Non blocca mai la sessione: se GitHub non è raggiungibile esce 0 in silenzio.

set -uo pipefail

REPO_URL="${CLOUDE_SKILL_REPO:-https://github.com/pbaldassare/cloude-skill.git}"
CACHE_DIR="${CLOUDE_SKILL_HOME:-$HOME/.cache/cloude-skill}"
MAX_AGE_HOURS="${CLOUDE_SKILL_MAX_AGE_HOURS:-6}"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

log() { printf '[cloude-skill] %s\n' "$*" >&2; }

command -v git >/dev/null 2>&1 || { log "git non disponibile, salto"; exit 0; }

if [[ -d "$CACHE_DIR/.git" ]]; then
  # Aggiorna solo se il fetch precedente è vecchio: all'avvio di ogni sessione
  # una chiamata di rete costa più di quanto valga.
  stamp="$CACHE_DIR/.git/FETCH_HEAD"
  if [[ ! -f "$stamp" ]] || [[ -n "$(find "$stamp" -mmin "+$((MAX_AGE_HOURS * 60))" 2>/dev/null)" ]]; then
    git -C "$CACHE_DIR" fetch --quiet --depth 1 origin 2>/dev/null || log "fetch fallito, uso la copia in cache"
    branch="$(git -C "$CACHE_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    git -C "$CACHE_DIR" reset --quiet --hard "origin/$branch" 2>/dev/null || true
  fi
else
  mkdir -p "$(dirname "$CACHE_DIR")"
  if ! git clone --quiet --depth 1 "$REPO_URL" "$CACHE_DIR" 2>/dev/null; then
    log "clone fallito, nessuna skill collegata"
    exit 0
  fi
fi

[[ -x "$CACHE_DIR/install.sh" ]] || { log "install.sh non trovato nella cache"; exit 0; }

CLAUDE_SKILLS_DIR="$PROJECT_DIR/.claude/skills" \
CURSOR_SKILLS_DIR="$PROJECT_DIR/.cursor/skills" \
  "$CACHE_DIR/install.sh" >/dev/null 2>&1 \
  || log "collegamento parziale: alcune skill non sono state installate"

count="$(find "$PROJECT_DIR/.claude/skills" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l | tr -d ' ')"
log "$count skill disponibili da $CACHE_DIR"
exit 0
