#!/usr/bin/env bash
# Verifica che ogni skill della repo rispetti il contratto in SKILL-CONTRACT.md.
# Gira in CI su ogni push e va lanciato prima di committare una skill nuova.
#
#   ./validate.sh              # controlla tutte le skill
#   ./validate.sh supabase-rls # solo quelle indicate
#
# Exit code 1 se c'è almeno un errore. I warning non fanno fallire.

set -uo pipefail
shopt -s nullglob

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIRS=("$REPO_DIR/skills" "$REPO_DIR/third-party")
MAX_LINES=500
MIN_DESC=40
MAX_DESC=1024

errors=0
warnings=0

err()  { printf '  ✗ %s\n' "$*"; errors=$((errors + 1)); }
warn() { printf '  ! %s\n' "$*"; warnings=$((warnings + 1)); }
ok()   { printf '  · %s\n' "$*"; }

# Estrae il valore di una chiave dal frontmatter YAML (prima coppia --- ... ---).
frontmatter_value() {
  awk -v key="$2" '
    NR == 1 && $0 != "---" { exit }
    NR == 1 { infm = 1; next }
    infm && $0 == "---" { exit }
    infm {
      idx = index($0, ":")
      if (idx > 0 && substr($0, 1, idx - 1) == key) {
        v = substr($0, idx + 1)
        sub(/^[ \t]+/, "", v)
        sub(/[ \t]+$/, "", v)
        print v
        exit
      }
    }
  ' "$1"
}

has_frontmatter() {
  [[ "$(head -n 1 "$1")" == "---" ]] && grep -qm2 '^---$' "$1"
}

check_skill() {
  local dir="$1" name kind skill_md desc lines
  name="$(basename "$dir")"
  skill_md="$dir/SKILL.md"
  case "$dir" in
    "$REPO_DIR/third-party/"*) kind="third-party" ;;
    *) kind="nostra" ;;
  esac

  printf '\n%s (%s)\n' "$name" "$kind"

  if [[ ! -f "$skill_md" ]]; then
    err "manca SKILL.md"
    return
  fi

  # --- frontmatter ---
  if ! has_frontmatter "$skill_md"; then
    err "SKILL.md non inizia con un frontmatter YAML delimitato da ---"
    return
  fi

  local fm_name
  fm_name="$(frontmatter_value "$skill_md" name)"
  if [[ -z "$fm_name" ]]; then
    err "frontmatter senza campo 'name'"
  elif [[ "$fm_name" != "$name" ]]; then
    err "name '$fm_name' diverso dal nome cartella '$name'"
  elif [[ ! "$fm_name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    err "name '$fm_name' non è kebab-case minuscolo"
  else
    ok "name"
  fi

  # --- description: è l'unico segnale di attivazione, quindi è il campo critico ---
  desc="$(frontmatter_value "$skill_md" description)"
  if [[ -z "$desc" ]]; then
    err "frontmatter senza campo 'description' — la skill non si attiverà mai"
  elif (( ${#desc} < MIN_DESC )); then
    err "description di ${#desc} caratteri: troppo vaga per attivare la skill (min $MIN_DESC)"
  elif (( ${#desc} > MAX_DESC )); then
    warn "description di ${#desc} caratteri (oltre $MAX_DESC): rischia il troncamento"
  else
    ok "description (${#desc} caratteri)"
  fi

  if [[ -n "$desc" ]] && ! grep -qiE 'quando|use when|usa questa|this skill should be used|any time|whenever' <<<"$desc"; then
    warn "la description non dice *quando* usare la skill: aggiungi i casi d'innesco"
  fi

  # --- dimensione ---
  lines="$(wc -l < "$skill_md")"
  if (( lines > MAX_LINES )); then
    warn "SKILL.md di $lines righe (oltre $MAX_LINES): sposta il raro in references/"
  else
    ok "$lines righe"
  fi

  # --- link interni ---
  local missing=0 link
  while IFS= read -r link; do
    [[ -z "$link" ]] && continue
    [[ -e "$dir/$link" ]] || { err "link rotto in SKILL.md: $link"; missing=$((missing + 1)); }
  done < <(grep -oE '\]\((\./)?(references?|scripts|assets|tests)/[^)#]+\)' "$skill_md" 2>/dev/null \
             | sed -E 's/^\]\(//; s/\)$//; s|^\./||' | sort -u)
  (( missing == 0 )) && ok "link interni"

  # --- provenienza per le skill di terzi ---
  if [[ "$kind" == "third-party" ]]; then
    if [[ ! -f "$dir/SOURCE.md" ]]; then
      err "manca SOURCE.md (origine, licenza, commit, modifiche locali)"
    else
      local field
      for field in Origine Licenza Versione Modifiche; do
        grep -qi "$field" "$dir/SOURCE.md" || warn "SOURCE.md non menziona '$field'"
      done
      ok "SOURCE.md"
    fi
    if ! ls "$dir"/LICENSE* >/dev/null 2>&1; then
      warn "nessun file LICENSE copiato dall'upstream"
    fi
  fi

  # --- indice nel README ---
  grep -q "\`$name\`" "$REPO_DIR/README.md" || warn "non compare nell'indice del README"

  # --- segreti ---
  local hits
  hits="$(grep -rlE 'eyJ[A-Za-z0-9_-]{30,}|sb_secret_[A-Za-z0-9_-]{20,}|SUPABASE_SERVICE_ROLE_KEY[[:space:]]*=[[:space:]]*[A-Za-z0-9]' "$dir" 2>/dev/null | head -5)"
  if [[ -n "$hits" ]]; then
    err "possibile chiave/segreto committato:"
    printf '      %s\n' $hits
  fi
}

all_skill_dirs() {
  local d p
  for d in "${SOURCE_DIRS[@]}"; do
    [[ -d "$d" ]] || continue
    for p in "$d"/*/; do
      [[ -f "${p}SKILL.md" || -d "$p" ]] && printf '%s\n' "${p%/}"
    done
  done
}

# --- collisioni di nome tra skills/ e third-party/ ---
check_collisions() {
  local dup
  dup="$(all_skill_dirs | xargs -r -n1 basename | sort | uniq -d)"
  if [[ -n "$dup" ]]; then
    printf '\ncollisioni\n'
    local name
    while IFS= read -r name; do
      err "il nome '$name' esiste in più cartelle: install.sh ne collegherebbe una sola"
    done <<<"$dup"
  fi
}

main() {
  local dirs=() name found
  if [[ $# -gt 0 ]]; then
    for name in "$@"; do
      found=""
      for d in "${SOURCE_DIRS[@]}"; do
        [[ -d "$d/$name" ]] && { dirs+=("$d/$name"); found=1; break; }
      done
      [[ -n "$found" ]] || { printf '✗ skill non trovata: %s\n' "$name"; errors=$((errors + 1)); }
    done
  else
    mapfile -t dirs < <(all_skill_dirs)
  fi

  if (( ${#dirs[@]} == 0 )); then
    echo "Nessuna skill da controllare."
    return 0
  fi

  printf 'Controllo %d skill in %s\n' "${#dirs[@]}" "$REPO_DIR"
  local dir
  for dir in "${dirs[@]}"; do
    check_skill "$dir"
  done
  [[ $# -eq 0 ]] && check_collisions

  printf '\n%s\n' "----------------------------------------"
  if (( errors > 0 )); then
    printf '%d errori, %d warning\n' "$errors" "$warnings"
    return 1
  fi
  printf 'OK — %d warning\n' "$warnings"
  return 0
}

main "$@"
