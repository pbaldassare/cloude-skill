#!/usr/bin/env bash
# Configura un progetto perché l'agent abbia sempre accesso alle skill, anche
# nelle sessioni remote di Claude Code sul web (dove ~/.claude/skills non esiste).
#
#   ./setup-project.sh ~/code/mio-progetto
#   ./setup-project.sh ~/code/mio-progetto --copy   # copia le skill invece di collegarle
#
# Cosa fa:
#   1. copia hooks/session-start.sh in <progetto>/.claude/hooks/
#   2. lo registra come SessionStart hook in <progetto>/.claude/settings.json
#   3. aggiunge .claude/skills e .cursor/skills al .gitignore del progetto
#
# Il risultato va committato nel progetto: da lì in poi ogni sessione, locale o
# remota, tira giù le skill da GitHub da sola.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-}"
MODE="${2:-link}"

die() { printf 'errore: %s\n' "$*" >&2; exit 1; }

[[ -n "$TARGET" ]] || die "uso: ./setup-project.sh <percorso-progetto> [--copy]"
[[ -d "$TARGET" ]] || die "progetto non trovato: $TARGET"
TARGET="$(cd "$TARGET" && pwd)"
[[ "$TARGET" != "$REPO_DIR" ]] || die "questa è la repo delle skill, non un progetto che le usa"

if [[ "$MODE" == "--copy" ]]; then
  echo "Copio le skill dentro $TARGET (progetto autonomo, niente hook)"
  mkdir -p "$TARGET/.claude/skills" "$TARGET/.cursor/skills"
  for src in "$REPO_DIR"/skills/*/ "$REPO_DIR"/third-party/*/; do
    [[ -f "${src}SKILL.md" ]] || continue
    name="$(basename "$src")"
    rm -rf "$TARGET/.claude/skills/$name" "$TARGET/.cursor/skills/$name"
    cp -R "${src%/}" "$TARGET/.claude/skills/$name"
    cp -R "${src%/}" "$TARGET/.cursor/skills/$name"
    echo "  + $name"
  done
  echo
  echo "Le skill sono ora dentro il progetto e vanno committate."
  echo "Contropartita: non si aggiornano più da sole quando modifichi questa repo."
  exit 0
fi

echo "Configuro $TARGET"

mkdir -p "$TARGET/.claude/hooks"
cp "$REPO_DIR/hooks/session-start.sh" "$TARGET/.claude/hooks/cloude-skill.sh"
chmod +x "$TARGET/.claude/hooks/cloude-skill.sh"
echo "  + .claude/hooks/cloude-skill.sh"

SETTINGS="$TARGET/.claude/settings.json"
CMD='"$CLAUDE_PROJECT_DIR"/.claude/hooks/cloude-skill.sh'

if command -v python3 >/dev/null 2>&1; then
  python3 - "$SETTINGS" "$CMD" <<'PY'
import json, os, sys

path, cmd = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    with open(path) as f:
        content = f.read().strip()
    if content:
        try:
            data = json.loads(content)
        except json.JSONDecodeError:
            sys.exit(f"settings.json non è JSON valido: {path}")

hooks = data.setdefault("hooks", {})
entries = hooks.setdefault("SessionStart", [])

already = any(
    h.get("command") == cmd
    for entry in entries
    for h in entry.get("hooks", [])
)
if already:
    print("  = SessionStart hook già registrato")
else:
    entries.append({"hooks": [{"type": "command", "command": cmd}]})
    print("  + SessionStart hook in .claude/settings.json")

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
else
  echo "  ! python3 non trovato: aggiungi a mano in $SETTINGS"
  cat <<JSON
{
  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "$CMD" } ] }
    ]
  }
}
JSON
fi

GITIGNORE="$TARGET/.gitignore"
for entry in ".claude/skills/" ".cursor/skills/"; do
  if [[ ! -f "$GITIGNORE" ]] || ! grep -qxF "$entry" "$GITIGNORE"; then
    printf '%s\n' "$entry" >> "$GITIGNORE"
    echo "  + $entry in .gitignore"
  fi
done

echo
echo "Fatto. Committa .claude/hooks/cloude-skill.sh e .claude/settings.json nel progetto."
echo "Da lì in poi ogni sessione — anche remota — collega le skill da GitHub all'avvio."
