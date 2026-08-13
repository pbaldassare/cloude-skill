# Origine

- **Origine**: https://github.com/pbakaus/impeccable
- **Licenza**: Apache 2.0 (vedi `LICENSE`). `NOTICE.md` copre materiale derivato da ehmo/platform-design-skills (MIT).
- **Versione/commit**: v4.0.4 — `bd2535974861db28a9f4a18ec78608488cd868dd` (2026-08-13, branch `main`)
- **Payload copiato**: `.cursor/skills/impeccable/` (build provider Cursor). Include `SKILL.md`, `reference/` e `scripts/` (detector, live browser, context).
- **Modifiche locali**: aggiunti solo `SOURCE.md`, `LICENSE` e `NOTICE.md` del repo upstream. Nessun altro file della skill è stato modificato.

Non è stato vendored il monorepo (CLI, extension, build per altri harness). Per Claude Code e Cursor Agent basta questo payload: `install.sh` lo collega in `~/.claude/skills/impeccable` e `~/.cursor/skills/impeccable`. I path di fallback nello `SKILL.md` dicono `.cursor/skills/...`; il path primario resta `<skill-base-dir>`, quindi vale anche da `~/.claude/skills`.
